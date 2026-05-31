# shower-thoughts

Push-to-talk voice notes, transcribed on-device, fully offline. Flutter iOS
app; iPad / Android / desktop are deliberately later.

- **Privacy policy:** https://kilsekddd.github.io/shower-thoughts/
- **Issues / contact:** https://github.com/kilsekddd/shower-thoughts/issues

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
├── README.md, PRD.md, ARCHITECTURE.md, CLAUDE.md, FILE_TREE.md, TASKS.md, manifest.json
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
├── test/                    # unit + widget tests
├── integration_test/        # capture-flow contract test
└── .spikes/                 # reference: working whisper.cpp + Dart FFI spike
```

## Current state

All milestones M1–M9 from `TASKS.md` have shipped on `main`:

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

### What's left for App Store ship

Code is done. The remaining work is on the developer side, not the codebase:

1. Set `DEVELOPMENT_TEAM` in Xcode (Runner target → Signing & Capabilities)
2. `flutter build ipa --release` with your signing identity
3. Upload via Transporter / Xcode → App Store Connect
4. Fill in App Store Connect metadata: description, keywords, screenshots, age rating, privacy nutrition labels (all "Data Not Collected"), export compliance ("exempt — no encryption")
5. TestFlight internal beta on a real device
6. Submit for review

## Licensing

All third-party components are permissive (MIT or BSD-3-Clause) and OK for
commercial App Store distribution. Run-time attribution is wired in: tap
**Export → Open source licenses** in the app to see the full list, which
includes `whisper.cpp` + `ggml`, the `ggml-tiny.en` model, SQLite (public
domain), Flutter, Dart, and every pub.dev package the app ships with.

The app itself does not declare a license file. If you intend to fork,
modify, or redistribute the source, open an issue first.
