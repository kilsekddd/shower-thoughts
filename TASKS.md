# Build plan

## Milestone 1: skeleton

- [ ] Scaffold the Flutter project with iOS-only platform support (`flutter create --platforms=ios shower_thoughts`) and set the iOS deployment target to 16.0 in `ios/Podfile`.
- [ ] Pin Dart SDK and Flutter constraint in `pubspec.yaml`; add `flutter_lints` and enable strict-analysis flags in `analysis_options.yaml`.
- [ ] Add core dependencies to `pubspec.yaml`: `drift`, `sqlite3_flutter_libs`, `drift_dev`, `build_runner`, `record`, `path_provider`, `share_plus`, `flutter_riverpod`, `ffi`, `ffigen`.
- [ ] Commit the four decomposition artifacts at the repo root: `PRD.md`, `ARCHITECTURE.md`, `CLAUDE.md`, `TASKS.md`.
- [ ] Create the `lib/` directory skeleton matching FILE_TREE.md (`app/`, `ui/`, `data/`, `audio/`, `transcription/`, `export/`) with placeholder files so imports resolve.
- [ ] Wire `lib/main.dart` to bootstrap `MaterialApp` via `lib/app/app.dart` and `lib/app/router.dart` with empty page stubs.

## Milestone 2: persistence

- [ ] Define the `notes` table in `lib/data/database.dart` with `id`, `created_at`, `duration_ms`, `transcript`, `model_id`.
- [ ] Add the `notes_fts` FTS5 virtual table and the insert / update / delete triggers that keep it in sync with `notes.transcript`.
- [ ] Run `dart run build_runner build --delete-conflicting-outputs` and commit `lib/data/database.g.dart`.
- [ ] Implement `NotesDao` in `lib/data/notes_dao.dart` with: `insertNote`, `searchByText`, `listAllNewestFirst`, `getById`, `deleteById`.
- [ ] Implement `NotesRepository` in `lib/data/notes_repository.dart` exposing `commitTranscript(note, audioPath)` — must insert the row and delete the audio file in one operation with the delete in a `finally`.
- [ ] Write `test/data/notes_repository_test.dart` covering: commit happy path, commit when audio file missing, search by token, search by substring fragment, ordering by `created_at` desc.

## Milestone 3: audio capture

- [ ] Implement `AudioRecorder` in `lib/audio/audio_recorder.dart` wrapping the `record` package; configure 16 kHz mono PCM WAV output.
- [ ] Implement `lib/audio/audio_paths.dart` returning a single deterministic path under the app's temp directory.
- [ ] Add `NSMicrophoneUsageDescription` to `ios/Runner/Info.plist` with a one-line privacy-first rationale.
- [ ] Manually verify on a device: hold-to-record produces a playable WAV at the expected path.

## Milestone 4: whisper.cpp integration

- [ ] Add whisper.cpp as a prebuilt xcframework under `ios/whisper/` and reference it from `ios/Podfile`.
- [ ] Author the `ffigen` config and generate `lib/transcription/whisper_bindings.dart` from the whisper.cpp public header.
- [ ] Implement `WhisperFFI` in `lib/transcription/whisper_ffi.dart` exposing `transcribe(audioPath, modelPath) -> String`.
- [ ] Ship `assets/models/ggml-tiny.en.bin` and register it under `assets:` in `pubspec.yaml`.
- [ ] Implement `lib/transcription/model_assets.dart` to copy the bundled model from the app bundle to the documents directory on first launch.
- [ ] Implement `TranscriptionService` in `lib/transcription/transcription_service.dart` that runs `WhisperFFI.transcribe` on a background isolate (`Isolate.run`) and returns the transcript.
- [ ] Write `test/transcription/transcription_service_test.dart` against a short fixture WAV; assert non-empty transcript and that the isolate completes without blocking.

## Milestone 5: capture flow

