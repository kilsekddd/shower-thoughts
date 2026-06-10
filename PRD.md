## Problem

Capturing a thought while walking, driving, or mid-task at a desk usually means losing it — typing is too slow, and cloud-backed voice assistants raise legitimate privacy concerns. There is no friction-free way to dictate a private note, get a searchable transcript, and trust that nothing leaves the device.

shower-thoughts is a push-to-talk capture app that records short voice notes, transcribes them on-device, discards the audio once transcription succeeds, and keeps the resulting text in a local store the user can search, sort, filter, and bulk-export as JSON.

## Target users

- **Primary, v1:** a single developer (the author) using it on their own iPhone while walking, driving, or having a stray thought at their desk.
- **Secondary, later:** general iOS App Store users with the same shape of need — privacy-conscious voice capture without cloud round-trips. Expansion to iPad, Android, and desktop is a known future direction, which is why the codebase is responsive from day one even though v1 only ships to iOS.

## Goals

- Capture a thought in one tap and one held button — the app must be usable without looking at the screen.
- Run speech-to-text fully on-device so no audio or transcript ever leaves the phone.
- Delete the audio file as soon as transcription succeeds; treat audio as transient working data, not stored content.
- Persist transcripts locally with timestamp and duration metadata.
- Let the user search, sort by time, and filter their transcripts.
- Provide a bulk JSON export of all transcripts for use in other tools.
- Ship to the iOS App Store first; structure the codebase so iPad / Android / desktop expansion is a layout problem, not a rewrite.

## Non-goals

Explicitly out of scope for v1:

- Cloud sync of any kind (no iCloud, no third-party backend).
- Sharing notes to other people from inside the app.
- AI summarization, classification, or other LLM post-processing of transcripts.
- Multi-device usage on a single account.
- Speaker identification or diarization.
- User-curated structure on notes — no tags, titles, folders, or categories. Search is the only retrieval mechanism the user is expected to use. (v1.1 adds a binary "completed" lifecycle state — see the v1.1 section below. This is intentionally not a user-defined taxonomy.)
- Long-term audio retention or playback of original recordings after transcription.

## User journeys

**1. Walking, single thought.** The user is walking and has an idea about a project. They pull out their phone, press and hold a large push-to-talk button, speak for ten seconds, and release. The app shows a confirmation that transcription is underway, then displays the transcript in a fresh list entry timestamped to "just now". The audio file is deleted in the background. The user returns the phone to their pocket without further interaction.

**2. Driving, several thoughts in sequence.** The user is driving and has three loosely related thoughts over five minutes. They hold and release the push-to-talk control three times. Each note becomes its own entry — there is no merging or threading. Later, parked, they open the app and scroll the list, which is sorted newest-first.

**3. Looking up a past thought.** A week later the user remembers having said something about "rendering pipeline". They open the app, type "rendering" into search, and see the matching entry with its date. They tap it to read the full transcript.

**4. Bulk export.** After a month of use, the user wants to feed their transcripts into another tool. They open the app's export action, get a single JSON file containing every note (timestamp, duration, transcript), and AirDrop or share-sheet it off the device themselves.

## Success criteria

- Push-to-talk capture works one-handed without looking at the screen.
- 100% of audio files are deleted from the device once their transcript is committed to the store; this is verifiable by inspecting the app's storage.
- The app functions with airplane mode on — no network call is required for any core flow (capture, transcribe, search, export).
- Transcription accuracy on the chosen on-device model is good enough that the resulting text is searchable for the speaker's own intent, even if not word-perfect.
- The user can find a past thought from memory of a keyword in under five seconds via search.
- The JSON export round-trips: every note in the store appears in the export with timestamp, duration, and transcript text.
- The app passes App Store review on first or second submission.
- The UI stays small enough that adding a new feature requires an explicit justification — "no overengineering" is a measurable design constraint.

## v1.1 additions

Shipped on top of v1.0 once the App Store version was live. The capture flow, on-device transcription, audio-delete contract, search behavior, and non-goals all carry forward unchanged.

**1. Completed lifecycle.** Every note has a `completed_at` timestamp that is `null` while active and stamped UTC when the user marks the note complete. The notes list grew a two-tab partition (Active / Completed); Active is sorted by `created_at` newest-first, Completed by `completed_at` newest-first. Completion is a single binary lifecycle state, not a free-form category — see the non-goals note above.

**2. Swipe-to-reveal actions.** The list tile reveals two actions on left-swipe: complete/reopen (depending on which tab) and delete. Delete is permanent — no trash, no undo — and confirmed via dialog before destroying the row.

**3. Editable transcripts.** The detail page now hosts an editable text field with Save / Cancel actions in the app bar, plus a complete/reopen toggle and a delete button. The back gesture confirms before discarding unsaved edits. Edits go straight into the FTS index via the existing update trigger, so search stays in sync.

**4. Export schema v2.** Each note row gains a `"completed_at"` field (ISO-8601 UTC string or `null`); the rest of the v1 shape is byte-for-byte preserved. Schema tag bumps to `shower-thoughts.export.v2`. The export still contains every note regardless of completion state.

**5. Bounded recording + silent-truncation guard.** A single recording is hard-capped at 10 minutes; the cap fires whether the user holds the button forever, walks away with it stuck down, or simply forgets a toggle-mode session running. The native whisper.cpp wrapper now returns a distinct error code when its output buffer can't hold the full transcript (previously it silently truncated mid-sentence); the FFI layer grows the buffer and retries once before surfacing the failure.

**6. Toggle record mode.** Users can switch the capture button between push-to-talk (hold) and toggle (tap-to-start, tap-to-stop) via a segmented control on the capture screen. The 10-minute cap is what makes the toggle option safe — without it, a forgotten session would record indefinitely. The mode preference persists across launches in a small extensible `SettingsRepository` (the first of what may be several settings).

**7. Recording cues.** A short rising tone + medium-impact haptic fire at recording start, and a short falling tone + light-impact haptic at recording end. Audible to people in the area (so they know they're being captured) and eyes-off confirmation for the user. Cues fire outside the recorder window so they don't bleed into the WAV. Both gesture modes use the same cues, including the cap-triggered auto-stop path.

The non-goals from v1.0 still hold: no soft-delete or trash, no cloud sync, no AI summarization, no user-defined categories, no audio retention.
