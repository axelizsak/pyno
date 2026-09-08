# Pyno

Live speech-to-text on Apple Silicon Macs. Fully local, free, no account.

Start a session, give it a title, hit Record. Pyno listens to the microphone and
writes the text as it goes. When you stop, the session is a clean Markdown file in
`~/Documents/Pyno/` — ready to paste into Claude or read as-is.

Nothing is uploaded during transcription. The model (NVIDIA Parakeet TDT v3, 0.6 B)
runs on the **Apple Neural Engine** through Core ML, which is what keeps battery
usage low across two- and three-hour sessions.

---

## Requirements

- **Apple Silicon** Mac (M1 or newer — developed on an M2 Pro)
- **macOS 14** or later
- Swift 6.1, from the Command Line Tools: `xcode-select --install`

Full Xcode is not required.

## Run it

```bash
./run.sh
```

Builds, assembles `dist/Pyno.app`, and opens it.

On first launch:
1. macOS asks for microphone access → **Allow**.
2. Pyno downloads the Parakeet model (~470 MB, once) into
   `~/Library/Application Support/FluidAudio/Models/`. Progress shows in the bottom bar.

Everything after that is offline and instant.

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

Toolbar and right-click menu on any session:

- **Copy** — plain text on the clipboard. A small caption appears next to the pointer
  to confirm it landed.
- **Open in Claude** — copies the transcript with a short context header (title, date,
  duration, language) and opens a new Claude conversation. Paste with ⌘V and ask
  whatever you want; Pyno does not impose an analysis prompt.
- **Export…** — saves a copy of the Markdown file anywhere you like.
- **Reveal in Finder** — the original file.

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

## Giving the app to someone else

`./scripts/build-app.sh` produces `dist/Pyno.zip`; `./scripts/make-dmg.sh` produces
`dist/Pyno.dmg`. Both are ~10 MB — the model is not bundled, each machine downloads
it on first launch.

**With an Apple Developer account** (the smooth path — one link, no instructions):

```bash
# one-time, stores an app-specific password in the keychain
xcrun notarytool store-credentials pyno-notary \
  --apple-id you@example.com --team-id TEAMID --password <app-specific-password>

DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" ./scripts/release.sh
```

That builds, signs with the hardened runtime, packages a `.dmg`, notarizes it with
Apple, and staples the ticket. Upload the `.dmg` anywhere that serves a plain
download link — a public GitHub Release, Google Drive, Dropbox, iCloud Drive — and
send the link. The recipient opens it, drags Pyno to Applications, and launches it
with no warning at all. **No website is needed.**

**Without a Developer account**, the app is ad-hoc signed. It runs fine, but the
first launch on someone else's Mac is blocked by Gatekeeper: they have to
right-click → Open, then confirm. Or:

```bash
xattr -dr com.apple.quarantine /Applications/Pyno.app
```

The app is **arm64 only**: Parakeet needs the Neural Engine, which Intel Macs lack.

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
| `Sources/Pyno/TranscriptExport.swift` | Clipboard, file export, hand-off to Claude |
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

## Built on

[FluidAudio](https://github.com/FluidInference/FluidAudio) (MIT) — Core ML Parakeet
TDT models converted from NVIDIA NeMo, running on the Apple Neural Engine.
