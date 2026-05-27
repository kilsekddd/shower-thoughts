import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

part 'database.g.dart';

/// Logical `notes` row. One transcript = one row.
///
/// Columns intentionally mirror ARCHITECTURE.md verbatim. No tags, titles,
/// folders, or categories — search is the only retrieval mechanism (see
/// CLAUDE.md "Avoid" list).
@DataClassName('Note')
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Unix epoch milliseconds, UTC. Drives default sort and timestamp display.
  IntColumn get createdAt => integer().named('created_at')();

  /// Length of the original recording, in milliseconds.
  IntColumn get durationMs => integer().named('duration_ms')();

  /// The transcribed text (single paragraph; whisper line breaks collapsed).
  TextColumn get transcript => text()();

  /// Which whisper model produced this transcript (e.g. `ggml-tiny.en`).
  TextColumn get modelId => text().named('model_id')();
}

/// Lightweight, FFI-free draft used by the app layer to construct a new note
/// before it is persisted. Kept here so `NotesRepository` can stay decoupled
/// from Drift's generated companions.
class NoteDraft {
  const NoteDraft({
    required this.createdAt,
    required this.durationMs,
    required this.transcript,
    required this.modelId,
  });

  final DateTime createdAt;
  final int durationMs;
  final String transcript;
  final String modelId;
}

@DriftDatabase(tables: <Type>[Notes])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructor for tests; pass a `NativeDatabase.memory()` executor.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          // FTS5 virtual table mirrors `notes.transcript`. We use
          // content-linked mode (`content='notes', content_rowid='id'`) so
          // FTS5 stores only the index, not a duplicate of the text; the
          // triggers below keep it in sync.
          await customStatement('''
            CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(
              transcript,
              content='notes',
              content_rowid='id',
              tokenize='unicode61'
            )
          ''');
          await customStatement('''
            CREATE TRIGGER IF NOT EXISTS notes_ai AFTER INSERT ON notes BEGIN
              INSERT INTO notes_fts(rowid, transcript)
              VALUES (new.id, new.transcript);
            END
          ''');
          await customStatement('''
            CREATE TRIGGER IF NOT EXISTS notes_ad AFTER DELETE ON notes BEGIN
              INSERT INTO notes_fts(notes_fts, rowid, transcript)
              VALUES ('delete', old.id, old.transcript);
            END
          ''');
          await customStatement('''
            CREATE TRIGGER IF NOT EXISTS notes_au AFTER UPDATE OF transcript ON notes BEGIN
              INSERT INTO notes_fts(notes_fts, rowid, transcript)
              VALUES ('delete', old.id, old.transcript);
              INSERT INTO notes_fts(rowid, transcript)
              VALUES (new.id, new.transcript);
            END
          ''');
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // On iOS, ship SQLite via `sqlite3_flutter_libs` so we get FTS5 enabled.
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    final Directory dir = await getApplicationDocumentsDirectory();
    final File file = File('${dir.path}${Platform.pathSeparator}shower_thoughts.db');
    return NativeDatabase.createInBackground(file);
  });
}
