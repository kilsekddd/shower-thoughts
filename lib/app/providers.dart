import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/audio_recorder.dart';
import '../data/database.dart';
import '../data/notes_dao.dart';
import '../data/notes_repository.dart';
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

/// One-shot first-launch setup. Currently just copies the bundled whisper
/// model out of the asset bundle into the documents directory (~77 MB, so it
/// matters on first launch; instant thereafter). Watched by the root scaffold
/// so the UI can show a loading state instead of a blank screen during the
/// copy — the surface App Review's automated first-launch test sees.
final FutureProvider<void> bootstrapProvider = FutureProvider<void>(
  (Ref ref) async {
    await ensureModelInstalled();
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

final StreamProvider<List<Note>> notesStreamProvider =
    StreamProvider<List<Note>>((Ref ref) {
  final String query = ref.watch(notesSearchQueryProvider);
  return ref.watch(notesRepositoryProvider).watchSearchByText(query);
});

final FutureProviderFamily<Note?, int> noteByIdProvider =
    FutureProvider.family<Note?, int>((Ref ref, int id) {
  return ref.watch(notesRepositoryProvider).getById(id);
});

final Provider<JsonExporter> jsonExporterProvider = Provider<JsonExporter>(
  (Ref ref) => JsonExporter(ref.watch(notesRepositoryProvider)),
);

final StateNotifierProvider<ExportController, ExportState>
    exportControllerProvider =
    StateNotifierProvider<ExportController, ExportState>((Ref ref) {
  return ExportController(exporter: ref.watch(jsonExporterProvider));
});
