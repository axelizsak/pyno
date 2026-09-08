import AVFoundation
import Foundation
import FluidAudio
import OSLog
import SwiftUI

/// Loads the Parakeet models once and shares them across sessions.
/// The download (~470 MB, int8) only happens on first launch; afterwards the
/// models are read from the local cache.
actor ModelLoader {
    static let shared = ModelLoader()

    private var loaded: AsrModels?
    private var inFlight: Task<AsrModels, Error>?

    func models(progress: @escaping ProgressHandler) async throws -> AsrModels {
        if let loaded { return loaded }
        if let inFlight { return try await inFlight.value }

        let task = Task<AsrModels, Error> {
            try await AsrModels.downloadAndLoad(version: .v3, progressHandler: progress)
        }
        inFlight = task
        do {
            let models = try await task.value
            loaded = models
            inFlight = nil
            return models
        } catch {
            inFlight = nil
            throw error
        }
    }
}

/// The recording state machine: microphone → Parakeet → paragraphs → Markdown.
@MainActor
final class Recorder: ObservableObject {

    enum Phase: Equatable {
        case idle
        case preparing
        case recording
        case paused
        case finishing

        var isActive: Bool { self == .recording || self == .paused }
    }

    /// How long a paragraph may run before the transcript breaks to a new one.
    private static let paragraphSeconds: TimeInterval = 45

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var status: String = ""
    @Published private(set) var downloadProgress: Double?
    /// True while the one-time model download/compile is running, so the UI can explain it.
    @Published private(set) var isFirstRunSetup = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var level: Float = 0
    @Published private(set) var paragraphs: [Paragraph] = []
    /// Text that is still provisional (the model may revise it) — shown greyed out.
    @Published private(set) var pendingText: String = ""
    @Published var errorMessage: String?
    @Published private(set) var activeSessionID: UUID?

    private let logger = Logger(subsystem: "app.pyno", category: "Recorder")
    private let store: SessionStore
    private let loc: Localization
    private let mic = MicCapture()

    private var asr: SlidingWindowAsrManager?
    private var updateTask: Task<Void, Never>?
    private var timer: Timer?
    private var activity: NSObjectProtocol?

    private var session: Session?
    private var accumulatedTime: TimeInterval = 0
    private var segmentStart: Date?

    private var consumedConfirmedCount = 0
    private var currentParagraph = ""
    private var paragraphStart: TimeInterval = 0
    private var lastDeltaElapsed: TimeInterval = 0

    init(store: SessionStore, localization: Localization) {
        self.store = store
        self.loc = localization
    }

    // MARK: - Session lifecycle

    func start(title: String, language: SessionLanguage) async {
        guard phase == .idle else { return }

        // The chosen spoken language also becomes the language of the interface.
        loc.use(language)

        phase = .preparing
        errorMessage = nil
        status = loc[.checkingMic]

        guard await MicCapture.requestPermission() else {
            fail(MicCapture.CaptureError.permissionDenied)
            return
        }

        status = loc[.loadingModel]
        do {
            let models = try await ModelLoader.shared.models { [weak self] progress in
                Task { @MainActor in self?.apply(progress) }
            }
            downloadProgress = nil
            status = loc[.starting]

            let config = SlidingWindowAsrConfig.streaming.applying(language: language.asrLanguage)
            let manager = SlidingWindowAsrManager(config: config)
            try await manager.loadModels(models)

            // Grab the stream before startStreaming: reading it installs the continuation.
            let updates = await manager.transcriptionUpdates
            try await manager.startStreaming(source: .microphone)

            let newSession = store.create(title: title, language: language)
            session = newSession
            activeSessionID = newSession.id

            resetTranscriptState()
            asr = manager

            updateTask = Task { [weak self] in
                for await _ in updates {
                    let confirmed = await manager.confirmedTranscript
                    let volatile = await manager.volatileTranscript
                    self?.ingest(confirmed: confirmed, volatile: volatile)
                }
            }

            mic.onBuffer = { buffer in
                Task { await manager.streamAudio(buffer) }
            }
            mic.onLevel = { [weak self] value in
                Task { @MainActor in self?.level = value }
            }
            try mic.start()

            beginActivity()
            accumulatedTime = 0
            segmentStart = Date()
            startTimer()
            status = ""
            phase = .recording
        } catch {
            await teardown()
            fail(error)
        }
    }

    func pause() {
        guard phase == .recording else { return }
        mic.pause()
        stopTimer()
        accumulatedTime = elapsed
        segmentStart = nil
        level = 0
        phase = .paused
        persist(finished: false)
    }

    func resume() {
        guard phase == .paused else { return }
        do {
            try mic.resume()
            segmentStart = Date()
            startTimer()
            phase = .recording
        } catch {
            fail(error)
        }
    }

