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

  /// All notes, newest first. Drives the default list view.
  Future<List<Note>> listAllNewestFirst() {
    return _allNewestFirst().get();
  }

  /// Live-updating version of [listAllNewestFirst] — Drift re-emits the list
  /// whenever the `notes` table changes (which the FTS triggers fan out from).
  Stream<List<Note>> watchAllNewestFirst() {
    return _allNewestFirst().watch();
  }

  SimpleSelectStatement<$NotesTable, Note> _allNewestFirst() {
    return select(notes)
      ..orderBy(<OrderClauseGenerator<$NotesTable>>[
        ($NotesTable t) =>
            OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]);
  }

  /// Fetch a single note by primary key, or `null` if it does not exist.
  Future<Note?> getById(int id) {
    return (select(notes)..where(($NotesTable t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Delete a row by primary key; returns the number of rows removed.
  Future<int> deleteById(int id) {
    return (delete(notes)..where(($NotesTable t) => t.id.equals(id))).go();
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

  /// Live-updating variant of [searchByText]. Empty / whitespace queries fall
  /// back to the full newest-first stream.
  Stream<List<Note>> watchSearchByText(String query) {
    final String? matchExpression = _matchExpressionOrNull(query);
    if (matchExpression == null) return watchAllNewestFirst();
    return _searchQuery(matchExpression).watch();
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