- [ ] Implement `CaptureController` in `lib/app/capture_controller.dart` as a Riverpod `StateNotifier` modeling `idle → recording → transcribing → committed | failed`.
- [ ] Wire `CaptureController` to call `AudioRecorder` on start/stop, then `TranscriptionService`, then `NotesRepository.commitTranscript`.
- [ ] Build `lib/ui/widgets/push_to_talk_button.dart` — a large, glanceable hold-to-record control with onStart / onStop callbacks.
- [ ] Build `lib/ui/pages/capture_page.dart` using the button and surfacing the controller's current state.
- [ ] Add a retry affordance for the `failed` state that re-runs transcription against the still-on-disk audio.
- [ ] Write `test/app/capture_controller_test.dart` covering: happy path, transcription failure keeps audio, successful retry commits and deletes audio.

## Milestone 6: list, search, detail

- [ ] Implement `NotesController` in `lib/app/notes_controller.dart` exposing a sortable, FTS-searchable stream of notes.
- [ ] Build `lib/ui/widgets/note_tile.dart` showing relative timestamp + transcript snippet.
- [ ] Build `lib/ui/widgets/search_field.dart` debounced and wired to `NotesController`.
- [ ] Build `lib/ui/pages/notes_list_page.dart` combining search field + sort toggle + tile list.
- [ ] Build `lib/ui/pages/note_detail_page.dart` displaying the full transcript and the timestamp.
- [ ] Add the route entries in `lib/app/router.dart` and a tab or nav affordance between capture and list.

## Milestone 7: export

- [ ] Implement `lib/export/json_exporter.dart` producing the v1 export JSON shape (`schema`, `exported_at`, `notes[]`) into the documents directory.
- [ ] Implement `ExportController` in `lib/app/export_controller.dart` invoking the exporter then `share_plus` for the share-sheet handoff.
- [ ] Build `lib/ui/pages/export_page.dart` with one button: "Export all notes as JSON".
- [ ] Write `test/export/json_exporter_test.dart` round-tripping a populated DB → JSON → asserting every row appears and the `schema` field is set.

## Milestone 8: responsive layout pass

- [ ] Implement `lib/ui/layout/responsive.dart` with breakpoint helpers (compact / medium / expanded).
- [ ] Audit all four pages to use the responsive helpers; verify in the iPad simulator that nothing is hard-pinned to phone widths.
- [ ] Keep the iOS-only platform configuration; do not add Android / macOS / web runners.

## Milestone 9: end-to-end + release prep

- [ ] Write `integration_test/capture_flow_test.dart` covering: record short clip → transcribe → commit → assert transcript row exists → assert audio file is gone.
- [ ] Run `flutter test` and `flutter test integration_test/` on a real device; fix anything red.
- [ ] Verify airplane-mode operation: every flow (capture, transcribe, search, export) works with all networking off.
- [ ] Set the app display name and bundle identifier in `ios/Runner/Info.plist` and the Xcode project.
- [ ] Produce a release build (`flutter build ipa --release`) and validate it against App Store Connect.
- [ ] Submit to TestFlight, then App Store review.

## Milestone 10: completed lifecycle (data layer)

Shipped on top of v1.0.

- [x] Add nullable `completed_at INTEGER` column to the `notes` table; bump Drift `schemaVersion` to 2; add `onUpgrade` that `ALTER TABLE`s the column onto shipped v1.0 installs.
- [x] Regenerate `lib/data/database.g.dart`.
- [x] Extend `NotesDao` with `setCompleted`, `updateTranscript`, `watchActiveNewestFirst`, `watchCompletedNewestFirst`, `watchById`, and tab-filtered FTS variants (`watchSearchActive`, `watchSearchCompleted`).
- [x] Extend `NotesRepository` with `markCompleted({at})`, `markActive`, `updateTranscript`, plus the new watch variants. `commitTranscript` is unchanged.
- [x] Update `test/data/notes_repository_test.dart` to cover lifecycle transitions, edit-to-FTS propagation, hard-delete-to-FTS purge, and tab-scoped search.
- [x] Verify the migration on a real v1.0 install on a device (notes survive, no crash).

