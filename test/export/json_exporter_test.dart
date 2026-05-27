import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shower_thoughts/data/database.dart';
import 'package:shower_thoughts/data/notes_dao.dart';
import 'package:shower_thoughts/data/notes_repository.dart';
import 'package:shower_thoughts/export/json_exporter.dart';

void main() {
  late Directory tmp;
  late AppDatabase db;
  late NotesRepository repository;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('exporter_test_');
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = NotesRepository(NotesDao(db));
  });

  tearDown(() async {
    await db.close();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<int> insert({
    required DateTime createdAt,
    required int durationMs,
    required String transcript,
  }) {
    return repository.commitTranscript(
      NoteDraft(
        createdAt: createdAt,
        durationMs: durationMs,
        transcript: transcript,
        modelId: 'ggml-tiny.en',
      ),
      '${tmp.path}/no-such-audio.wav', // missing audio is a no-op delete
    );
  }

  test('round-trip: every row appears and schema field is set', () async {
    final DateTime a = DateTime.utc(2026, 5, 27, 12, 0, 0);
    final DateTime b = DateTime.utc(2026, 5, 27, 12, 5, 0);
    final DateTime c = DateTime.utc(2026, 5, 27, 12, 10, 0);

    final int idA = await insert(createdAt: a, durationMs: 1000, transcript: 'first');
    final int idB = await insert(createdAt: b, durationMs: 1500, transcript: 'second');
    final int idC = await insert(createdAt: c, durationMs: 2200, transcript: 'third');

    final JsonExporter exporter = JsonExporter.forTesting(
      repository,
      documentsDir: tmp,
      now: () => DateTime.utc(2026, 5, 27, 13, 0, 0),
    );

    final String path = await exporter.exportAll();
    expect(File(path).existsSync(), isTrue,
        reason: 'exporter must write the file to the supplied docs dir');
    expect(path.startsWith(tmp.path), isTrue);

    final dynamic decoded = jsonDecode(await File(path).readAsString());
    expect(decoded, isA<Map<String, dynamic>>());
    final Map<String, dynamic> body = decoded as Map<String, dynamic>;

    expect(body['schema'], 'shower-thoughts.export.v1');
    expect(body['exported_at'], isA<String>());
    expect((body['exported_at'] as String).endsWith('Z'), isTrue,
        reason: 'exported_at must be UTC ISO 8601');

    final List<dynamic> notes = body['notes'] as List<dynamic>;
    expect(notes.length, 3, reason: 'every row must appear in the export');

    final Set<int> ids =
        notes.map((dynamic n) => (n as Map<String, dynamic>)['id'] as int).toSet();
    expect(ids, <int>{idA, idB, idC});

    final Map<String, dynamic> first = notes.firstWhere(
      (dynamic n) => (n as Map<String, dynamic>)['id'] == idA,
    ) as Map<String, dynamic>;
    expect(first['transcript'], 'first');
    expect(first['duration_ms'], 1000);
    expect(first['model_id'], 'ggml-tiny.en');
    expect(first['created_at'], '2026-05-27T12:00:00.000Z');
  });

  test('exports an empty notes array when the DB has no rows', () async {
    final JsonExporter exporter = JsonExporter.forTesting(
      repository,
      documentsDir: tmp,
      now: () => DateTime.utc(2026, 5, 27, 13, 0, 0),
    );
    final String path = await exporter.exportAll();
    final Map<String, dynamic> body =
        jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
    expect(body['schema'], 'shower-thoughts.export.v1');
    expect(body['notes'], <Object?>[]);
  });
}
