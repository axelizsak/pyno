import Foundation
import FluidAudio

/// Language picked when a session is created.
///
/// Parakeet TDT v3 is multilingual; the choice is passed to the decoder as a hint
/// (script filtering, which keeps streaming windows from drifting into another
/// language) and it also drives the language of the interface.
enum SessionLanguage: String, CaseIterable, Identifiable, Codable {
    case english = "en"
    case french = "fr"

    /// English first: it is the default.
    static let ordered: [SessionLanguage] = [.english, .french]

    var id: String { rawValue }

    /// Always shown in its own language, never translated.
    var label: String {
        switch self {
        case .french: return "Français"
        case .english: return "English"
        }
    }

    var flag: String {
        switch self {
        case .french: return "🇫🇷"
        case .english: return "🇬🇧"
        }
    }

    var asrLanguage: Language {
        switch self {
        case .french: return .french
        case .english: return .english
        }
    }
}

/// One paragraph of transcript, timestamped from the start of the session.
struct Paragraph: Identifiable, Hashable {
    var id = UUID()
    var start: TimeInterval
    var text: String
}

/// A recording session. Persisted as a single Markdown file.
struct Session: Identifiable, Hashable {
    var id: UUID
    var title: String
    var createdAt: Date
    var language: SessionLanguage
    var duration: TimeInterval
    var isFinished: Bool
    var paragraphs: [Paragraph]
    var fileURL: URL

    var plainText: String {
        paragraphs.map(\.text).joined(separator: "\n\n")
    }
}

/// `H:MM:SS` / `MM:SS` formatting for the UI and for Markdown timestamps.
enum Clock {
    static func stamp(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    static func short(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        if total >= 3600 {
            return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
        }
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
