import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var recorder: Recorder
    @EnvironmentObject private var loc: Localization

    @State private var selection: UUID?
    @State private var showNewSession = false
    @State private var draftTitle = ""
    @State private var draftLanguage: SessionLanguage = .english

    var body: some View {
        NavigationSplitView {
            SessionList(selection: $selection, onNew: presentNewSession)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
        } detail: {
            VStack(spacing: 0) {
                DetailPane(selection: $selection)
                Divider()
                TransportBar(
                    onRecord: presentNewSession,
                    onTogglePause: togglePause,
                    onStop: { Task { await recorder.stop() } }
                )
            }
        }
        .navigationTitle("")
        .sheet(isPresented: $showNewSession) {
            NewSessionSheet(title: $draftTitle, language: $draftLanguage) {
                showNewSession = false
                let title = draftTitle
                let language = draftLanguage
                Task {
                    await recorder.start(title: title, language: language)
                    if let id = recorder.activeSessionID { selection = id }
                }
            } onCancel: {
                showNewSession = false
            }
        }
        .alert(
            loc[.error],
            isPresented: Binding(
                get: { recorder.errorMessage != nil },
                set: { if !$0 { recorder.errorMessage = nil } }
            )
        ) {
            Button(loc[.ok], role: .cancel) { recorder.errorMessage = nil }
        } message: {
            Text(recorder.errorMessage ?? "")
        }
        .onChange(of: recorder.activeSessionID) { _, id in
            if let id { selection = id }
        }
        .onAppear {
            if selection == nil { selection = store.sessions.first?.id }
        }
    }

    private func presentNewSession() {
        guard recorder.phase == .idle else { return }
        draftTitle = ""
        draftLanguage = loc.language
        showNewSession = true
    }

    private func togglePause() {
        switch recorder.phase {
        case .recording: recorder.pause()
        case .paused: recorder.resume()
        default: break
        }
    }
}

// MARK: - Session list

