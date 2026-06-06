import 'package:drift/drift.dart';

import 'database.dart';

part 'notes_dao.g.dart';

/// Typed queries against the `notes` table and the `notes_fts` virtual table.
///
/// The DAO is intentionally thin — `NotesRepository` is the layer that owns
/// the audio-delete-on-commit contract; this class only knows about rows.
@DriftAccessor(tables: <Type>[Notes])
class NotesDao extends DatabaseAccessor<AppDatabase> with _$NotesDaoMixin {
  NotesDao(super.db);

  /// Inserts a row and returns the freshly-assigned `id`.
  Future<int> insertNote(NotesCompanion entry) {
    return into(notes).insert(entry);
  }

  /// All notes, newest first. Drives the JSON export.
  Future<List<Note>> listAllNewestFirst() {
    return (select(notes)
          ..orderBy(<OrderClauseGenerator<$NotesTable>>[
            ($NotesTable t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .get();
  }

  /// Live stream of active notes (`completed_at IS NULL`), newest-created first.
  Stream<List<Note>> watchActiveNewestFirst() {
    return (select(notes)
          ..where(($NotesTable t) => t.completedAt.isNull())
          ..orderBy(<OrderClauseGenerator<$NotesTable>>[
            ($NotesTable t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// Live stream of completed notes, ordered by recency of completion.
  Stream<List<Note>> watchCompletedNewestFirst() {
    return (select(notes)
          ..where(($NotesTable t) => t.completedAt.isNotNull())
          ..orderBy(<OrderClauseGenerator<$NotesTable>>[
            ($NotesTable t) => OrderingTerm(
                expression: t.completedAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// Fetch a single note by primary key, or `null` if it does not exist.
  Future<Note?> getById(int id) {
    return (select(notes)..where(($NotesTable t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Live-updating fetch of a single note by primary key. Emits `null` when
  /// the row is missing (e.g. it was just deleted), so detail pages can react.
  Stream<Note?> watchById(int id) {
    return (select(notes)..where(($NotesTable t) => t.id.equals(id)))
        .watchSingleOrNull();
  }

  /// Delete a row by primary key; returns the number of rows removed.
  Future<int> deleteById(int id) {
    return (delete(notes)..where(($NotesTable t) => t.id.equals(id))).go();
  }

  /// Set the `completed_at` column. Pass `null` to reopen a completed note.
  /// Returns the number of rows updated.
  Future<int> setCompleted(int id, DateTime? at) {
    return (update(notes)..where(($NotesTable t) => t.id.equals(id))).write(
      NotesCompanion(
        completedAt: Value<int?>(at?.toUtc().millisecondsSinceEpoch),
      ),
    );
  }

  /// Replace the transcript text for a single row. The FTS5 update trigger
  /// keeps `notes_fts` in sync. Returns the number of rows updated.
  Future<int> updateTranscript(int id, String transcript) {
    return (update(notes)..where(($NotesTable t) => t.id.equals(id))).write(
      NotesCompanion(transcript: Value<String>(transcript)),
    );
  }

  /// Full-text search via the `notes_fts` virtual table.
  ///
  /// The `query` is treated as a prefix-match expression so a substring
  /// fragment like `"sho"` matches `"shower"`. Results are joined back to
  /// `notes` and returned newest-first; we pick recency over BM25 so that
  /// the list view's sort stays predictable when a search is active.
  Future<List<Note>> searchByText(String query) {
    final String? matchExpression = _matchExpressionOrNull(query);
    if (matchExpression == null) return listAllNewestFirst();
    return _searchQuery(matchExpression).get();
  }

  /// Live FTS search restricted to active notes. Empty query falls back to
  /// [watchActiveNewestFirst].
  Stream<List<Note>> watchSearchActive(String query) {
    final String? matchExpression = _matchExpressionOrNull(query);
    if (matchExpression == null) return watchActiveNewestFirst();
    return _filteredSearchQuery(
      matchExpression,
      completionClause: 'notes.completed_at IS NULL',
      orderClause: 'notes.created_at DESC',
    ).watch();
  }

  /// Live FTS search restricted to completed notes, ordered by
  /// completed_at DESC. Empty query falls back to [watchCompletedNewestFirst].
  Stream<List<Note>> watchSearchCompleted(String query) {
    final String? matchExpression = _matchExpressionOrNull(query);
    if (matchExpression == null) return watchCompletedNewestFirst();
    return _filteredSearchQuery(
      matchExpression,
      completionClause: 'notes.completed_at IS NOT NULL',
      orderClause: 'notes.completed_at DESC',
    ).watch();
  }

  Selectable<Note> _searchQuery(String matchExpression) {
    return customSelect(
      'SELECT notes.* FROM notes '
      'JOIN notes_fts ON notes_fts.rowid = notes.id '
      'WHERE notes_fts MATCH ? '
      'ORDER BY notes.created_at DESC',
      variables: <Variable<Object>>[Variable<String>(matchExpression)],
      readsFrom: <ResultSetImplementation<Table, Object?>>{notes},
    ).asyncMap((QueryRow row) => notes.mapFromRow(row));
  }

  Selectable<Note> _filteredSearchQuery(
    String matchExpression, {
    required String completionClause,
    required String orderClause,
  }) {
    return customSelect(
      'SELECT notes.* FROM notes '
      'JOIN notes_fts ON notes_fts.rowid = notes.id '
      'WHERE notes_fts MATCH ? AND $completionClause '
      'ORDER BY $orderClause',
      variables: <Variable<Object>>[Variable<String>(matchExpression)],
      readsFrom: <ResultSetImplementation<Table, Object?>>{notes},
    ).asyncMap((QueryRow row) => notes.mapFromRow(row));
  }

  String? _matchExpressionOrNull(String query) {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) return null;
    final String expr = _toPrefixMatch(trimmed);
    return expr.isEmpty ? null : expr;
  }

  /// Convert a raw user query into an FTS5 prefix-match expression.
  ///
  /// We split on whitespace and append `*` to each token so partial words
  /// match (`"sho"` finds `"shower"`). Quotes / parens / `MATCH` operators
  /// the user might accidentally type are stripped so they cannot break the
  /// expression parser.
  String _toPrefixMatch(String raw) {
    final Iterable<String> tokens = raw
        .split(RegExp(r'\s+'))
        .map((String t) => t.replaceAll(RegExp(r'[^\w]'), ''))
        .where((String t) => t.isNotEmpty);
    return tokens.map((String t) => '$t*').join(' ');
  }
}
