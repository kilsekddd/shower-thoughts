```
shower-thoughts/
├── pubspec.yaml
├── analysis_options.yaml
├── README.md
├── CLAUDE.md
├── PRD.md
├── ARCHITECTURE.md
├── TASKS.md
├── assets/
│   ├── models/
│   │   └── ggml-tiny.en.bin
│   └── sounds/
│       ├── start.wav
│       └── stop.wav
├── tool/
│   └── generate_cues.dart
├── lib/
│   ├── main.dart
│   ├── app/
│   │   ├── app.dart
│   │   ├── router.dart
│   │   ├── capture_controller.dart
│   │   ├── notes_controller.dart
│   │   ├── export_controller.dart
│   │   └── providers.dart
│   ├── ui/
│   │   ├── theme.dart
│   │   ├── layout/
│   │   │   └── responsive.dart
│   │   ├── pages/
│   │   │   ├── capture_page.dart
│   │   │   ├── notes_list_page.dart
│   │   │   ├── note_detail_page.dart
│   │   │   └── export_page.dart
│   │   └── widgets/
│   │       ├── push_to_talk_button.dart
│   │       ├── note_tile.dart
│   │       └── search_field.dart
│   ├── data/
│   │   ├── database.dart
│   │   ├── database.g.dart
│   │   ├── notes_dao.dart
│   │   ├── notes_repository.dart
│   │   └── settings_repository.dart
│   ├── audio/
│   │   ├── audio_recorder.dart
│   │   ├── audio_paths.dart
│   │   ├── cue_player.dart
│   │   └── haptic_adapter.dart
│   ├── transcription/
│   │   ├── transcription_service.dart
│   │   ├── whisper_ffi.dart
│   │   ├── whisper_bindings.dart
│   │   └── model_assets.dart
│   └── export/
│       └── json_exporter.dart
├── ios/
│   ├── Runner/
│   │   └── Info.plist
│   ├── Podfile
│   └── whisper/
│       └── (prebuilt whisper.cpp xcframework or build script)
├── test/
│   ├── data/
│   │   └── notes_repository_test.dart
│   ├── app/
│   │   └── capture_controller_test.dart
│   ├── export/
│   │   └── json_exporter_test.dart
│   └── transcription/
│       └── transcription_service_test.dart
└── integration_test/
    └── capture_flow_test.dart
```

- `pubspec.yaml` — Flutter project manifest. Declares Dart SDK constraint, dependencies (`drift`, `sqlite3_flutter_libs`, `record`, `path_provider`, `share_plus`, `riverpod` or equivalent), and the `assets/models/` directory.
- `analysis_options.yaml` — lints. Enable `flutter_lints` plus strict-mode flags so the analyzer matches the "no overengineering" posture.
- `CLAUDE.md`, `PRD.md`, `ARCHITECTURE.md`, `TASKS.md` — the four decomposition artifacts; AI assistants read CLAUDE.md first.
- `assets/models/ggml-tiny.en.bin` — bundled whisper model. Shipped as a Flutter asset and copied to the app's documents directory on first launch.
- `assets/sounds/start.wav` / `assets/sounds/stop.wav` — short rising / falling sine-sweep cues (~6.6 KB each, 22050 Hz mono 16-bit PCM) played at recording start and end. Synthesised, not recorded.
- `tool/generate_cues.dart` — standalone Dart script that synthesises the two cue WAVs. Kept in-repo so the cues can be re-shaped (frequency, length, envelope) without an external audio tool.
- `lib/main.dart` — Flutter entrypoint. Initializes the database, copies the bundled model on first launch, wires Riverpod, and runs the app.
- `lib/app/app.dart` — top-level `MaterialApp` with theme and router.
- `lib/app/router.dart` — route table for the four pages.
- `lib/app/capture_controller.dart` — state machine for a capture round-trip (idle / recording / transcribing / committed / failed).
- `lib/app/notes_controller.dart` — list and search state for the notes list page.
- `lib/app/export_controller.dart` — orchestrates the JSON export action.
- `lib/ui/theme.dart` — minimal theme; intentionally small to discourage UI overreach.
- `lib/ui/layout/responsive.dart` — breakpoint helpers so the same widget tree reflows for iPhone / iPad / future desktop.
- `lib/ui/pages/capture_page.dart` — push-to-talk page; one large button, glanceable status.
- `lib/ui/pages/notes_list_page.dart` — searchable, sorted list of notes.
- `lib/ui/pages/note_detail_page.dart` — single transcript view.
- `lib/ui/pages/export_page.dart` — triggers the JSON export and hands the file to the share sheet.
- `lib/ui/widgets/push_to_talk_button.dart` — the hold-to-record button; fires `onStart` / `onStop`.
- `lib/ui/widgets/note_tile.dart` — list item showing timestamp and transcript snippet.
- `lib/ui/widgets/search_field.dart` — search input wired to `notes_fts`.
- `lib/data/database.dart` — Drift database definition including the `notes` table and the `notes_fts` virtual table plus triggers.
- `lib/data/database.g.dart` — generated Drift code; do not hand-edit.
- `lib/data/notes_dao.dart` — typed queries for inserts, searches, and bulk reads.
- `lib/data/notes_repository.dart` — the contract layer; owns `commitTranscript(note, audioPath)` which inserts the row and deletes the audio file in the same operation.
- `lib/data/settings_repository.dart` — thin typed wrapper over `shared_preferences`. First setting is `RecordGesture` (hold / toggle); shape is one private key per setting so future settings mirror it.
- `lib/audio/audio_recorder.dart` — wraps the `record` package, configured for 16 kHz mono PCM WAV.
- `lib/audio/audio_paths.dart` — single source of truth for the deterministic tmp recording path.
- `lib/audio/cue_player.dart` — pre-loads the start / stop cue WAVs and exposes fire-and-forget `playStart()` / `playStop()` via `audioplayers`.
- `lib/audio/haptic_adapter.dart` — abstraction over `flutter/services` `HapticFeedback` (`startCue` = medium impact, `stopCue` = light impact) so the controller can be tested without real haptics.
- `lib/transcription/transcription_service.dart` — runs whisper inference on a background isolate; consumes an audio path, returns transcript text.
- `lib/transcription/whisper_ffi.dart` — Dart FFI wrapper over whisper.cpp.
- `lib/transcription/whisper_bindings.dart` — generated FFI bindings (via `ffigen`).
- `lib/transcription/model_assets.dart` — first-launch copy of the bundled model from app bundle to documents directory.
- `lib/export/json_exporter.dart` — serializes the `notes` table to the v1 export JSON schema.
- `ios/Runner/Info.plist` — sets `NSMicrophoneUsageDescription` and any other required keys.
- `ios/Podfile` — adds the prebuilt whisper.cpp xcframework (or builds from source via a podspec).
- `ios/whisper/` — prebuilt whisper.cpp xcframework or its build script.
- `test/` — unit tests scoped to one component per file; the repository, controller, exporter, and transcription service are the load-bearing units to cover.
- `integration_test/capture_flow_test.dart` — end-to-end test of record → transcribe → commit → audio-deleted, run via `flutter test integration_test/`.
