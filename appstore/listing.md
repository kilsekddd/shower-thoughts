# App Store Connect listing — Shower Thoughts v1.0.0

Drop these straight into the App Store Connect form fields. Character
counts under each section are the Apple limit, not what's used.

---

## Name (30 char max)

```
Shower Thoughts
```
*(15 chars)*

---

## Subtitle (30 char max)

```
Voice notes, on device
```
*(22 chars — sets up the privacy hook in three words)*

---

## Primary category

**Productivity**

## Secondary category (optional)

**Utilities**

---

## Promotional text (170 char max — editable post-launch without resubmitting)

```
Push to talk. Speak. Release. Your thoughts arrive as searchable text — without ever leaving your phone. No accounts. No cloud. No network.
```
*(143 chars)*

---

## Description (4000 char max)

```
Shower Thoughts is a push-to-talk voice notes app for the thoughts that arrive in the cracks between tasks — walking, driving, the moment before you forget. Hold a button, speak, release. The recording is transcribed entirely on your device and saved as a searchable note. The audio is deleted the instant the transcript lands.

No account. No cloud. No network requests. Works in airplane mode.

— On-device speech recognition.
Powered by whisper.cpp, a tiny open-source speech model that runs on your iPhone's own silicon. Nothing about what you say is sent to a server. There is no server.

— Audio deleted on success.
The recording is treated as transient working data. The moment the transcript is committed to the local database, the audio file is removed from disk. If transcription fails, the audio is kept so you can retry — then deleted as soon as the retry succeeds.

— Search every word.
Full-text search across every transcript you've ever saved. Find the thought you had on Tuesday by typing two words from it.

— Export when you need it.
One tap produces a JSON file of every note and hands it to the iOS share sheet. Save it to Files, send it to yourself, drop it into another app — it's your data.

— Built for thinking, not curation.
No tags, no folders, no categories. Search is the only way back to a note, because curating is the work this app was designed to avoid.

Privacy specifics:
• No data ever leaves your device — there is no server to send it to
• No analytics, no telemetry, no third-party SDKs collecting anything
• Microphone access is used only while you are actively holding the record button
• Open source: github.com/kilsekddd/shower-thoughts
```
*(1850 chars)*

---

## Keywords (100 char max, comma-separated, NO spaces after commas)

```
voice notes,push to talk,on device,offline,dictation,transcription,speech to text,journal,memo
```
*(94 chars)*

---

## Support URL

```
https://github.com/kilsekddd/shower-thoughts/issues
```

## Marketing URL (optional)

```
https://kilsekddd.github.io/shower-thoughts/
```

## Privacy policy URL

```
https://kilsekddd.github.io/shower-thoughts/
```

---

## What's New in This Version (release notes — 4000 char max)

```
First public release. Hold the microphone button on the Capture tab, speak, release. Your thought arrives as a searchable note within a few seconds — entirely on-device.
```
*(170 chars — short by design for a v1)*

---

## App Review Information

### Demo account

Not applicable — the app has no login.

### Notes for App Review

```
Shower Thoughts is a push-to-talk voice notes app. There is no signup and no demo content required.

To test:
1. Launch the app. On first launch the splash will display for a couple of seconds while the on-device speech-recognition model is initialized from the bundled asset.
2. Tap the Capture tab (default). The large blue circular button is the record control.
3. Press and HOLD the button for a few seconds while speaking. iOS will ask for microphone permission the first time — grant it.
4. Release the button. The status text will change to "Transcribing…" while the recording is processed on-device via the bundled whisper.cpp model. This typically takes 2–5 seconds.
5. On success, the status changes to "Saved." and the audio recording is automatically deleted from the device. The transcript appears on the Notes tab.
6. Tap the Notes tab to see saved transcripts. Tap any row to see the full text.
7. The Export tab writes a JSON file of all notes and opens the iOS share sheet.

The app makes no network requests for any core flow and works in airplane mode. All speech recognition is performed on-device. No data is collected. The privacy policy is at https://kilsekddd.github.io/shower-thoughts/

Open-source license attribution for every bundled component is reachable from the Export tab via the "Open source licenses" button.
```

---

## Privacy nutrition label — Data Types

Apple's privacy form asks per-category. For every category, the answer is the same:

**Data Not Collected**

The form will ask several follow-ups:
- "Does your app collect any data from this app?" → **No**
- After "No": the form closes out. Confirm.

---

## Export Compliance (asked on every build upload)

- "Does your app use encryption?" → **No** (the app contains no encryption code; it makes no network calls and stores data in an unencrypted local SQLite database under iOS's standard data protection)

If Apple's form pushes back: select **"My app uses non-exempt encryption" → "My app only uses encryption that is exempt"** and pick *"App only uses standard system encryption"* (iOS's filesystem encryption counts).

---

## Content Rights

- "Does your app contain, show, or access third-party content?" → **No** (the app only displays the user's own transcripts and bundled open-source license text. No third-party content is fetched at runtime.)

---

## Age Rating Questionnaire

Every question: **None** / **No**.

- Cartoon or fantasy violence: No
- Realistic violence: No
- Sexual content: No
- Profanity or crude humor: No
- Alcohol, tobacco, or drug use or references: No
- Mature/suggestive themes: No
- Horror/fear themes: No
- Medical/treatment information: No
- Gambling: No
- Unrestricted web access: No
- User-generated content: No (transcripts are local-only; there is no sharing-to-others feature)

Expected rating: **4+**

---

## Pricing & availability

- **Price**: Free (or your call)
- **Availability**: All territories (or restrict to your home country only for the v1 launch, then expand)

---

## Screenshots

Located in: `appstore/screenshots-1290x2796/`

Upload order (Apple shows them in the order you upload):

1. `capture.png` — hero shot of the push-to-talk button
2. `notes.png` — list with sample notes, demonstrating density + relative timestamps
3. `detail.png` — full transcript view (Selectable text + duration + model)
4. `export.png` — export button + licenses link visible

The 1290×2796 size is Apple's "6.7-inch iPhone" requirement, captured on iPhone 17 Pro Max simulator and downscaled to match.
