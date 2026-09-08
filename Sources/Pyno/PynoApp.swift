import AppKit
import SwiftUI

@main
struct PynoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var store: SessionStore
    @StateObject private var recorder: Recorder
    @StateObject private var loc: Localization

    init() {
        // A SwiftUI App's init runs on the main thread.
        let (store, localization, recorder) = MainActor.assumeIsolated {
            () -> (SessionStore, Localization, Recorder) in
            let store = SessionStore()
            let localization = Localization()
            return (store, localization, Recorder(store: store, localization: localization))
        }
        _store = StateObject(wrappedValue: store)
        _loc = StateObject(wrappedValue: localization)
        _recorder = StateObject(wrappedValue: recorder)
    }

    var body: some Scene {
        WindowGroup("Pyno") {
            ContentView()
                .environmentObject(store)
                .environmentObject(recorder)
                .environmentObject(loc)
                .frame(minWidth: 760, minHeight: 480)
                .onAppear {
                    delegate.recorder = recorder
                    delegate.localization = loc
                }
        }
        .defaultSize(width: 1020, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .saveItem) {
                Button(loc[.openTranscriptsFolder]) {
                    NSWorkspace.shared.open(store.folder)
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var recorder: Recorder?
    weak var localization: Localization?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// Quitting mid-recording would lose the paragraph that has not been written yet,
    /// so offer to wind down cleanly first.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let recorder, recorder.phase.isActive else { return .terminateNow }
        let language = localization?.language ?? .english

        let alert = NSAlert()
        alert.messageText = tr(.quitTitle, language)
        alert.informativeText = tr(.quitBody, language)
        alert.addButton(withTitle: tr(.quitConfirm, language))
        alert.addButton(withTitle: tr(.cancel, language))
        guard alert.runModal() == .alertFirstButtonReturn else { return .terminateCancel }

        Task { @MainActor in
            await recorder.finishForTermination()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
