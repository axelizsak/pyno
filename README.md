# Pyno

Live speech-to-text on Apple Silicon Macs. Fully local, free, no account.

Built for lecture halls: start it when the lecturer starts, stop it at the end, walk
out with the hour already written up. Two and three hour sessions are the ordinary
case, not the stress test.

Start a session, give it a title, hit Record. Pyno listens to the microphone and
writes the text as it goes. When you stop, the session is a clean Markdown file in
`~/Documents/Pyno/` — ready to read or to paste into Claude.

Nothing is uploaded. The model (NVIDIA Parakeet TDT v3, 0.6 B, 25 European
languages) runs on the **Apple Neural Engine** through Core ML, which keeps battery
use low and means it works just as well with the Wi-Fi off.

## Download

**[pyno on the web](https://axelizsak.github.io/pyno/)** is the link to hand out.
Or take **[the disk image](https://github.com/axelizsak/pyno/releases/latest)**
directly: open it, drag Pyno to Applications. Signed and notarized by Apple, so it
opens on the first double-click with no security warning.

Apple Silicon (M1 or newer), macOS 14 or later. Intel Macs cannot run it: Parakeet
needs the Neural Engine. On first launch macOS asks for the microphone, and Pyno
downloads its model once, about 470 MB. Everything after that is offline and instant.

## Building it yourself

You need the Command Line Tools, `xcode-select --install`, which include Swift 6.1.
Full Xcode is not required.

```bash
./run.sh
```

That builds, assembles `dist/Pyno.app`, and opens it.

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

### Interface language

The language you pick when starting a recording is also the language of the
interface: choose French and the app speaks French, choose English and it speaks
English. **English is the default.** The choice is remembered between launches.
This is a deliberate choice, not system-locale or location detection.

### Getting a transcript out

An action row sits under the session title, and the same actions are on the
right-click menu in the sidebar:

- **Analyze in Claude** — opens a new Claude conversation with the prompt *and* the
  transcript already typed into the composer. Nothing is sent: review it, then press
  Enter. The prompt is editable (button's ▾ menu → *Edit prompt…*), defaults to
  "Analyze this transcript and write a summary." and is remembered.
  Transcripts too long for a URL (roughly beyond 25 minutes of speech) are put on
  the clipboard instead, and the caption says to press ⌘V.
- **Download** — saves the Markdown file, defaulting to ~/Downloads.
- **Copy** — plain text on the clipboard.
- **Reveal in Finder** — the original file.

Every one of these confirms with a small caption next to the pointer.

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
SHA-256. The recipient opens the image, drags Pyno to Applications, and launches it
with no warning of any kind.

`dist/Pyno.dmg` is about 10 MB — the model is not bundled, each machine downloads it
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
| `Sources/Pyno/TranscriptExport.swift` | Clipboard, download, hand-off to Claude |
| `Sources/Pyno/PromptStore.swift` | The editable prompt sent with the transcript |
| `Sources/Pyno/Theme.swift` | Colors, level meter, the starburst mark |
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
| More languages (25 European ones) | Add cases to `SessionLanguage` — v3 already handles them |
| Store transcripts elsewhere | `SessionStore.init` |
| Accent color | `Theme.orange` |
| URL budget before falling back to the clipboard | `TranscriptExport.maxURLLength` |

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
