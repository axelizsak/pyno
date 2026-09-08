import AppKit
import Foundation
import UniformTypeIdentifiers

/// The ways a finished transcript leaves the app: clipboard, a file on disk,
/// or a hand-off to Claude for analysis.
@MainActor
enum TranscriptExport {

    static func copyPlainText(_ session: Session, _ loc: Localization) {
        write(session.plainText)
        Toast.shared.show(loc[.toastCopied])
    }

    /// Copies the transcript with a short context header and opens Claude, ready to paste.
    /// No analysis prompt is imposed — what to ask is left to the user.
    static func openInClaude(_ session: Session, _ loc: Localization) {
        write(claudeText(for: session))
        NSWorkspace.shared.open(URL(string: "https://claude.ai/new")!)
        Toast.shared.show(loc[.toastCopiedForClaude])
    }

    static func export(_ session: Session, _ loc: Localization) {
        let panel = NSSavePanel()
        panel.title = loc[.exportPanelTitle]
        panel.nameFieldStringValue = session.fileURL.lastPathComponent
        panel.canCreateDirectories = true
        if let markdown = UTType(filenameExtension: "md") {
            panel.allowedContentTypes = [markdown]
        }

        guard panel.runModal() == .OK, let destination = panel.url else { return }
        do {
            try SessionStore.markdown(for: session).write(to: destination, atomically: true, encoding: .utf8)
            Toast.shared.show(loc[.toastExported])
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

    private static func claudeText(for session: Session) -> String {
        let french = session.language == .french
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: french ? "fr_FR" : "en_US")
        formatter.dateStyle = .long
        formatter.timeStyle = .short

        var out = tr(.claudeHeader, session.language) + "\n\n"
        out += (french ? "Titre" : "Title") + ": \(session.title)\n"
        out += (french ? "Date" : "Date") + ": \(formatter.string(from: session.createdAt))\n"
        out += (french ? "Durée" : "Duration") + ": \(Clock.short(session.duration))\n"
        out += (french ? "Langue" : "Language") + ": \(session.language.label)\n\n---\n\n"

        for paragraph in session.paragraphs {
            out += "[\(Clock.stamp(paragraph.start))] \(paragraph.text)\n\n"
        }
        return out
    }
}
