import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/audio_recorder.dart';
import '../data/database.dart';
import '../data/notes_dao.dart';
import '../data/notes_repository.dart';
import '../transcription/transcription_service.dart';
import 'capture_controller.dart';

/// Overridden in `main.dart` after the database is opened so widgets can read
/// it synchronously. Throws if read without the override, which surfaces a
/// missing bootstrap step as a loud crash instead of silent re-initialization.
final Provider<AppDatabase> databaseProvider = Provider<AppDatabase>((Ref ref) {
  throw StateError('databaseProvider must be overridden in ProviderScope');
});

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
