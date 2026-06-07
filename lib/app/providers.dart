import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/audio_recorder.dart';
import '../data/database.dart';
import '../data/notes_dao.dart';
import '../data/notes_repository.dart';
import '../data/settings_repository.dart';
import '../export/json_exporter.dart';
import '../transcription/model_assets.dart';
import '../transcription/transcription_service.dart';
import 'capture_controller.dart';
import 'export_controller.dart';
import 'notes_controller.dart';

/// Overridden in `main.dart` after the database is opened so widgets can read
/// it synchronously. Throws if read without the override, which surfaces a
/// missing bootstrap step as a loud crash instead of silent re-initialization.
final Provider<AppDatabase> databaseProvider = Provider<AppDatabase>((Ref ref) {
  throw StateError('databaseProvider must be overridden in ProviderScope');
});

/// Overridden in `main.dart` after [SharedPreferences.getInstance] resolves so
/// widgets and controllers can read settings synchronously. Throws if not
/// overridden — same loud-crash contract as [databaseProvider].
final Provider<SharedPreferences> sharedPreferencesProvider =
    Provider<SharedPreferences>((Ref ref) {
  throw StateError(
    'sharedPreferencesProvider must be overridden in ProviderScope',
  );
});

final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>((Ref ref) {
  return SettingsRepository(ref.watch(sharedPreferencesProvider));
});

/// The active record-mode gesture. Initial value loaded from
/// [SettingsRepository]; updates are persisted through the same repo so the
/// choice survives a relaunch.
final StateNotifierProvider<RecordGestureNotifier, RecordGesture>
    recordGestureProvider =
    StateNotifierProvider<RecordGestureNotifier, RecordGesture>((Ref ref) {
  return RecordGestureNotifier(ref.watch(settingsRepositoryProvider));
});

class RecordGestureNotifier extends StateNotifier<RecordGesture> {
  RecordGestureNotifier(this._settings) : super(_settings.recordGesture);

  final SettingsRepository _settings;

  Future<void> set(RecordGesture v) async {
    if (state == v) return;
    state = v;
    await _settings.setRecordGesture(v);
  }
}

/// One-shot first-launch setup. Copies the bundled whisper model out of the
/// asset bundle into the documents directory (~77 MB on first launch, instant
/// thereafter). Watched by the root scaffold so the UI can show a loading
/// state instead of a blank screen during the copy — the surface App Review's
/// automated first-launch test sees.
///
/// The model copy is raced against a 2 s floor so the launch experience
/// always lets the splash (and the app icon on it) breathe for a moment,
/// even on subsequent launches where the copy is a no-op.
final FutureProvider<void> bootstrapProvider = FutureProvider<void>(
  (Ref ref) async {
    await Future.wait<void>(<Future<void>>[
      ensureModelInstalled(),
      Future<void>.delayed(const Duration(seconds: 2)),
    ]);
  },
);

final Provider<NotesDao> notesDaoProvider = Provider<NotesDao>((Ref ref) {
  return NotesDao(ref.watch(databaseProvider));
});

final Provider<NotesRepository> notesRepositoryProvider =
    Provider<NotesRepository>((Ref ref) {
  return NotesRepository(ref.watch(notesDaoProvider));
});

final Provider<AudioRecorder> audioRecorderProvider =
    Provider<AudioRecorder>((Ref ref) {
  final AudioRecorder recorder = AudioRecorder();
  ref.onDispose(recorder.dispose);
  return recorder;
});

final Provider<TranscriptionService> transcriptionServiceProvider =
    Provider<TranscriptionService>((Ref ref) {
  return TranscriptionService();
});

final StateNotifierProvider<CaptureController, CaptureState>
    captureControllerProvider =
    StateNotifierProvider<CaptureController, CaptureState>((Ref ref) {
  return CaptureController(
    recorder: ref.watch(audioRecorderProvider),
    transcriptionService: ref.watch(transcriptionServiceProvider),
    repository: ref.watch(notesRepositoryProvider),
  );
});

final StateNotifierProvider<NotesSearchQuery, String> notesSearchQueryProvider =
    StateNotifierProvider<NotesSearchQuery, String>((Ref ref) {
  return NotesSearchQuery();
});

/// Live stream of active notes (not yet marked complete), filtered by the
/// current search query. Drives the Active tab in the notes list.
final StreamProvider<List<Note>> notesActiveStreamProvider =
    StreamProvider<List<Note>>((Ref ref) {
  final String query = ref.watch(notesSearchQueryProvider);
  return ref.watch(notesRepositoryProvider).watchSearchActive(query);
});

/// Live stream of completed notes, ordered by recency-of-completion and
/// filtered by the current search query. Drives the Completed tab.
final StreamProvider<List<Note>> notesCompletedStreamProvider =
    StreamProvider<List<Note>>((Ref ref) {
  final String query = ref.watch(notesSearchQueryProvider);
  return ref.watch(notesRepositoryProvider).watchSearchCompleted(query);
});

/// Live single-note fetch keyed by id. Emits `null` if the row is deleted
/// while a detail page is open, so the page can dismiss itself.
final StreamProviderFamily<Note?, int> noteByIdProvider =
    StreamProvider.family<Note?, int>((Ref ref, int id) {
  return ref.watch(notesRepositoryProvider).watchById(id);
});

final Provider<JsonExporter> jsonExporterProvider = Provider<JsonExporter>(
  (Ref ref) => JsonExporter(ref.watch(notesRepositoryProvider)),
);

final StateNotifierProvider<ExportController, ExportState>
    exportControllerProvider =
    StateNotifierProvider<ExportController, ExportState>((Ref ref) {
  return ExportController(exporter: ref.watch(jsonExporterProvider));
});
