import Foundation
import SwiftUI

/// Every user-facing string in the app.
///
/// The UI language is not detected from the system or from where the user is:
/// it follows the language picked when starting a recording. English is the default.
enum L {
    case sessions, newSession, noSessions, noSessionsHint
    case nothingToShow, nothingToShowHint, listening, noSpeech
    case copy, copyTranscript, share, openInClaude, export, exportPanelTitle
    case revealInFinder, delete
    case record, pause, resume, stop
    case recording, paused, ready
    case checkingMic, loadingModel, starting, lookingForModel, finalizing
    case titleField, titlePlaceholder, spokenLanguage, cancel, start
    case error, ok
    case untitledSession, noSpeechMarkdown, fallbackFileName
    case openTranscriptsFolder
    case quitTitle, quitBody, quitConfirm
    case toastCopied, toastCopiedForClaude, toastExported
    case micDenied, noInputDevice
    case claudeHeader

    var pair: (en: String, fr: String) {
        switch self {
        case .sessions:
            return ("Sessions", "Sessions")
        case .newSession:
            return ("New session", "Nouvelle session")
        case .noSessions:
            return ("No sessions", "Aucune session")
        case .noSessionsHint:
            return ("Press Record to get started.", "Appuie sur Enregistrer pour commencer.")
        case .nothingToShow:
            return ("Nothing to show", "Rien à afficher")
        case .nothingToShowHint:
            return (
                "Pick a session on the left, or start a new recording.",
                "Choisis une session à gauche, ou lance un nouvel enregistrement."
            )
        case .listening:
            return ("Listening…", "En écoute…")
        case .noSpeech:
            return ("No speech transcribed.", "Aucune parole transcrite.")
        case .copy:
            return ("Copy", "Copier")
        case .copyTranscript:
            return ("Copy transcript", "Copier le transcript")
        case .share:
            return ("Share", "Partager")
        case .openInClaude:
            return ("Open in Claude", "Ouvrir dans Claude")
        case .export:
            return ("Export…", "Exporter…")
        case .exportPanelTitle:
            return ("Export transcript", "Exporter le transcript")
        case .revealInFinder:
            return ("Reveal in Finder", "Afficher dans le Finder")
        case .delete:
            return ("Delete", "Supprimer")
        case .record:
            return ("Record", "Enregistrer")
        case .pause:
            return ("Pause", "Pause")
        case .resume:
            return ("Resume", "Reprendre")
        case .stop:
            return ("Stop", "Arrêter")
        case .recording:
            return ("Recording", "Enregistrement")
        case .paused:
            return ("Paused", "En pause")
        case .ready:
            return ("Ready · 100% local", "Prêt · 100 % local")
        case .checkingMic:
            return ("Checking microphone access…", "Vérification de l'accès micro…")
        case .loadingModel:
            return ("Loading Parakeet model…", "Chargement du modèle Parakeet…")
        case .starting:
            return ("Starting…", "Démarrage…")
        case .lookingForModel:
            return ("Looking for the model…", "Recherche du modèle…")
        case .finalizing:
            return ("Finalizing transcription…", "Finalisation de la transcription…")
        case .titleField:
            return ("Title", "Titre")
        case .titlePlaceholder:
            return ("Product review", "Réunion produit")
        case .spokenLanguage:
            return ("Spoken language", "Langue parlée")
        case .cancel:
            return ("Cancel", "Annuler")
        case .start:
            return ("Start", "Commencer")
        case .error:
            return ("Error", "Erreur")
        case .ok:
            return ("OK", "OK")
        case .untitledSession:
            return ("Untitled session", "Session sans titre")
        case .noSpeechMarkdown:
            return ("_(no speech transcribed)_", "_(aucune parole transcrite)_")
        case .fallbackFileName:
            return ("session", "session")
        case .openTranscriptsFolder:
            return ("Open transcripts folder", "Ouvrir le dossier des transcripts")
        case .quitTitle:
            return ("A recording is in progress", "Un enregistrement est en cours")
        case .quitBody:
            return (
                "Stop the recording and write the transcript before quitting?",
                "Arrêter l'enregistrement et écrire le transcript avant de quitter ?"
            )
        case .quitConfirm:
            return ("Stop and quit", "Arrêter et quitter")
        case .toastCopied:
            return ("Text copied", "Texte copié")
        case .toastCopiedForClaude:
            return ("Copied — paste into Claude", "Copié — colle-le dans Claude")
        case .toastExported:
            return ("File exported", "Fichier exporté")
        case .micDenied:
            return (
                "Pyno has no access to the microphone. Open System Settings → Privacy & Security → Microphone and enable Pyno.",
                "Pyno n'a pas accès au micro. Ouvre Réglages Système → Confidentialité et sécurité → Microphone et active Pyno."
            )
        case .noInputDevice:
            return ("No audio input device was found.", "Aucun périphérique d'entrée audio n'a été trouvé.")
        case .claudeHeader:
            return (
                "Transcript of a recorded conversation, captured locally with Pyno.",
                "Transcript d'une conversation enregistrée, capturée en local avec Pyno."
            )
        }
    }
}

/// Resolves a key for a given language. Free function so non-`MainActor` code
/// (and the Markdown writer, which follows the *session* language) can use it too.
func tr(_ key: L, _ language: SessionLanguage) -> String {
    language == .french ? key.pair.fr : key.pair.en
}

func trDownloading(_ done: Int, _ total: Int, _ language: SessionLanguage) -> String {
    language == .french
        ? "Téléchargement du modèle Parakeet (\(done)/\(total))"
        : "Downloading Parakeet model (\(done)/\(total))"
}

func trCompiling(_ modelName: String, _ language: SessionLanguage) -> String {
    language == .french
        ? "Compilation Core ML — \(modelName)"
        : "Compiling Core ML — \(modelName)"
}

func trFinalFailed(_ reason: String, _ language: SessionLanguage) -> String {
    language == .french
        ? "La transcription finale a échoué (\(reason)). Le texte déjà confirmé a été conservé."
        : "The final transcription failed (\(reason)). Text confirmed so far was kept."
}

/// Current UI language. Set when a recording starts, then remembered.
@MainActor
final class Localization: ObservableObject {

    private static let defaultsKey = "PynoUILanguage"

    @Published private(set) var language: SessionLanguage

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.defaultsKey)
        language = stored.flatMap(SessionLanguage.init(rawValue:)) ?? .english
    }

    func use(_ language: SessionLanguage) {
        guard self.language != language else { return }
        self.language = language
        UserDefaults.standard.set(language.rawValue, forKey: Self.defaultsKey)
    }

    subscript(key: L) -> String { tr(key, language) }

    func downloading(_ done: Int, _ total: Int) -> String { trDownloading(done, total, language) }
    func compiling(_ modelName: String) -> String { trCompiling(modelName, language) }
    func finalFailed(_ reason: String) -> String { trFinalFailed(reason, language) }
}
