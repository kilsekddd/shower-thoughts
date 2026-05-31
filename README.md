# shower-thoughts

Push-to-talk voice notes, transcribed on-device, fully offline. Flutter iOS
app; iPad / Android / desktop are deliberately later.

- **Status:** v1.0.0 submitted to Apple App Review on 2026-05-31; live on TestFlight. Manual release pending Apple decision.
- **Privacy policy:** https://kilsekddd.github.io/shower-thoughts/
- **Issues / contact:** https://github.com/kilsekddd/shower-thoughts/issues
- **Bundle ID:** `io.github.kilsekddd.showerThoughts`

## What it does

Hold the push-to-talk button, speak, release. The recording is transcribed
locally on the device via a bundled `whisper.cpp` model (`ggml-tiny.en`).
The transcript is saved to a local SQLite database and the audio file is
deleted in the same operation. Search is full-text over the transcript
column. Export hands a JSON file to the iOS share sheet.

No accounts, no servers, no network requests. Works in airplane mode.

## Where to start

Read these in order — they are the spec for v1 and the conventions an AI
assistant should follow:

- **`CLAUDE.md`** — stack, conventions, hard "do not" list, build/run/test commands
- **`PRD.md`** — problem, target users, goals, non-goals, user journeys, success criteria
- **`ARCHITECTURE.md`** — components, data model, external surfaces, committed decisions, open questions
- **`FILE_TREE.md`** — directory layout with one-line per-path responsibility
- **`TASKS.md`** — milestone-ordered build plan

## Quick commands

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs  # drift + FFI codegen
cd ios && pod install && cd ..

flutter run -d ios            # run on simulator or device
flutter test                  # unit + widget tests (13)
flutter test integration_test # end-to-end on device (1)
flutter build ipa --release   # App Store build (requires signing identity)
```

## Repository layout

```
shower-thoughts/
├── README.md, PRD.md, ARCHITECTURE.md, CLAUDE.md, FILE_TREE.md, TASKS.md
├── pubspec.yaml, analysis_options.yaml
├── lib/                     # Dart sources (see FILE_TREE.md)
├── ios/
│   ├── Runner/              # Flutter iOS host (icon, launch screen, Info.plist)
│   └── whisper/             # vendored whisper.cpp xcframework + C-ABI wrapper
├── assets/
│   ├── icon.png             # 512px down-sample of branding/icon_1024.png (bundled)
│   └── models/              # bundled whisper.cpp model (ggml-tiny.en.bin, ~77 MB; gitignored)
├── branding/                # 1024×1024 master icon + SVG sources
├── docs/                    # GitHub Pages: privacy policy
├── appstore/                # App Store listing copy + 6.9" / iPad 13" screenshots
├── test/                    # unit + widget tests
├── integration_test/        # capture-flow contract test
└── .spikes/                 # reference: working whisper.cpp + Dart FFI spike
```

## Current state

v1.0.0+1 was submitted to Apple App Review on **2026-05-31** and is live on
TestFlight. Manual release is configured — when Apple approves, the build
has to be released from App Store Connect to go public.

All milestones M1–M9 from `TASKS.md` shipped:

| Milestone | What's there |
|---|---|
| **M1** scaffold | Flutter project, iOS-only platform, deps wired |
| **M2** persistence | Drift schema with FTS5 + triggers, DAO, `NotesRepository.commitTranscript` (audio-delete in `finally`) |
| **M3** audio capture | `record` package at 16 kHz mono PCM WAV, `NSMicrophoneUsageDescription` |
| **M4** whisper.cpp | Prebuilt v1.8.4 xcframework under `ios/whisper/`, ffigen bindings, `Isolate.run` for inference |
| **M5** capture flow | `CaptureController` sealed-state state machine, push-to-talk button, retry-on-failure |
| **M6** list / search / detail | FTS-backed live stream, debounced search, detail page |
| **M7** export | v1 JSON shape (`schema`, `exported_at`, `notes[]`), share-sheet handoff |
| **M8** responsive | iPad layout audit, `ResponsiveColumn` width cap on prose pages |
| **M9** release prep | Integration test (E2E), version `1.0.0+1`, app icon, splash with 2 s minimum, privacy policy, OSS license screen |

Post-M9 polish on `main`: App Store listing copy + 6.9" and iPad 13"
screenshots under `appstore/`, bundle ID moved to
`io.github.kilsekddd.showerThoughts`, Xcode 16 umbrella-header build
fix, and signing wired for App Store distribution.

### Roadmap (v1.1+)

Explicitly out of v1: optional `base.en` model as in-app download, FTS5
BM25 ranking, Android / iPad-specific layouts. See
[`PRD.md`](PRD.md) for the full non-goals list.

## Licensing

All third-party components are permissive (MIT or BSD-3-Clause) and OK for
commercial App Store distribution. Run-time attribution is wired in: tap
**Export → Open source licenses** in the app to see the full list, which
includes `whisper.cpp` + `ggml`, the `ggml-tiny.en` model, SQLite (public
domain), Flutter, Dart, and every pub.dev package the app ships with.

The app itself does not declare a license file. If you intend to fork,
modify, or redistribute the source, open an issue first.
