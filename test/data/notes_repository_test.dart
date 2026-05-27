import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shower_thoughts/data/database.dart';
import 'package:shower_thoughts/data/notes_dao.dart';
import 'package:shower_thoughts/data/notes_repository.dart';

void main() {
  late AppDatabase db;
  late NotesRepository repo;
  late Directory tmpDir;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = NotesRepository(NotesDao(db));
    tmpDir = await Directory.systemTemp.createTemp('shower_thoughts_test_');
  });

  tearDown(() async {
    await db.close();
    if (tmpDir.existsSync()) {
      await tmpDir.delete(recursive: true);
    }
  });

  group('commitTranscript', () {
    test('inserts the row and deletes the audio file on success', () async {
      final File audio = File('${tmpDir.path}/scratch.wav')
        ..writeAsBytesSync(<int>[0, 1, 2, 3]);
      expect(audio.existsSync(), isTrue);

      final int id = await repo.commitTranscript(
        NoteDraft(
          createdAt: DateTime.utc(2026, 1, 1, 12),
          durationMs: 4200,
          transcript: 'hello world',
          modelId: 'ggml-tiny.en',
        ),
        audio.path,
      );

      expect(id, greaterThan(0));
      final Note? row = await repo.getById(id);
      expect(row, isNotNull);
      expect(row!.transcript, 'hello world');
      expect(row.durationMs, 4200);
      expect(row.modelId, 'ggml-tiny.en');
      expect(audio.existsSync(), isFalse,
          reason: 'audio scratch must be deleted after a successful commit');
    });

    test('commit succeeds when the audio file does not exist', () async {
      final String ghostPath = '${tmpDir.path}/never_was.wav';
      expect(File(ghostPath).existsSync(), isFalse);

      final int id = await repo.commitTranscript(
        NoteDraft(
          createdAt: DateTime.utc(2026, 2, 2, 9),
          durationMs: 1000,
          transcript: 'note without audio',
          modelId: 'ggml-tiny.en',
        ),
        ghostPath,
      );

      final Note? row = await repo.getById(id);
      expect(row, isNotNull);
      expect(row!.transcript, 'note without audio');
      expect(File(ghostPath).existsSync(), isFalse);
    });
  });

  group('searchByText', () {
    test('matches a full token', () async {
      await _insert(repo, 'apples are red', tmpDir);
      await _insert(repo, 'bananas are yellow', tmpDir);
      await _insert(repo, 'cherries are also red', tmpDir);

      final List<Note> results = await repo.searchByText('red');
      expect(results.length, 2);
      expect(
        results.map((Note n) => n.transcript),
        containsAll(<String>['apples are red', 'cherries are also red']),
      );
    });

    test('matches a substring fragment via FTS prefix match', () async {
      await _insert(repo, 'thinking about the shower', tmpDir);
      await _insert(repo, 'unrelated text here', tmpDir);

      final List<Note> results = await repo.searchByText('sho');
      expect(results.length, 1);
      expect(results.single.transcript, 'thinking about the shower');
    });
  });

  group('listAllNewestFirst', () {
    test('orders by created_at descending', () async {
      await _insert(repo, 'oldest', tmpDir,
          createdAt: DateTime.utc(2026, 1, 1));
      await _insert(repo, 'middle', tmpDir,
          createdAt: DateTime.utc(2026, 3, 1));
      await _insert(repo, 'newest', tmpDir,
          createdAt: DateTime.utc(2026, 5, 1));

      final List<Note> rows = await repo.listAllNewestFirst();
      expect(
        rows.map((Note n) => n.transcript).toList(),
        <String>['newest', 'middle', 'oldest'],
      );
    });
  });
}

/// Helper: build a scratch audio file, commit a transcript, and return.
/// Mirrors how the capture pipeline will call the repository.
Future<int> _insert(
  NotesRepository repo,
  String transcript,
  Directory tmpDir, {
  DateTime? createdAt,
}) async {
  final File audio = File(
    '${tmpDir.path}/clip_${DateTime.now().microsecondsSinceEpoch}.wav',
  )..writeAsBytesSync(<int>[0]);
  return repo.commitTranscript(
    NoteDraft(
      createdAt: createdAt ?? DateTime.now().toUtc(),
      durationMs: 1000,
      transcript: transcript,
      modelId: 'ggml-tiny.en',
    ),
    audio.path,
  );
}