## Milestone 11: list screen tabs + swipe-reveal

- [x] Add `flutter_slidable` to `pubspec.yaml`.
- [x] Replace `notesStreamProvider` with `notesActiveStreamProvider` + `notesCompletedStreamProvider`. Flip `noteByIdProvider` to a `StreamProvider` so the detail page reacts to deletes.
- [x] Rewrite `lib/ui/pages/notes_list_page.dart` with a `TabBar` (Active / Completed) and a search field above the tabs that filters whichever tab is active.
- [x] Wrap each `NoteTile` in `Slidable` with an end-action pane: Complete/Reopen + Delete. Delete confirms via `CupertinoAlertDialog` before destroying the row.

## Milestone 12: detail screen edit + delete

- [x] Convert `lib/ui/pages/note_detail_page.dart` to `ConsumerStatefulWidget` with an always-editable multiline `TextField` seeded from the loaded transcript.
- [x] App bar actions: Cancel + Save while dirty; complete/reopen toggle + Delete while clean. Back gesture confirms before discarding unsaved edits via `PopScope`.
- [x] Wire Save → `updateTranscript`, complete/reopen → `markCompleted`/`markActive`, Delete → confirm + `deleteById` + pop.

## Milestone 13: export schema v2

- [x] Bump exporter to `shower-thoughts.export.v2`; add `completed_at` (ISO-8601 UTC string or `null`) to each note row in the JSON. Order of v1 fields preserved.
- [x] Update `test/export/json_exporter_test.dart`: assert `v2` tag, `completed_at` is present-and-null on active notes, ISO-stringified on completed notes, and that the export contains both active and completed rows.
- [x] Document the v2 shape in `ARCHITECTURE.md`; add a "v1.1 additions" section to `PRD.md`.

## Milestone 14: max recording duration + transcript truncation detection

Closes the silent-data-loss timebomb where a stuck or pocket-pressed button could record indefinitely and silently truncate the transcript when whisper's output exceeded the FFI buffer.

- [x] `ios/whisper/wrapper.cpp` returns the new `-8` ("transcript would not fit in out_buf") instead of silently truncating + returning a positive count. Partial transcript is written into `out_buf` for diagnostics. `ios/whisper/wrapper.h` documents the new code.
- [x] `lib/transcription/whisper_ffi.dart` raises the default output buffer from 16 KiB to 64 KiB and retries once at 256 KiB on `-8` before throwing `WhisperException`.
- [x] `lib/app/capture_controller.dart` enforces a 10-minute hard cap on a single recording via an injectable `maxDuration`. A `Timer` started on `CaptureRecording` transition auto-calls `stopRecording` on fire and pipes an `autoStoppedByCap` flag through to `CaptureTranscribing` / `CaptureCommitted` / `CaptureFailed`. Cancelled on stop, abort, and dispose.
- [x] `lib/ui/pages/capture_page.dart` surfaces "Recording reached the 10-minute cap." in the transcribing and saved status panels when the flag is set, so the user understands their hold was cut short.
- [x] `test/app/capture_controller_test.dart` covers the cap path with a 50 ms `maxDuration` injected via the ctor: confirms the cap-triggered commit carries `autoStoppedByCap: true` and a normal stop carries `false`.

## Out of scope (not scheduled)

The PRD lists these explicitly out for v1; do not schedule work for them:

- Cloud sync (iCloud or otherwise)
- Sharing notes to other people from inside the app
- AI summarization, classification, or any LLM post-processing of transcripts
- Multi-device usage on a single account
- Speaker identification or diarization
- User-curated structure: tags, titles, folders, categories
- Audio retention or playback after transcription
- Android, iPad-specific layouts beyond responsive reflow, and desktop release
- Larger whisper models bundled by default (`base.en` and above are a v1.1 in-app upgrade path)