private struct SessionList: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var recorder: Recorder
    @EnvironmentObject private var loc: Localization
    @Binding var selection: UUID?
    let onNew: () -> Void

    var body: some View {
        List(selection: $selection) {
            Section(loc[.sessions]) {
                ForEach(store.sessions) { session in
                    SessionRow(session: session, isLive: session.id == recorder.activeSessionID)
                        .tag(session.id)
                        .contextMenu {
                            Button(loc[.copyTranscript]) { TranscriptExport.copyPlainText(session, loc) }
                            Button(loc[.openInClaude]) { TranscriptExport.openInClaude(session, loc) }
                            Button(loc[.export]) { TranscriptExport.export(session, loc) }
                            Button(loc[.revealInFinder]) { TranscriptExport.reveal(session) }
                            Divider()
                            Button(loc[.delete], role: .destructive) {
                                guard session.id != recorder.activeSessionID else { return }
                                if selection == session.id { selection = nil }
                                store.delete(session)
                            }
                            .disabled(session.id == recorder.activeSessionID)
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem {
                Button(action: onNew) {
                    Label(loc[.newSession], systemImage: "plus")
                }
                .disabled(recorder.phase != .idle)
                .help(loc[.newSession])
            }
        }
        .overlay {
            if store.sessions.isEmpty {
                ContentUnavailableView(
                    loc[.noSessions],
                    systemImage: "waveform",
                    description: Text(loc[.noSessionsHint])
                )
            }
        }
    }
}

private struct SessionRow: View {
    @EnvironmentObject private var loc: Localization
    let session: Session
    let isLive: Bool

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .lineLimit(1)
                Text("\(session.createdAt.formatted(date: .abbreviated, time: .shortened)) · \(Clock.short(session.duration))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if isLive {
                Circle().fill(.red).frame(width: 8, height: 8)
            } else {
                Text(session.language.flag).font(.caption)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Transcript pane

private struct DetailPane: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var recorder: Recorder
    @EnvironmentObject private var loc: Localization
    @Binding var selection: UUID?

    private let scrollAnchor = "pyno-transcript-end"

    private var isLive: Bool {
        selection != nil && selection == recorder.activeSessionID
    }

    var body: some View {
        Group {
            if let session = store.session(id: selection) {
                transcript(for: session)
            } else {
                ContentUnavailableView(
                    loc[.nothingToShow],
                    systemImage: "text.alignleft",
                    description: Text(loc[.nothingToShowHint])
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func transcript(for session: Session) -> some View {
        let paragraphs = isLive ? recorder.liveTranscript : session.paragraphs
        let duration = isLive ? recorder.elapsed : session.duration

        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .font(.title2.weight(.semibold))
                Text("\(session.createdAt.formatted(date: .long, time: .shortened)) · \(Clock.short(duration)) · \(session.language.flag) \(session.language.label)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 14)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(paragraphs) { paragraph in
                            ParagraphView(paragraph: paragraph)
                        }
                        if isLive, !recorder.pendingText.isEmpty {
                            ParagraphView(
                                paragraph: Paragraph(start: recorder.elapsed, text: recorder.pendingText),
                                isProvisional: true
                            )
                        }
                        Color.clear.frame(height: 1).id(scrollAnchor)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .textSelection(.enabled)
                .onChange(of: paragraphs.count) { _, _ in scrollToEnd(proxy) }
                .onChange(of: recorder.pendingText) { _, _ in if isLive { scrollToEnd(proxy) } }
                .overlay {
                    if paragraphs.isEmpty && recorder.pendingText.isEmpty {
                        Text(isLive ? loc[.listening] : loc[.noSpeech])
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    TranscriptExport.copyPlainText(session, loc)
                } label: {
                    Label(loc[.copy], systemImage: "doc.on.doc")
                }
                .help(loc[.copyTranscript])
                .disabled(paragraphs.isEmpty)

                Menu {
                    Button(loc[.openInClaude]) { TranscriptExport.openInClaude(session, loc) }
                    Button(loc[.export]) { TranscriptExport.export(session, loc) }
                    Divider()
                    Button(loc[.revealInFinder]) { TranscriptExport.reveal(session) }
                } label: {
                    Label(loc[.share], systemImage: "square.and.arrow.up")
                }
                .help(loc[.share])
            }
        }
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(scrollAnchor, anchor: .bottom)
        }
    }
}

private struct ParagraphView: View {
    let paragraph: Paragraph
    var isProvisional = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(Clock.stamp(paragraph.start))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 62, alignment: .trailing)
            Text(paragraph.text)
                .font(.system(size: 15))
                .lineSpacing(4)
                .foregroundStyle(isProvisional ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Transport bar

private struct TransportBar: View {
    @EnvironmentObject private var recorder: Recorder
    @EnvironmentObject private var loc: Localization
    let onRecord: () -> Void
    let onTogglePause: () -> Void
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onRecord) {
                Label(loc[.record], systemImage: "record.circle")
            }
            .disabled(recorder.phase != .idle)
            .keyboardShortcut("r", modifiers: .command)

            Button(action: onTogglePause) {
                Label(
                    recorder.phase == .paused ? loc[.resume] : loc[.pause],
                    systemImage: recorder.phase == .paused ? "play.fill" : "pause.fill"
                )
            }
            .disabled(!recorder.phase.isActive)

            Button(action: onStop) {
                Label(loc[.stop], systemImage: "stop.fill")
            }
            .disabled(!recorder.phase.isActive)

            Divider().frame(height: 20)

            statusArea

            Spacer(minLength: 12)

            if recorder.phase.isActive || recorder.phase == .finishing {
                Text(Clock.short(recorder.elapsed))
                    .font(.system(.title3, design: .monospaced))
                    .monospacedDigit()
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.bar)
    }

    @ViewBuilder
    private var statusArea: some View {
        switch recorder.phase {
        case .recording:
            HStack(spacing: 10) {
                Circle().fill(.red).frame(width: 9, height: 9)
                Text(loc[.recording])
                LevelMeter(level: recorder.level)
            }
            .font(.callout)
        case .paused:
            Label(loc[.paused], systemImage: "pause.circle")
                .font(.callout)
                .foregroundStyle(.secondary)
        case .preparing:
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text(recorder.status).font(.callout).foregroundStyle(.secondary)
                if let progress = recorder.downloadProgress {
                    ProgressView(value: progress).frame(width: 120)
                }
            }
        case .finishing:
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text(recorder.status).font(.callout).foregroundStyle(.secondary)
            }
        case .idle:
            Text(loc[.ready])
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
    }
}

private struct LevelMeter: View {
    let level: Float

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<14, id: \.self) { index in
                let threshold = Float(index) / 14
                RoundedRectangle(cornerRadius: 1)
                    .fill(level > threshold ? Color.accentColor : Color.secondary.opacity(0.22))
                    .frame(width: 3, height: 4 + CGFloat(index) * 0.9)
            }
        }
        .frame(height: 18, alignment: .bottom)
        .animation(.linear(duration: 0.08), value: level)
    }
}

// MARK: - New session

private struct NewSessionSheet: View {
    @EnvironmentObject private var loc: Localization
    @Binding var title: String
    @Binding var language: SessionLanguage
    let onStart: () -> Void
    let onCancel: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(loc[.newSession])
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 6) {
                Text(loc[.titleField]).font(.callout).foregroundStyle(.secondary)
                TextField(loc[.titlePlaceholder], text: $title)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .onSubmit(onStart)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(loc[.spokenLanguage]).font(.callout).foregroundStyle(.secondary)
                Picker("", selection: $language) {
                    ForEach(SessionLanguage.ordered) { option in
                        Text("\(option.flag)  \(option.label)").tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            HStack {
                Spacer()
                Button(loc[.cancel], role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(loc[.start], action: onStart)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 400)
        .onAppear { focused = true }
    }
}
