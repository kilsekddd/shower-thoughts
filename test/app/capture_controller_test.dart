import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shower_thoughts/app/capture_controller.dart';
import 'package:shower_thoughts/audio/audio_recorder.dart';
import 'package:shower_thoughts/data/database.dart';
import 'package:shower_thoughts/data/notes_dao.dart';
import 'package:shower_thoughts/data/notes_repository.dart';
import 'package:shower_thoughts/transcription/transcription_service.dart';

/// Fake recorder: returns a path to a real file we control on disk so the
/// repository's `commitTranscript` can actually delete it and the test can
/// assert on its presence/absence.
class _FakeRecorder implements AudioRecorder {
  _FakeRecorder(this.path);
  final String path;

  @override
  Future<String> start() async {
    // Create the scratch file each time `start` is called so a retry against
    // the still-on-disk audio is meaningful.
    await File(path).writeAsBytes(<int>[0, 1, 2, 3]);
    return path;
  }

  @override
  Future<String> stop() async => path;

  @override
  Future<bool> isRecording() async => false;

  @override
  Future<void> dispose() async {}
}

/// Fake transcription service: returns a queued list of outcomes. Each call
/// pops the head; a `String` resolves, an `Object` (non-string) throws.
class _FakeTranscription implements TranscriptionService {
  _FakeTranscription(this.outcomes);
  final List<Object> outcomes;
  final List<String> calls = <String>[];

  @override
  Future<String> transcribe(String audioPath) async {
    calls.add(audioPath);
    final Object outcome = outcomes.removeAt(0);
    if (outcome is String) return outcome;
    throw outcome;
  }
}

void main() {
  late Directory tmp;
  late String audioPath;
  late AppDatabase db;
  late NotesRepository repository;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('cap_ctrl_test_');
    audioPath = '${tmp.path}/capture.wav';
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = NotesRepository(NotesDao(db));
  });

  tearDown(() async {
    await db.close();
    if (await tmp.exists()) {
      await tmp.delete(recursive: true);
    }
  });

  test('happy path: idle → recording → transcribing → committed; audio deleted',
      () async {
    final _FakeRecorder recorder = _FakeRecorder(audioPath);
    final _FakeTranscription transcription =
        _FakeTranscription(<Object>['hello world']);
    final CaptureController controller = CaptureController(
      recorder: recorder,
      transcriptionService: transcription,
      repository: repository,
    );

    expect(controller.state, isA<CaptureIdle>());

    await controller.startRecording();
    expect(controller.state, isA<CaptureRecording>());
    expect(File(audioPath).existsSync(), isTrue);

    await controller.stopRecording();
    expect(controller.state, isA<CaptureCommitted>());

    final CaptureCommitted committed = controller.state as CaptureCommitted;
    final note = await repository.getById(committed.noteId);
    expect(note, isNotNull);
    expect(note!.transcript, 'hello world');

    // Audio scratch must be gone — the named PRD risk is audio retention.
    expect(File(audioPath).existsSync(), isFalse);
  });

  test('transcription failure keeps audio and exposes a retryable failed state',
      () async {
    final _FakeRecorder recorder = _FakeRecorder(audioPath);
    final _FakeTranscription transcription = _FakeTranscription(
      <Object>[Exception('whisper exploded')],
    );
    final CaptureController controller = CaptureController(
      recorder: recorder,
      transcriptionService: transcription,
      repository: repository,
    );

    await controller.startRecording();
    await controller.stopRecording();

    expect(controller.state, isA<CaptureFailed>());
    final CaptureFailed failed = controller.state as CaptureFailed;
    expect(failed.canRetry, isTrue);
    expect(failed.audioPath, audioPath);

    // Crucially: the audio file is still on disk so the user can retry.
    expect(File(audioPath).existsSync(), isTrue);

    // No row was committed.
    final List<dynamic> all = await repository.listAllNewestFirst();
    expect(all, isEmpty);
  });

  test('successful retry against the still-on-disk audio commits and deletes',
      () async {
    final _FakeRecorder recorder = _FakeRecorder(audioPath);
    final _FakeTranscription transcription = _FakeTranscription(
      <Object>[Exception('first try'), 'second try wins'],
    );
    final CaptureController controller = CaptureController(
      recorder: recorder,
      transcriptionService: transcription,
      repository: repository,
    );

    await controller.startRecording();
    await controller.stopRecording();
    expect(controller.state, isA<CaptureFailed>());
    expect(File(audioPath).existsSync(), isTrue);

    await controller.retry();
    expect(controller.state, isA<CaptureCommitted>());

    // Both transcribe calls used the same audio path.
    expect(transcription.calls, <String>[audioPath, audioPath]);

    final CaptureCommitted committed = controller.state as CaptureCommitted;
    final note = await repository.getById(committed.noteId);
    expect(note!.transcript, 'second try wins');

    // Audio gone after successful commit.
    expect(File(audioPath).existsSync(), isFalse);
  });
}
