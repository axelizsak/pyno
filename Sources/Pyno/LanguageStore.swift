import Foundation
import SwiftUI

/// Which spoken languages show up in the new-session picker on this Mac.
///
/// English and French are always there. Anything else is added by the user, and the
/// list is theirs alone: it lives in this Mac's preferences, so nobody else's app
/// changes. Adding costs no disk space, because the one speech model already knows
/// all 25 languages. The last language used is remembered as the next default.
@MainActor
final class LanguageStore: ObservableObject {

    private static let addedKey = "PynoAddedLanguages"
    private static let lastUsedKey = "PynoLastSpokenLanguage"

    /// Where someone asks for a language Parakeet does not cover.
    static let requestURL: URL = {
        var components = URLComponents(string: "https://github.com/axelizsak/pyno/issues/new")!
        components.queryItems = [URLQueryItem(name: "title", value: "Language request: ")]
        return components.url!
    }()

    @Published private(set) var added: [SessionLanguage]
    @Published private(set) var lastUsed: SessionLanguage?

    init() {
        let codes = UserDefaults.standard.stringArray(forKey: Self.addedKey) ?? []
        added = codes.compactMap(SessionLanguage.init(rawValue:)).filter { !$0.hasInterface }
        lastUsed = UserDefaults.standard.string(forKey: Self.lastUsedKey).flatMap(SessionLanguage.init(rawValue:))
    }

    /// What the picker offers, in order.
    var available: [SessionLanguage] { SessionLanguage.builtIn + added }

    func contains(_ language: SessionLanguage) -> Bool { available.contains(language) }

    func add(_ language: SessionLanguage) {
        guard !contains(language) else { return }
        added.append(language)
        save()
    }

    func remove(_ language: SessionLanguage) {
        guard !language.hasInterface else { return }
        added.removeAll { $0 == language }
        if lastUsed == language { lastUsed = nil }
        save()
    }

    func markUsed(_ language: SessionLanguage) {
        lastUsed = language
        UserDefaults.standard.set(language.rawValue, forKey: Self.lastUsedKey)
    }

    private func save() {
        UserDefaults.standard.set(added.map(\.rawValue), forKey: Self.addedKey)
        if lastUsed == nil { UserDefaults.standard.removeObject(forKey: Self.lastUsedKey) }
    }
}
