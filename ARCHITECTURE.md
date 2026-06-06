## High-level shape

shower-thoughts is a single-codebase Flutter app targeting iOS first, with responsive layouts so the same source ships unchanged to iPad and — later — Android and desktop. All capture, transcription, storage, search, and export run fully on-device. There is no backend, no account, and no network dependency for any core flow.

```
┌─────────────────────────────────────────────────────────────┐
│                       Flutter UI (Dart)                      │
│  CapturePage   NotesListPage   NoteDetailPage   ExportPage   │
└──────┬────────────────┬─────────────┬─────────────┬─────────┘
       │                │             │             │
       ▼                ▼             ▼             ▼
   AudioRecorder   NotesRepository (Drift / SQLite + FTS5)
       │                ▲             ▲             ▲
       ▼                │             │             │
   tmp/ scratch ──► TranscriptionService ──► WhisperFFI ──► whisper.cpp (bundled .ggml model)
       │                                                       (native, via Dart FFI)
       └── deleted on successful transcript commit ◄───────────┘
```

A capture round-trip is: hold push-to-talk → record to a tmp file → on release, hand the file to TranscriptionService → whisper.cpp runs synchronously on a background isolate → on success, insert the transcript row (with timestamp, duration) into SQLite and delete the tmp audio file in the same operation. Failure path keeps the audio file and surfaces a retry affordance.

## Components

**`lib/ui/`** — the Flutter widget tree. Pages are kept deliberately small: a capture page dominated by one large push-to-talk button, a list page with a search field and a sort toggle, a detail page that shows a single transcript, and an export action. UI depends on the application layer via Riverpod (or equivalent) providers; it never touches the database or FFI directly.

**`lib/app/`** — application services and state. Owns `NotesController` (list + search state), `CaptureController` (recording state machine: idle → recording → transcribing → committed / failed), and `ExportController` (assembles the JSON blob). Depends on the repository and transcription service.

**`lib/data/`** — `NotesRepository` plus the Drift database definition. The schema has one logical table (`notes`) plus an FTS5 virtual table (`notes_fts`) mirroring the `transcript` column for full-text search. Bulk export reads every row in `notes` and emits a JSON file via `dart:convert`. This layer owns the contract that audio files are deleted in the same Dart operation that commits a transcript row.

**`lib/audio/`** — `AudioRecorder` wraps the platform recorder (the `record` Flutter package, configured for 16 kHz mono PCM WAV — the format whisper.cpp expects) and writes to a single, deterministic path under the app's temp directory. Only one recording file exists at a time; a new capture overwrites it.

**`lib/transcription/`** — `TranscriptionService` orchestrates "give me a tmp audio path, return a transcript". It runs whisper inference on a background isolate so the UI stays responsive. Depends on `WhisperFFI`, which is a thin Dart-FFI binding to a bundled native library built from whisper.cpp. The whisper model file (`ggml-tiny.en.bin`, ~39 MB) is shipped as a Flutter asset and copied to the app's documents directory on first launch.

**`lib/export/`** — JSON serialization of the notes table. Produces a single `.json` file written to the app's documents directory, then handed to the OS share sheet so the user moves it off-device themselves (no in-app upload anywhere).

**`ios/` runner** — standard Flutter iOS host. The Podfile adds the prebuilt whisper.cpp framework (or builds it from source at pod-install time) and exposes it to Dart FFI. Microphone permission strings are set in `Info.plist`.

## Data model

One logical entity.

**Note**
- `id` — INTEGER PRIMARY KEY AUTOINCREMENT
- `created_at` — INTEGER (Unix epoch milliseconds, UTC). Drives default sort and timestamp display.
- `duration_ms` — INTEGER. Length of the original recording.
- `transcript` — TEXT. The transcribed text. Single-paragraph; whisper line breaks collapsed to spaces. Editable in the detail view after capture; FTS5 stays in sync via the update trigger.
- `model_id` — TEXT. Which whisper model produced this transcript (`ggml-tiny.en` for v1). Recorded so future model upgrades don't lie about provenance.
- `completed_at` — INTEGER NULL (Unix epoch milliseconds, UTC). NULL means the note is still active; a value means the user marked it complete at that timestamp. Drives the Active / Completed tab partition on the list page and the sort order on the Completed tab. Added in schema v2; the Drift `onUpgrade` migration `ALTER TABLE`s it onto shipped v1.0 installs.

Plus one virtual table:

**notes_fts** — SQLite FTS5 virtual table mirroring `notes.transcript`, with insert / update / delete triggers keeping it in sync. This is what the search box queries.

No tags, titles, folders, or categories — confirmed out of scope. No relationships; a Note stands alone.

