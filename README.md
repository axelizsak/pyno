# Pyno

Live speech-to-text on Apple Silicon Macs. Fully local, free, no account.

Built for lecture halls. Record the whole class and the full transcript is written
and saved by the time it ends. Two and three hour sessions are the ordinary case,
not the stress test.

Start a session, give it a title, hit Record. Pyno listens to the microphone and
writes the text as it goes. When you stop, the session is a clean Markdown file in
`~/Documents/Pyno/` — ready to read or to hand to Claude or ChatGPT.

Nothing is uploaded. The model (NVIDIA Parakeet TDT v3, 0.6 B, 25 European
languages) runs on the **Apple Neural Engine** through Core ML, which keeps battery
use low and means it works just as well with the Wi-Fi off.

## Download

**[pyno on the web](https://pyno.dev/)** is the link to hand out.
Or take **[the disk image](https://github.com/axelizsak/pyno/releases/latest)**
directly: open it, drag Pyno onto the Applications folder the window points to. Signed and notarized by Apple, so it
opens on the first double-click with no security warning.

Apple Silicon (M1 or newer), macOS 14 or later. Intel Macs cannot run it: Parakeet
needs the Neural Engine. On first launch macOS asks for the microphone, and Pyno
downloads its model once, about 470 MB. Everything after that is offline and instant.

## Building it yourself

You need Swift 6.1 or newer. The Command Line Tools (`xcode-select --install`) used to
be enough, but recent releases ship without SwiftUI's macro plugin, so install Xcode:
`build-app.sh` picks up `/Applications/Xcode.app` on its own when it is there.

```bash
./run.sh
```

That builds, assembles `dist.noindex/Pyno.app`, and opens it.

## Using it

| Button | What it does |
| --- | --- |
| **Record** (⌘R) | Asks for a title and the spoken language, then starts |
| **Pause** / **Resume** | Mutes the microphone without ending the session — paused audio is not transcribed |
| **Stop** | Flushes the last audio windows, writes the final file, closes the session |

While recording, black text is confirmed — the model will not revise it. The grey
line underneath is the working hypothesis, which can still change once the model
hears the rest of the sentence.

The transcript is saved as it goes (every paragraph, roughly every 45 s), so a crash
two hours in costs at most one paragraph.

### Spoken languages

The picker offers English and French. **Add a language…** next to it lists the other
23 languages Parakeet v3 understands (German, Spanish, Italian, Polish, Russian,
Ukrainian and the rest of Europe). Adding one downloads nothing and takes no space:
the single speech model already covers all 25, so the button only puts the language
in this Mac's picker. Nobody else's app changes. The list and the last language used
are remembered.

A language Parakeet does not cover cannot be added this way. The sheet links to a
pre-filled GitHub issue to ask for it. Japanese or Chinese would mean a second model
of several hundred megabytes, so they are not offered.

### Interface language

Starting a recording in English or French also switches the interface to that
language. **English is the default.** The choice is remembered between launches.
Recording in any other language leaves the interface as it was: it only exists in
English and French. This is a deliberate choice, not system-locale or location
detection.

### Getting a transcript out

An action row sits under the session title, and the same actions are on the
right-click menu in the sidebar:

- **Analyze with AI** — a menu with **ChatGPT**, **Claude** and **Edit prompt…**.
  Either assistant opens a new conversation with the prompt *and* the transcript
  already in it. Claude leaves it in the composer until you press Enter; ChatGPT
  sends it as soon as the page loads. The prompt defaults to "Analyze this
  transcript and write a summary." and is remembered. A transcript too long for a
  link (beyond roughly 25 minutes of speech for Claude, 6 for ChatGPT) is put on the
  clipboard instead, and the caption says to press ⌘V.
- **Download** — saves the Markdown file, defaulting to ~/Downloads.
- **Copy** — plain text on the clipboard.
- **Reveal in Finder** — the original file.

Every one of these confirms with a small caption next to the pointer.

### Updates

Pyno does not update itself. At launch it asks GitHub for the latest release, and
when that is newer than the running version a banner appears above the transcript:
**Download** opens the new disk image, and dragging Pyno into Applications replaces
the old copy. Transcripts in `~/Documents/Pyno/` are untouched. **Later** hides the
banner until the next launch, and *Pyno → Check for Updates…* runs the same check on
demand. Nothing else is sent: one unauthenticated request to the GitHub API.

Versions before 1.1.0 have no check at all, so anyone on 1.0.x has to download the new
version by hand once.

## Output format

One Markdown file per session in `~/Documents/Pyno/`:

```markdown
---
pyno: 1
id: 6E1A…
title: Product review
created: 2026-09-08T14:30:00+02:00
language: en
duration: 5412
finished: true
---

# Product review

_September 8, 2026 at 2:30 PM · 1:30:12 · English_

**[00:00:00]** Good morning everyone, thanks for joining this product review…

**[00:00:47]** The first item is the quality of speech recognition…
```

The YAML header is also how the app reloads a session: the folder *is* the database.
Move, rename, or version these files freely.

## Distribution

Pyno ships the way MacParakeet, Whisper Notes and the rest of this category ship: a
signed, notarized disk image on a plain download link. **Not the Mac App Store.**
The store would put the app in a sandbox, which moves `~/Documents/Pyno/` into a
private container the user cannot browse — and that folder being an ordinary,
movable pile of Markdown files is the whole idea. Every update would also wait on
review. Notarization gives the same one-click install with none of that.

### One-time setup

```bash
./scripts/setup-signing.sh csr      # makes the key and the request
# upload the request at developer.apple.com, download the certificate
./scripts/setup-signing.sh import ~/Downloads/developerID_application.cer
./scripts/setup-signing.sh notary   # stores an app-specific password
./scripts/setup-signing.sh status   # confirms both are in place
```

An Apple Developer Program membership is required: the certificate type is issued
only to paid accounts.

### Cutting a release

```bash
./scripts/release.sh              # build, sign, notarize, staple, verify
./scripts/release.sh --publish    # the same, plus tag and upload to GitHub Releases
```

The version comes from `CFBundleShortVersionString` in `Resources/Info.plist`, and
the tag from the version. Bump it there before publishing.

The app is notarized and stapled before the disk image is built, so the ticket lives
inside the bundle: a copy dragged out of the image opens even on a Mac that is
offline. The script then verifies exactly what Gatekeeper checks and prints the
SHA-256. The recipient opens the image, sees Pyno on the left and Applications on
the right with an arrow between them, drags, and launches it with no warning of any
kind. There is no text file in the image: a Developer ID build does not need one.

The window is laid out by [dmgbuild](https://github.com/dmgbuild/dmgbuild), which
`make-dmg.sh` installs into `.build/dmgbuild` on first use. It writes Finder's view
settings directly, so building the image never scripts Finder.

`dist.noindex/Pyno.dmg` is about 10 MB — the model is not bundled, each machine downloads it
on first launch.

### Without a certificate

`./scripts/build-app.sh` and `./scripts/make-dmg.sh` still work, and the disk image
then carries an `OPEN ME FIRST.txt` in English and French. But the recipient has to
double-click, get refused, and go to System Settings → Privacy & Security →
**Open Anyway**. It works. It is not something to hand a stranger.

## How it works

```
AVAudioEngine (microphone tap, native format)
      │  buffers copied, ~12/s
      ▼
SlidingWindowAsrManager  ← FluidAudio (Core ML, Neural Engine)
      │  sliding window 2 s + 11 s + 2 s, hypothesis every 1 s
      │  confirmed at ≥ 0.80 confidence and ≥ 10 s of context
      ▼
Recorder  → timestamped paragraphs (~45 s)
      ▼
SessionStore → one .md file, rewritten on every paragraph
```

| File | Role |
| --- | --- |
| `Sources/Pyno/MicCapture.swift` | Microphone capture, level, device changes |
| `Sources/Pyno/Recorder.swift` | State machine, ASR driving, paragraph splitting |
| `Sources/Pyno/SessionStore.swift` | Markdown read/write |
| `Sources/Pyno/TranscriptExport.swift` | Clipboard, download, hand-off to Claude and ChatGPT |
| `Sources/Pyno/LanguageStore.swift` | Which spoken languages this Mac's picker offers |
| `Sources/Pyno/UpdateChecker.swift` | Asks GitHub whether a newer release is out |
| `Sources/Pyno/PromptStore.swift` | The editable prompt sent with the transcript |
| `scripts/make-dmg-background.swift` | The drag-to-Applications backdrop of the disk image |
| `Sources/Pyno/Theme.swift` | Colors, level meter, language chip |
| `Sources/Pyno/Localization.swift` | Every user-facing string, English and French |
| `Sources/Pyno/Toast.swift` | The small caption next to the pointer |
| `Sources/Pyno/ContentView.swift` | Interface |
| `Sources/Pyno/Models.swift` | Session, paragraph, language |

While recording, Pyno asks macOS not to sleep and not to nap the app
(`beginActivity`). Quitting mid-recording offers to finish cleanly first.

## Easy things to change

| Want | Where |
| --- | --- |
| Shorter or longer paragraphs | `Recorder.paragraphSeconds` (45 s) |
| Confirm faster (snappier, less stable) | `SlidingWindowAsrConfig.streaming` → `confirmationThreshold` |
| Dedicated English model (slightly better recall) | `AsrModels.downloadAndLoad(version: .v2)` plus `SlidingWindowAsrConfig(..., tdtConfig: TdtConfig(blankId: 1024))` |
| Languages always in the picker | `SessionLanguage.builtIn` |
| Store transcripts elsewhere | `SessionStore.init` |
| Accent color | `Theme.orange` |
| URL budget before falling back to the clipboard | `Assistant.maxURLLength` |
| Disk image window (icon positions, size) | `scripts/make-dmg.sh` settings and `make-dmg-background.swift`, kept in step |

## Known limits

- **Microphone only.** System audio (the far end of a Zoom call) is not captured.
  The plumbing is ready — FluidAudio exposes `AudioSource.system` — it needs a Core
  Audio process tap or BlackHole wired in.
- **No speaker separation.** The transcript is one continuous stream. FluidAudio can
  do diarization (`LSEENDDiarizer`); it is simply not wired up here.
- **Pausing breaks context.** On resume the model restarts from silence, so a word
  straddling the pause can be lost.
- Seams between 15-second windows occasionally glue two words together or duplicate
  a syllable. That is inherent to streaming chunking.

## Licence

MIT — fork it, change it, ship it. See `LICENSE`.

## Built on

[FluidAudio](https://github.com/FluidInference/FluidAudio) (MIT) — Core ML Parakeet
TDT models converted from NVIDIA NeMo, running on the Apple Neural Engine.
