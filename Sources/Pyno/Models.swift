import Foundation
import FluidAudio

/// Language picked when a session is created.
///
/// Parakeet Ultra (a post-trained TDT v3) is one multilingual model covering 25 European languages, so every
/// case here is already on disk once the model is: adding a language to the picker
/// downloads nothing. The choice is passed to the decoder as a hint (script filtering,
/// which keeps streaming windows from drifting into another language). English and
/// French also drive the language of the interface.
enum SessionLanguage: String, CaseIterable, Identifiable, Codable {
    case english = "en"
    case french = "fr"
    case bulgarian = "bg"
    case croatian = "hr"
    case czech = "cs"
    case danish = "da"
    case dutch = "nl"
    case estonian = "et"
    case finnish = "fi"
    case german = "de"
    case greek = "el"
    case hungarian = "hu"
    case italian = "it"
    case latvian = "lv"
    case lithuanian = "lt"
    case maltese = "mt"
    case polish = "pl"
    case portuguese = "pt"
    case romanian = "ro"
    case russian = "ru"
    case slovak = "sk"
    case slovenian = "sl"
    case spanish = "es"
    case swedish = "sv"
    case ukrainian = "uk"

    /// Always in the picker. English first: it is the default.
    static let builtIn: [SessionLanguage] = [.english, .french]

    /// The ones a user can add, alphabetical by their own name.
    static let addable: [SessionLanguage] = allCases
        .filter { !builtIn.contains($0) }
        .sorted { $0.label.localizedCompare($1.label) == .orderedAscending }

    var id: String { rawValue }

    /// The interface only exists in English and French.
    var hasInterface: Bool { SessionLanguage.builtIn.contains(self) }

    /// Always shown in its own language, never translated.
    var label: String {
        switch self {
        case .english: return "English"
        case .french: return "Français"
        case .bulgarian: return "Български"
        case .croatian: return "Hrvatski"
        case .czech: return "Čeština"
        case .danish: return "Dansk"
        case .dutch: return "Nederlands"
        case .estonian: return "Eesti"
        case .finnish: return "Suomi"
        case .german: return "Deutsch"
        case .greek: return "Ελληνικά"
        case .hungarian: return "Magyar"
        case .italian: return "Italiano"
        case .latvian: return "Latviešu"
        case .lithuanian: return "Lietuvių"
        case .maltese: return "Malti"
        case .polish: return "Polski"
        case .portuguese: return "Português"
        case .romanian: return "Română"
        case .russian: return "Русский"
        case .slovak: return "Slovenčina"
        case .slovenian: return "Slovenščina"
        case .spanish: return "Español"
        case .swedish: return "Svenska"
        case .ukrainian: return "Українська"
        }
    }

    var flag: String {
        switch self {
        case .english: return "🇬🇧"
        case .french: return "🇫🇷"
        case .bulgarian: return "🇧🇬"
        case .croatian: return "🇭🇷"
        case .czech: return "🇨🇿"
        case .danish: return "🇩🇰"
        case .dutch: return "🇳🇱"
        case .estonian: return "🇪🇪"
        case .finnish: return "🇫🇮"
        case .german: return "🇩🇪"
        case .greek: return "🇬🇷"
        case .hungarian: return "🇭🇺"
        case .italian: return "🇮🇹"
        case .latvian: return "🇱🇻"
        case .lithuanian: return "🇱🇹"
        case .maltese: return "🇲🇹"
        case .polish: return "🇵🇱"
        case .portuguese: return "🇵🇹"
        case .romanian: return "🇷🇴"
        case .russian: return "🇷🇺"
        case .slovak: return "🇸🇰"
        case .slovenian: return "🇸🇮"
        case .spanish: return "🇪🇸"
        case .swedish: return "🇸🇪"
        case .ukrainian: return "🇺🇦"
        }
    }

    /// Dates in the transcript are written in the spoken language.
    var locale: Locale { Locale(identifier: rawValue) }

    var asrLanguage: Language {
        switch self {
        case .english: return .english
        case .french: return .french
        case .bulgarian: return .bulgarian
        case .croatian: return .croatian
        case .czech: return .czech
        case .danish: return .danish
        case .dutch: return .dutch
        case .estonian: return .estonian
        case .finnish: return .finnish
        case .german: return .german
        case .greek: return .greek
        case .hungarian: return .hungarian
        case .italian: return .italian
        case .latvian: return .latvian
        case .lithuanian: return .lithuanian
        case .maltese: return .maltese
        case .polish: return .polish
        case .portuguese: return .portuguese
        case .romanian: return .romanian
        case .russian: return .russian
        case .slovak: return .slovak
        case .slovenian: return .slovenian
        case .spanish: return .spanish
        case .swedish: return .swedish
        case .ukrainian: return .ukrainian
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
