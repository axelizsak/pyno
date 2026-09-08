import Foundation
import SwiftUI

/// The instruction placed above the transcript when handing off to Claude.
/// Editable, remembered between launches, and resettable to the default for the
/// current interface language.
@MainActor
final class PromptStore: ObservableObject {

    private static let defaultsKey = "PynoClaudePrompt"

    @Published private(set) var prompt: String

    private let loc: Localization

    init(localization: Localization) {
        loc = localization
        prompt = UserDefaults.standard.string(forKey: Self.defaultsKey)
            ?? tr(.defaultPrompt, localization.language)
    }

    func update(_ newValue: String) {
        let clean = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        prompt = clean.isEmpty ? loc[.defaultPrompt] : clean
        UserDefaults.standard.set(prompt, forKey: Self.defaultsKey)
    }

    func reset() {
        update(loc[.defaultPrompt])
    }
}