    func stop() async {
        guard phase.isActive else { return }
        phase = .finishing
        status = loc[.finalizing]

        mic.stop()
        stopTimer()
        if segmentStart != nil { accumulatedTime = elapsed }
        segmentStart = nil
        level = 0

        if let manager = asr {
            do {
                let fallback = try await manager.finish()
                // `finish()` flushes the remaining windows: take the confirmed text,
                // then the still-volatile tail, which will never be confirmed now.
                ingest(confirmed: await manager.confirmedTranscript, volatile: "")
                let tail = await manager.volatileTranscript
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !tail.isEmpty { append(tail) }
                flushParagraph(force: true)

                // Safety net: if the incremental stream produced nothing but the final
                // reconstruction has text, keep the latter.
                if paragraphs.isEmpty, !fallback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    paragraphs = [Paragraph(start: 0, text: fallback)]
                }
            } catch {
                flushParagraph(force: true)
                logger.error("finish() failed: \(error.localizedDescription)")
                errorMessage = loc.finalFailed(error.localizedDescription)
            }
        }

        pendingText = ""
        await teardown()
        persist(finished: true)

        session = nil
        activeSessionID = nil
        status = ""
        phase = .idle
    }

    /// Wind down cleanly when the app is quitting mid-recording.
    func finishForTermination() async {
        guard phase.isActive else { return }
        await stop()
    }

    // MARK: - Transcript

    private func resetTranscriptState() {
        paragraphs = []
        pendingText = ""
        consumedConfirmedCount = 0
        currentParagraph = ""
        paragraphStart = 0
        lastDeltaElapsed = 0
        elapsed = 0
    }

    /// `confirmed` is cumulative and only grows; consume just the new suffix.
    private func ingest(confirmed: String, volatile: String) {
        if confirmed.count > consumedConfirmedCount {
            let delta = String(confirmed.dropFirst(consumedConfirmedCount))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            consumedConfirmedCount = confirmed.count
            if !delta.isEmpty { append(delta) }
        }
        pendingText = volatile
    }

    private func append(_ text: String) {
        if currentParagraph.isEmpty {
            paragraphStart = lastDeltaElapsed
            currentParagraph = text
        } else {
            currentParagraph += " " + text
        }
        lastDeltaElapsed = elapsed
        flushParagraph(force: false)
    }

    private func flushParagraph(force: Bool) {
        let text = currentParagraph.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard force || (elapsed - paragraphStart) >= Self.paragraphSeconds else { return }

        paragraphs.append(Paragraph(start: paragraphStart, text: text))
        currentParagraph = ""
        paragraphStart = elapsed
        persist(finished: false)
    }

    /// What the transcript view shows live: written paragraphs plus the one in progress.
    var liveTranscript: [Paragraph] {
        var all = paragraphs
        let inProgress = currentParagraph.trimmingCharacters(in: .whitespacesAndNewlines)
        if !inProgress.isEmpty {
            all.append(Paragraph(start: paragraphStart, text: inProgress))
        }
        return all
    }

    // MARK: - Persistence

    private func persist(finished: Bool) {
        guard var current = session else { return }
        current.paragraphs = liveTranscript
        current.duration = elapsed
        current.isFinished = finished
        session = current
        store.save(current)
    }

    // MARK: - Plumbing

    /// `fractionCompleted` is byte-weighted and monotonic across both the download
    /// and the compile phase, so it is the only honest number to show. The library's
    /// file counter is not: one file (the encoder weights) is 432 MB of the 470 MB,
    /// so "6/23" says nothing about how far along the download is.
    private func apply(_ progress: DownloadProgress) {
        downloadProgress = progress.fractionCompleted
        switch progress.phase {
        case .listing:
            status = loc[.lookingForModel]
            isFirstRunSetup = false
        case .downloading(_, let total):
            // total == 0 means nothing to fetch: the model is already cached.
            status = total > 0 ? loc[.firstRunDownload] : loc[.loadingModel]
            isFirstRunSetup = total > 0
        case .compiling:
            status = loc[.firstRunCompiling]
            isFirstRunSetup = true
        }
    }

    private func startTimer() {
        stopTimer()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        tick()
    }

    private func tick() {
        guard let segmentStart else { return }
        elapsed = accumulatedTime + Date().timeIntervalSince(segmentStart)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    /// Keeps App Nap and idle sleep away during long sessions.
    private func beginActivity() {
        guard activity == nil else { return }
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Recording and transcribing audio"
        )
    }

    private func endActivity() {
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
    }

    private func teardown() async {
        mic.onBuffer = nil
        mic.onLevel = nil
        mic.stop()
        updateTask?.cancel()
        updateTask = nil
        if let manager = asr {
            await manager.cleanup()
        }
        asr = nil
        endActivity()
        stopTimer()
        downloadProgress = nil
        isFirstRunSetup = false
    }

    private func fail(_ error: Error) {
        logger.error("\(error.localizedDescription)")
        errorMessage = message(for: error)
        status = ""
        phase = .idle
        // The file may have been created just before the failure: don't leave an empty session.
        if let session, session.paragraphs.isEmpty {
            store.delete(session)
        }
        session = nil
        activeSessionID = nil
    }

    private func message(for error: Error) -> String {
        switch error {
        case MicCapture.CaptureError.permissionDenied: return loc[.micDenied]
        case MicCapture.CaptureError.noInputDevice: return loc[.noInputDevice]
        default: return error.localizedDescription
        }
    }
}
