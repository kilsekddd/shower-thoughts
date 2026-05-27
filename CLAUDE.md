# shower-thoughts

shower-thoughts is a Flutter iOS app for push-to-talk voice notes that get transcribed fully on-device, stored locally with timestamp metadata, and made searchable. Audio is treated as transient working data and is deleted as soon as transcription succeeds. The app has no backend, no account, and no network dependency for any core flow.

## Stack

- **Language / framework:** Dart 3 + Flutter (stable channel). Minimum iOS deployment target is iOS 16.
- **Persistence:** SQLite via the `drift` package, with an `FTS5` virtual table mirroring the `transcript` column for search.
- **Audio capture:** the `record` package, configured for 16 kHz mono PCM WAV (the format whisper.cpp expects).
- **Speech-to-text:** whisper.cpp, called via Dart FFI. Default bundled model is `ggml-tiny.en.bin` (~39 MB), shipped as a Flutter asset and copied to the documents directory on first launch.
- **State management:** Riverpod (or `flutter_riverpod`) for app-layer providers.
- **Sharing / export:** `share_plus` to hand the export JSON file to the iOS share sheet.
- **File paths:** `path_provider` for documents / temp directories.
- **Deployment:** iOS App Store first. Android, iPad-specific layouts, and desktop targets are explicitly later.

## Conventions

- **Architecture:** UI → app (controllers / providers) → data (`NotesRepository`) → database / FFI. Never let a widget reach into Drift or FFI directly.
- **Capture contract:** the only path that ever writes to or deletes the audio scratch file is `NotesRepository.commitTranscript(note, audioPath)`. It inserts the transcript row and deletes the audio file in the same async operation, with the deletion in a `finally` block so a partial failure still removes the audio.
- **Naming:** snake_case for files, lowerCamelCase for Dart identifiers, PascalCase for types. The product / package / app display name is `shower-thoughts` (Dart package name is `shower_thoughts` because of pub.dev rules).
- **Responsive layouts:** use `LayoutBuilder` or the helpers in `lib/ui/layout/responsive.dart`. Do not hard-code phone-only sizes even though v1 ships iOS-only.
- **Asynchrony:** transcription runs on a background isolate via `Isolate.run` (or a `compute`-style helper). The UI thread never blocks on whisper inference.
- **Errors:** surface transcription failures back to `CaptureController` so the UI can show a retry affordance. The audio file is kept on failure so the user can retry; it is deleted only on success.
- **Testing:** unit tests live next to their layer in `test/<layer>/`. The repository, capture controller, exporter, and transcription service are the four units that must stay covered. The end-to-end record → transcribe → commit → delete-audio path lives in `integration_test/capture_flow_test.dart`.
- **Generated code:** `lib/data/database.g.dart` and `lib/transcription/whisper_bindings.dart` are generated. Re-run the generator instead of hand-editing.

## Avoid

- **Do not add cloud sync, sharing-to-people, AI summarization, multi-device, or speaker identification.** These are explicit non-goals for v1. If a feature request implies them, push back before implementing.
- **Do not add user-curated structure** — no tags, titles, folders, or categories. Search is the only retrieval mechanism.
- **Do not keep audio files past successful transcription.** Audio retention is a named risk in the PRD; any path that writes to the audio scratch must have a guaranteed delete-on-success.
- **Do not call Apple's Speech framework, SiriKit, or any cloud STT API.** The on-device-only constraint is privacy-driven, not a performance preference.
- **Do not add network calls** for any core flow. The app must work in airplane mode.
- **Do not overengineer the UI.** "UI too overengineered" is a named risk; prefer one screen and one action over abstraction layers, theme systems, or animation frameworks beyond Flutter defaults.
- **Do not silently change the export JSON shape.** The `"schema": "shower-thoughts.export.v1"` field is a contract; if the shape needs to change, bump the schema version.
- **Do not add platform runners (Android / macOS / Windows / Linux / web) in v1.** Keep the build matrix to iOS only.

## How to run / build / test

```bash
# One-time setup
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generates Drift + FFI bindings
cd ios && pod install && cd ..

# Run on a connected iPhone or simulator
flutter run -d ios

# Unit + widget tests
flutter test

# End-to-end capture flow on a device
flutter test integration_test/

# Release build for App Store submission
flutter build ipa --release
```

The bundled whisper model lives at `assets/models/ggml-tiny.en.bin` and is referenced in `pubspec.yaml`. If it is missing, `flutter pub get` will not fetch it — download it from the whisper.cpp release page and place it there manually.
