import AVFoundation
import Foundation
import OSLog

/// Microphone capture through AVAudioEngine.
/// Buffers are copied before being handed on: a tap's buffer is only valid for the
/// duration of the callback, which runs on a real-time thread.
///
/// Errors are untranslated on purpose — `Recorder` maps them to the current UI language.
final class MicCapture {

    enum CaptureError: Error {
        case permissionDenied
        case noInputDevice
    }

    private let logger = Logger(subsystem: "app.pyno", category: "MicCapture")
    private let engine = AVAudioEngine()
    private var isTapInstalled = false
    private var isPaused = false
    private var observer: NSObjectProtocol?

    /// Called for every captured buffer (audio thread).
    var onBuffer: (@Sendable (AVAudioPCMBuffer) -> Void)?
    /// RMS level 0...1, published continuously (audio thread).
    var onLevel: (@Sendable (Float) -> Void)?

    static func requestPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .audio)
        default: return false
        }
    }

    func start() throws {
        try installTap()
        engine.prepare()
        try engine.start()
        isPaused = false
        observeConfigurationChanges()
    }

    func pause() {
        engine.pause()
        isPaused = true
        onLevel?(0)
    }

    func resume() throws {
        try engine.start()
        isPaused = false
    }

    func stop() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
        if isTapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        engine.stop()
        isPaused = false
        onLevel?(0)
    }

    private func installTap() throws {
        guard !isTapInstalled else { return }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw CaptureError.noInputDevice
        }
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            self?.handle(buffer)
        }
        isTapInstalled = true
    }

    // MARK: - Internal

    private func handle(_ buffer: AVAudioPCMBuffer) {
        guard let copy = Self.copy(buffer) else { return }
        onLevel?(Self.rms(copy))
        onBuffer?(copy)
    }

    /// Changing the input device (headset plugged in, dock attached) invalidates the
    /// graph. Reinstall the tap with the new format and carry on.
    private func observeConfigurationChanges() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.isTapInstalled else { return }
            self.logger.info("Audio configuration changed, restarting input tap")
            self.engine.inputNode.removeTap(onBus: 0)
            self.isTapInstalled = false
            do {
                try self.installTap()
                self.engine.prepare()
                // A paused session stays paused: only reinstall the tap.
                if !self.isPaused { try self.engine.start() }
            } catch {
                self.logger.error("Failed to restart engine: \(error.localizedDescription)")
            }
        }
    }

    private static func copy(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength) else {
            return nil
        }
        copy.frameLength = buffer.frameLength
        let channels = Int(buffer.format.channelCount)
        let frames = Int(buffer.frameLength)

        if let source = buffer.floatChannelData, let destination = copy.floatChannelData {
            for channel in 0..<channels {
                destination[channel].update(from: source[channel], count: frames)
            }
            return copy
        }
        if let source = buffer.int16ChannelData, let destination = copy.int16ChannelData {
            for channel in 0..<channels {
                destination[channel].update(from: source[channel], count: frames)
            }
            return copy
        }
        return nil
    }

    private static func rms(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData, buffer.frameLength > 0 else { return 0 }
        let frames = Int(buffer.frameLength)
        var sum: Float = 0
        for index in 0..<frames {
            let sample = data[0][index]
            sum += sample * sample
        }
        let rms = (sum / Float(frames)).squareRoot()
        // Perceptual scale: -60 dB → 0, 0 dB → 1
        let db = 20 * log10(max(rms, 1e-7))
        return min(1, max(0, (db + 60) / 60))
    }
}
