import Foundation
import SwiftUI

/// Every user-facing string in the app.
///
/// The UI language is not detected from the system or from where the user is:
/// it follows the language picked when starting a recording. English is the default.
enum L {
    case sessions, newSession, noSessions, noSessionsHint
    case nothingToShow, nothingToShowHint, listening, noSpeech
    case copy, copyTranscript, analyzeWithAI
    case download, downloadPanelTitle
    case revealInFinder, delete
    case editPrompt, promptSheetTitle, promptHint, promptReset, save
    case defaultPrompt
    case record, pause, resume, stop
    case recording, paused, ready
    case checkingMic, loadingModel, starting, lookingForModel, finalizing
    case firstRunDownload, firstRunCompiling, firstRunNote
    case titleField, titlePlaceholder, spokenLanguage, cancel, start
    case error, ok
    case untitledSession, noSpeechMarkdown, fallbackFileName
    case openTranscriptsFolder
    case quitTitle, quitBody, quitConfirm
    case toastCopied, toastCopiedForAssistant, toastOpeningClaude, toastOpeningChatGPT, toastDownloaded
    case addLanguage, languagesTitle, languagesHint, languagesInterfaceNote
    case yourLanguages, moreLanguages, add, remove, requestLanguage, done
    case checkForUpdates, upToDateTitle, updateCheckFailed, updateHint, downloadUpdate, later
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
        case .analyzeWithAI:
            return ("Analyze with AI", "Analyser avec l'IA")
        case .download:
            return ("Download", "Télécharger")
        case .downloadPanelTitle:
            return ("Download transcript", "Télécharger le transcript")
        case .editPrompt:
            return ("Edit prompt…", "Modifier le prompt…")
        case .promptSheetTitle:
            return ("Prompt sent with the transcript", "Prompt envoyé avec le transcript")
        case .promptHint:
            return (
                "This text goes above the transcript in the new Claude or ChatGPT conversation. Claude waits for you to press Enter; ChatGPT sends it straight away.",
                "Ce texte est placé au-dessus du transcript dans la nouvelle conversation Claude ou ChatGPT. Claude attend que tu appuies sur Entrée ; ChatGPT l'envoie directement."
            )
        case .promptReset:
            return ("Reset", "Réinitialiser")
        case .save:
            return ("Save", "Enregistrer")
        case .defaultPrompt:
            return (
                "Analyze this transcript and write a summary.",
                "Analyse ce transcript et fais-en un résumé."
            )
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
        case .firstRunDownload:
            return (
                "First launch only — downloading the speech model (630 MB)",
                "Premier lancement seulement — téléchargement du modèle vocal (630 Mo)"
            )
        case .firstRunCompiling:
            return (
                "First launch only — optimizing the model for this Mac",
                "Premier lancement seulement — optimisation du modèle pour ce Mac"
            )
        case .firstRunNote:
            return (
                "This happens once. Pyno then works offline.",
                "Ça n'arrive qu'une fois. Ensuite Pyno fonctionne hors-ligne."
            )
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
        case .toastCopiedForAssistant:
            return ("Too long for a link — copied, press ⌘V", "Trop long pour un lien — copié, fais ⌘V")
        case .toastOpeningClaude:
            return ("Opening Claude…", "Ouverture de Claude…")
        case .toastOpeningChatGPT:
            return ("Opening ChatGPT…", "Ouverture de ChatGPT…")
        case .toastDownloaded:
            return ("File downloaded", "Fichier téléchargé")
        case .addLanguage:
            return ("Add a language…", "Ajouter une langue…")
        case .languagesTitle:
            return ("Spoken languages", "Langues parlées")
        case .languagesHint:
            return (
                "Every language here is already inside Pyno's speech model, so adding one downloads nothing and takes no space. The list is only yours, on this Mac.",
                "Toutes ces langues sont déjà dans le modèle vocal de Pyno : en ajouter une ne télécharge rien et ne prend aucune place. La liste n'appartient qu'à toi, sur ce Mac."
            )
        case .languagesInterfaceNote:
            return (
                "The interface itself stays in English or French.",
                "L'interface, elle, reste en anglais ou en français."
            )
        case .yourLanguages:
            return ("In your list", "Dans ta liste")
        case .moreLanguages:
            return ("Available", "Disponibles")
        case .add:
            return ("Add", "Ajouter")
        case .remove:
            return ("Remove", "Retirer")
        case .requestLanguage:
            return ("Language missing? Ask for it", "Une langue manque ? Demande-la")
        case .done:
            return ("Done", "Terminé")
        case .checkForUpdates:
            return ("Check for Updates…", "Rechercher des mises à jour…")
        case .upToDateTitle:
            return ("You're up to date", "Pyno est à jour")
        case .updateCheckFailed:
            return ("Couldn't check for updates", "Impossible de vérifier les mises à jour")
        case .updateHint:
            return (
                "Download it, then drag it into Applications to replace this one. Your transcripts stay where they are.",
                "Télécharge-la, puis glisse-la dans Applications pour remplacer celle-ci. Tes transcripts ne bougent pas."
            )
        case .downloadUpdate:
            return ("Download", "Télécharger")
        case .later:
            return ("Later", "Plus tard")
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

func trFinalFailed(_ reason: String, _ language: SessionLanguage) -> String {
    language == .french
        ? "La transcription finale a échoué (\(reason)). Le texte déjà confirmé a été conservé."
        : "The final transcription failed (\(reason)). Text confirmed so far was kept."
}

/// Current UI language. Set when a recording starts in English or French, then remembered.
/// Recording in any other language leaves the interface as it was.
@MainActor
final class Localization: ObservableObject {

    private static let defaultsKey = "PynoUILanguage"

    @Published private(set) var language: SessionLanguage

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.defaultsKey)
        language = stored.flatMap(SessionLanguage.init(rawValue:)) ?? .english
    }

    func use(_ language: SessionLanguage) {
        guard language.hasInterface, self.language != language else { return }
        self.language = language
        UserDefaults.standard.set(language.rawValue, forKey: Self.defaultsKey)
    }

    subscript(key: L) -> String { tr(key, language) }

    func finalFailed(_ reason: String) -> String { trFinalFailed(reason, language) }

    func upToDate(_ version: String) -> String {
        language == .french
            ? "Pyno \(version) est la dernière version."
            : "Pyno \(version) is the latest version."
    }

    func updateAvailable(_ version: String) -> String {
        language == .french
            ? "Pyno \(version) est disponible"
            : "Pyno \(version) is available"
    }
}
