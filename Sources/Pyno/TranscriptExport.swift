import AppKit
import Foundation
import UniformTypeIdentifiers

/// A chat assistant a transcript can be handed to, with the prompt pre-filled.
enum Assistant {
    case claude
    case chatGPT

    fileprivate var newChatURL: URL {
        switch self {
        case .claude: return URL(string: "https://claude.ai/new")!
        case .chatGPT: return URL(string: "https://chatgpt.com/")!
        }
    }

    /// Budget for the whole pre-filled URL.
    ///
    /// Claude: measured against claude.ai, a 60,000-character encoded query still
    /// reaches the server, 100,000 is dropped at the edge. 32,000 keeps a wide margin
    /// and still covers roughly 25 minutes of speech.
    /// ChatGPT: chatgpt.com sits behind a bot check that cannot be probed from a
    /// script, so the limit is unmeasured. 8,000 stays well inside what any web
    /// server takes and covers roughly 6 minutes of speech.
    fileprivate var maxURLLength: Int {
        switch self {
        case .claude: return 32_000
        case .chatGPT: return 8_000
        }
    }

    fileprivate var openingToast: L {
        switch self {
        case .claude: return .toastOpeningClaude
        case .chatGPT: return .toastOpeningChatGPT
        }
    }
}

/// How a transcript leaves the app: clipboard, a file on disk, or a hand-off to Claude
/// or ChatGPT.
@MainActor
enum TranscriptExport {

    static func copyPlainText(_ session: Session, _ loc: Localization) {
        write(session.plainText)
        Toast.shared.show(loc[.toastCopied])
    }

    /// Opens a new conversation with the prompt and the transcript already in it.
    /// Claude leaves it in the composer until the user presses Enter; ChatGPT sends it
    /// on arrival. Transcripts too long for a URL are put on the clipboard instead.
    static func analyze(_ session: Session, in assistant: Assistant, prompt: String, _ loc: Localization) {
        let payload = payload(prompt: prompt, session: session)

        var components = URLComponents(url: assistant.newChatURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "q", value: payload)]

        if let url = components?.url, url.absoluteString.count <= assistant.maxURLLength {
            NSWorkspace.shared.open(url)
            Toast.shared.show(loc[assistant.openingToast])
        } else {
            write(payload)
            NSWorkspace.shared.open(assistant.newChatURL)
            Toast.shared.show(loc[.toastCopiedForAssistant])
        }
    }

    static func download(_ session: Session, _ loc: Localization) {
        let panel = NSSavePanel()
        panel.title = loc[.downloadPanelTitle]
        panel.nameFieldStringValue = session.fileURL.lastPathComponent
        panel.canCreateDirectories = true
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        if let markdown = UTType(filenameExtension: "md") {
            panel.allowedContentTypes = [markdown]
        }

        guard panel.runModal() == .OK, let destination = panel.url else { return }
        do {
            try SessionStore.markdown(for: session).write(to: destination, atomically: true, encoding: .utf8)
            Toast.shared.show(loc[.toastDownloaded])
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    static func reveal(_ session: Session) {
        NSWorkspace.shared.activateFileViewerSelecting([session.fileURL])
    }

    // MARK: - Internal

    private static func write(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private static func payload(prompt: String, session: Session) -> String {
        let french = session.language == .french
        let formatter = DateFormatter()
        formatter.locale = session.language.locale
        formatter.dateStyle = .long
        formatter.timeStyle = .short

        var out = prompt.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n"
        out += "---\n"
        out += (french ? "Titre" : "Title") + ": \(session.title)\n"
        out += "Date: \(formatter.string(from: session.createdAt))\n"
        out += (french ? "Durée" : "Duration") + ": \(Clock.short(session.duration))\n"
        out += (french ? "Langue" : "Language") + ": \(session.language.label)\n"
        out += "---\n\n"

        for paragraph in session.paragraphs {
            out += "[\(Clock.stamp(paragraph.start))] \(paragraph.text)\n\n"
        }
        return out
    }
}
