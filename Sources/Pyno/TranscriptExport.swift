import AppKit
import Foundation
import UniformTypeIdentifiers

/// How a transcript leaves the app: clipboard, a file on disk, or a hand-off to Claude.
@MainActor
enum TranscriptExport {

    /// Budget for the whole `claude.ai/new?q=…` URL.
    ///
    /// Measured against claude.ai: a 60,000-character encoded query still reaches the
    /// server, 100,000 is dropped at the edge. 32,000 keeps a wide margin and still
    /// covers roughly 25 minutes of speech; longer transcripts fall back to the clipboard.
    private static let maxURLLength = 32_000

    static func copyPlainText(_ session: Session, _ loc: Localization) {
        write(session.plainText)
        Toast.shared.show(loc[.toastCopied])
    }

    /// Opens a new Claude conversation with the prompt and the transcript already in the
    /// composer. Nothing is sent — the user reviews and presses Enter.
    /// Transcripts too long for a URL are put on the clipboard instead.
    static func analyzeInClaude(_ session: Session, prompt: String, _ loc: Localization) {
        let payload = payload(prompt: prompt, session: session)

        var components = URLComponents(string: "https://claude.ai/new")
        components?.queryItems = [URLQueryItem(name: "q", value: payload)]

        if let url = components?.url, url.absoluteString.count <= maxURLLength {
            NSWorkspace.shared.open(url)
            Toast.shared.show(loc[.toastOpeningClaude])
        } else {
            write(payload)
            NSWorkspace.shared.open(URL(string: "https://claude.ai/new")!)
            Toast.shared.show(loc[.toastCopiedForClaude])
        }
    }

    static func copyForClaude(_ session: Session, prompt: String, _ loc: Localization) {
        write(payload(prompt: prompt, session: session))
        Toast.shared.show(loc[.toastCopied])
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
        formatter.locale = Locale(identifier: french ? "fr_FR" : "en_US")
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