## External surfaces

- **iOS app UI** — the only user-facing surface. One push-to-talk capture flow, one searchable list, one detail view, one export action.
- **Microphone permission** — requested on first capture attempt; denial path shows a settings deep-link.
- **Files** — produces a single `.json` export file on demand, written to the app's documents directory and handed off via the iOS share sheet.
- **No HTTP, no IPC, no URL schemes, no widgets, no Siri shortcuts in v1.** The app is intentionally a closed system.

The export JSON shape is committed here so external consumers have something stable to target. v1.1 bumped the schema to `v2` to add `completed_at`; the rest of the shape is byte-for-byte the v1 shape, so a permissive reader can treat v2 as v1-plus-one-field:

```json
{
  "schema": "shower-thoughts.export.v2",
  "exported_at": "2026-05-27T18:00:00Z",
  "notes": [
    {
      "id": 42,
      "created_at": "2026-05-20T14:33:12Z",
      "duration_ms": 8400,
      "transcript": "...",
      "model_id": "ggml-tiny.en",
      "completed_at": null
    }
  ]
}
```

`completed_at` is `null` for active notes and an ISO-8601 UTC string for completed ones. The export contains every note regardless of completion state — completion is metadata on the row, not a filter on the export.

## Key decisions and tradeoffs

**1. Persistence: Drift over SQLite (with FTS5), rejecting ObjectBox / Hive / Isar.** Drift gives a typed Dart API, supports SQLite FTS5 natively (which we need for transcript search), and ships a battle-tested iOS build. ObjectBox/Isar are faster on synthetic benchmarks but have weaker full-text-search stories and add a native dependency we don't need on top of whisper.cpp. Hive lacks real query capabilities. The user deferred this choice; Drift is the lowest-risk pick for a search-driven, text-heavy app.

**2. ASR engine: whisper.cpp via Dart FFI, rejecting Apple's Speech framework and cloud APIs.** The user explicitly cited privacy concerns about Apple's voice models. whisper.cpp runs fully on-device, with no entitlement that could leak data. The tradeoff is bundle size (the model adds ~39 MB to the IPA) and per-transcription latency (a few seconds on a tiny model vs near-realtime on Apple's). Both are acceptable given the privacy requirement and the short-clip use case.

**3. Whisper model: `ggml-tiny.en` bundled, `base.en` available as an in-app upgrade.** Tiny.en is ~39 MB and runs in roughly real-time on modern iPhones; it's accurate enough for searchable notes in the speaker's own voice and language. Larger models are downloadable post-install so the initial App Store binary stays modest. Rejected: shipping `base.en` (~74 MB) by default — adds review friction with little day-one benefit for the primary user.

**4. Audio deletion at transcript-commit time, in a single Dart operation.** The PRD makes audio retention past use a named risk. The repository's `commitTranscript(note, audioPath)` method writes the row and deletes the file in the same async function, with the delete in a `finally` so a partial failure still removes the audio. Rejected: keeping a 24-hour audio buffer "in case of correction" — user explicitly said audio needn't be retained.

**5. Responsive layouts from day one, but iOS-only release for v1.** The user said "since it's Flutter, plan for responsive" but also "iOS first, then expand". We use `LayoutBuilder` / breakpoint-driven layouts in the widget tree so the same widgets reflow on iPad and (later) Android/desktop, but we only configure and submit the iOS runner. Android/desktop runners are deliberately not added to v1 to keep the matrix small. Rejected: iPhone-only fixed layouts that would need rewriting later — saves no code now and costs real code later.

**6. Minimum iOS version: iOS 16.** Lets us assume modern Flutter, SwiftUI-era system fonts, and Dart 3 features without polyfills. iOS 16+ covers the overwhelming majority of active iPhones as of the target ship date. Rejected: iOS 14/15 — adds backport work for users the primary user does not need to serve.

## Open questions

- **Larger-model UX.** The architecture allows `base.en` (or larger) as a post-install download, but the UI for that — settings screen? one-tap upgrade banner? — isn't designed yet. Defer to a v1.1 feature; v1 ships with `tiny.en` only.
- **Search ranking.** FTS5 supports BM25 ranking. Whether the list view sorts purely by recency or by relevance when a search is active is a UX call worth running past the user once there are real transcripts to look at.
- **Background transcription.** v1 transcribes synchronously on a background isolate while the app is foregrounded. If the user backgrounds the app mid-transcription, iOS may suspend the isolate. Acceptable for v1 given typical short-clip durations; revisit if it bites.
- **Export destination.** v1 uses the iOS share sheet only. A "save to Files" shortcut would be a small future addition.
