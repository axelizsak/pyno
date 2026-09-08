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
                .navigationSplitViewColumnWidth(min: 230, ideal: 270, max: 340)
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
        .tint(Theme.orange)
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
    @EnvironmentObject private var prompts: PromptStore
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
                            Button(loc[.analyzeInClaude]) {
                                TranscriptExport.analyzeInClaude(session, prompt: prompts.prompt, loc)
                            }
                            Button(loc[.download]) { TranscriptExport.download(session, loc) }
                            Button(loc[.copyTranscript]) { TranscriptExport.copyPlainText(session, loc) }
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
                VStack(spacing: 10) {
                    Image(systemName: "waveform")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(Theme.orange.opacity(0.7))
                    Text(loc[.noSessions]).font(.headline)
                    Text(loc[.noSessionsHint])
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
            }
        }
    }
}

private struct SessionRow: View {
    let session: Session
    let isLive: Bool

    @State private var pulse = false

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(session.title)
                    .lineLimit(1)
                Text("\(session.createdAt.formatted(date: .abbreviated, time: .shortened)) · \(Clock.short(session.duration))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if isLive {
                Circle()
                    .fill(Theme.loud)
                    .frame(width: 8, height: 8)
                    .opacity(pulse ? 0.25 : 1)
                    .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)
                    .onAppear { pulse = true }
            } else {
                Text(session.language.flag).font(.caption)
            }
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Transcript pane

private struct DetailPane: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var recorder: Recorder
    @EnvironmentObject private var prompts: PromptStore
    @EnvironmentObject private var loc: Localization
    @Binding var selection: UUID?

    @State private var showPromptEditor = false

    private let scrollAnchor = "pyno-transcript-end"

    private var isLive: Bool {
        selection != nil && selection == recorder.activeSessionID
    }

    var body: some View {
        Group {
            if let session = store.session(id: selection) {
                transcript(for: session)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(Theme.orange.opacity(0.55))
                    Text(loc[.nothingToShow]).font(.title3.weight(.medium))
                    Text(loc[.nothingToShowHint])
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showPromptEditor) {
            PromptSheet(isPresented: $showPromptEditor)
        }
    }

    @ViewBuilder
    private func transcript(for session: Session) -> some View {
        let paragraphs = isLive ? recorder.liveTranscript : session.paragraphs
        let duration = isLive ? recorder.elapsed : session.duration
        let hasText = !paragraphs.isEmpty

        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(session.title)
                        .font(.title2.weight(.semibold))
                    HStack(spacing: 8) {
                        Text("\(session.createdAt.formatted(date: .long, time: .shortened)) · \(Clock.short(duration))")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Chip(text: "\(session.language.flag) \(session.language.label)")
                    }
                }

                actionRow(for: session, enabled: hasText)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Theme.orange.opacity(0.06), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

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
                    if !hasText && recorder.pendingText.isEmpty {
                        Text(isLive ? loc[.listening] : loc[.noSpeech])
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func actionRow(for session: Session, enabled: Bool) -> some View {
        HStack(spacing: 10) {
            Menu {
                Button(loc[.editPrompt]) { showPromptEditor = true }
                Button(loc[.copyForClaude]) {
                    TranscriptExport.copyForClaude(session, prompt: prompts.prompt, loc)
                }
            } label: {
                HStack(spacing: 7) {
                    Burst(spokes: 8)
                        .fill(.white)
                        .frame(width: 13, height: 13)
                    Text(loc[.analyzeInClaude])
                }
            } primaryAction: {
                TranscriptExport.analyzeInClaude(session, prompt: prompts.prompt, loc)
            }
            .menuStyle(.button)
            .buttonStyle(.borderedProminent)
            .tint(Theme.claude)
            .fixedSize()

            Button {
                TranscriptExport.download(session, loc)
            } label: {
                Label(loc[.download], systemImage: "arrow.down.circle")
            }

            Button {
                TranscriptExport.copyPlainText(session, loc)
            } label: {
                Label(loc[.copy], systemImage: "doc.on.doc")
            }

            Button {
                TranscriptExport.reveal(session)
            } label: {
                Image(systemName: "folder")
            }
            .help(loc[.revealInFinder])

            Spacer(minLength: 0)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .disabled(!enabled)
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
                .foregroundStyle(Theme.orange.opacity(isProvisional ? 0.4 : 0.75))
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

    @State private var pulse = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onRecord) {
                Label(loc[.record], systemImage: "mic.fill")
                    .frame(minWidth: 84)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.orange)
            .disabled(recorder.phase != .idle)
            .keyboardShortcut("r", modifiers: .command)

            Button(action: onTogglePause) {
                Label(
                    recorder.phase == .paused ? loc[.resume] : loc[.pause],
                    systemImage: recorder.phase == .paused ? "play.fill" : "pause.fill"
                )
            }
            .buttonStyle(.bordered)
            .disabled(!recorder.phase.isActive)

            Button(action: onStop) {
                Label(loc[.stop], systemImage: "stop.fill")
            }
            .buttonStyle(.bordered)
            .tint(Theme.loud)
            .disabled(!recorder.phase.isActive)

            Divider().frame(height: 22)

            statusArea

            Spacer(minLength: 12)

            if recorder.phase.isActive || recorder.phase == .finishing {
                Text(Clock.short(recorder.elapsed))
                    .font(.system(.title3, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(recorder.phase == .recording ? Theme.orangeDeep : .secondary)
            }
        }
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
                Circle()
                    .fill(Theme.loud)
                    .frame(width: 9, height: 9)
                    .opacity(pulse ? 0.3 : 1)
                    .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)
                    .onAppear { pulse = true }
                Text(loc[.recording]).font(.callout.weight(.medium))
                MicLevel(level: recorder.level)
            }
        case .paused:
            Label(loc[.paused], systemImage: "pause.circle.fill")
                .font(.callout)
                .foregroundStyle(Theme.orange)
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
            HStack(spacing: 7) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.quiet)
                Text(loc[.ready]).font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Sheets

private struct NewSessionSheet: View {
    @EnvironmentObject private var loc: Localization
    @Binding var title: String
    @Binding var language: SessionLanguage
    let onStart: () -> Void
    let onCancel: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 9) {
                Image(systemName: "waveform")
                    .foregroundStyle(Theme.orange)
                Text(loc[.newSession])
                    .font(.title3.weight(.semibold))
            }

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
                    .tint(Theme.orange)
            }
        }
        .padding(24)
        .frame(width: 400)
        .onAppear { focused = true }
    }
}

private struct PromptSheet: View {
    @EnvironmentObject private var prompts: PromptStore
    @EnvironmentObject private var loc: Localization
    @Binding var isPresented: Bool

    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 9) {
                Burst(spokes: 8)
                    .fill(Theme.claude)
                    .frame(width: 15, height: 15)
                Text(loc[.promptSheetTitle])
                    .font(.title3.weight(.semibold))
            }

            TextEditor(text: $draft)
                .font(.system(size: 13))
                .frame(height: 96)
                .padding(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3))
                )

            Text(loc[.promptHint])
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button(loc[.promptReset]) { draft = loc[.defaultPrompt] }
                Spacer()
                Button(loc[.cancel], role: .cancel) { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Button(loc[.save]) {
                    prompts.update(draft)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(Theme.claude)
            }
        }
        .padding(22)
        .frame(width: 460)
        .onAppear { draft = prompts.prompt }
    }
}
