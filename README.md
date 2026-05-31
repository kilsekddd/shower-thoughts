# shower-thoughts

Push-to-talk voice notes, transcribed on-device, fully offline. Flutter iOS app; iPad / Android / desktop are deliberately later.

## Where to start

Read these in order — they are the canonical spec for v1 and the conventions an AI assistant should follow:

- **`CLAUDE.md`** — stack, conventions, hard "do not" list, build/run/test commands
- **`PRD.md`** — problem, target users, goals, non-goals, user journeys, success criteria
- **`ARCHITECTURE.md`** — components, data model, external surfaces, committed decisions, open questions
- **`FILE_TREE.md`** — directory layout with one-line per-path responsibility
- **`TASKS.md`** — milestone-ordered build plan

## Quick commands

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # drift + FFI codegen
cd ios && pod install && cd ..
flutter run -d ios            # run on simulator or device
flutter test                  # unit + widget tests
flutter test integration_test # end-to-end on device
flutter build ipa --release   # App Store build
```

## Repository layout

```
shower-thoughts/
├── PRD.md, ARCHITECTURE.md, CLAUDE.md, FILE_TREE.md, TASKS.md, manifest.json
├── pubspec.yaml, analysis_options.yaml
├── lib/                  # Dart sources (see FILE_TREE.md)
├── ios/                  # iOS runner + whisper.cpp integration
├── assets/models/        # bundled whisper.cpp model (ggml-tiny.en.bin, ~77 MB)
├── test/, integration_test/
└── .spikes/              # reference: working whisper.cpp + Dart FFI spike
```

## Current state

- **M1 (scaffold):** ✅ committed on `main` — project compiles, smoke test green, app boots to a Capture / Notes / Export bottom-nav scaffold with placeholder pages.
- **M2 (persistence):** WIP on branch `feat/m2-persistence` (one partial commit — drift schema + DAO started by a sub-agent that was interrupted). Re-run or finish manually.
- **M4-prep (whisper iOS plumbing):** branch `feat/m4-whisper-prep` exists but has no commits beyond `main`; the agent had only downloaded the model before being stopped. The model file was rescued to `assets/models/ggml-tiny.en.bin` and is untracked at the project root.

## Known follow-ups

- The 77 MB whisper model in `assets/models/` is too big for vanilla git. Decide on git-lfs vs `.gitignore` + fetch-on-build before committing.
- `record_darwin` plugin emits a Swift Package Manager deprecation warning during analyze; non-blocking but flagged.
- The `feat/m2-persistence` WIP commit (`24d4867`) should be reviewed before re-spawning the M2 agent — it may save time, or may be cleaner to discard.
