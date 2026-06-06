import 'dart:io';

import 'database.dart';
import 'notes_dao.dart';

/// The single contract layer between the app/transcription side and the
/// database. The capture pipeline only talks to this class — never to the
/// DAO or to Drift directly.
///
/// `commitTranscript` is the only path that ever deletes the audio scratch
/// file. Per CLAUDE.md, the delete lives in a `finally` block so a partial
/// failure still removes the audio (audio retention is a named PRD risk).
class NotesRepository {
  NotesRepository(this._dao);

  final NotesDao _dao;

  /// Insert a transcript row and delete the audio scratch file in the same
  /// async operation.
  ///
  /// - The row is inserted first; the insert's result is returned to the
  ///   caller.
  /// - The audio file at `audioPath` is then removed inside a `finally`
  ///   block so a partial failure in the insert path still wipes the audio.
  /// - If the file does not exist at delete time, that is **not** an error
  ///   — it just means an earlier attempt already cleaned it up.
  ///
  /// Returns the freshly-assigned note `id`.
  Future<int> commitTranscript(NoteDraft note, String audioPath) async {
    try {
      return await _dao.insertNote(
        NotesCompanion.insert(
          createdAt: note.createdAt.toUtc().millisecondsSinceEpoch,
          durationMs: note.durationMs,
          transcript: note.transcript,
          modelId: note.modelId,
        ),
      );
    } finally {
      await _safeDeleteAudio(audioPath);
    }
  }

  /// All notes, newest first.
  Future<List<Note>> listAllNewestFirst() => _dao.listAllNewestFirst();

  /// Live-updating stream of all notes, newest first. Emits a new list any
  /// time a note is inserted, updated, or deleted.
  Stream<List<Note>> watchAllNewestFirst() => _dao.watchAllNewestFirst();

  /// Live stream of active notes (not yet marked complete), newest first.
  Stream<List<Note>> watchActiveNewestFirst() => _dao.watchActiveNewestFirst();

  /// Live stream of completed notes, most-recently-completed first.
  Stream<List<Note>> watchCompletedNewestFirst() =>
      _dao.watchCompletedNewestFirst();

  /// Full-text search; empty queries fall back to the newest-first list.
  Future<List<Note>> searchByText(String query) => _dao.searchByText(query);

  /// Live-updating FTS search stream; empty queries fall back to the
  /// newest-first stream.
  Stream<List<Note>> watchSearchByText(String query) =>
      _dao.watchSearchByText(query);

  /// Live FTS search restricted to active notes.
  Stream<List<Note>> watchSearchActive(String query) =>
      _dao.watchSearchActive(query);

  /// Live FTS search restricted to completed notes.
  Stream<List<Note>> watchSearchCompleted(String query) =>
      _dao.watchSearchCompleted(query);

  /// Fetch a single note by primary key, or `null` if missing.
  Future<Note?> getById(int id) => _dao.getById(id);

  /// Live-updating fetch of a single note. Emits `null` if the row is deleted
  /// while a detail page is open.
  Stream<Note?> watchById(int id) => _dao.watchById(id);

  /// Mark a note complete. `at` defaults to `DateTime.now().toUtc()` so most
  /// callers don't need to supply it; injected timestamps make tests
  /// deterministic.
  Future<void> markCompleted(int id, {DateTime? at}) async {
    await _dao.setCompleted(id, at ?? DateTime.now().toUtc());
  }

  /// Reopen a previously completed note (clear `completed_at`).
  Future<void> markActive(int id) async {
    await _dao.setCompleted(id, null);
  }

  /// Replace a note's transcript text. The FTS index updates in lockstep via
  /// the schema's update trigger, so search stays in sync without extra work.
  Future<void> updateTranscript(int id, String transcript) async {
    await _dao.updateTranscript(id, transcript);
  }

  /// Hard delete: the row is gone, the FTS entry is gone, and there is no
  /// trash or undo. Mirrors the product decision to not soft-delete.
  Future<int> deleteById(int id) => _dao.deleteById(id);

  /// Best-effort delete of the audio scratch file. A missing file is fine;
  /// a permission error or similar is swallowed so the contract holds even
  /// in degraded environments. The caller doesn't get to choose.
  Future<void> _safeDeleteAudio(String audioPath) async {
    final File file = File(audioPath);
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      // Swallow: the audio scratch is transient; if the OS won't let us
      // delete it (locked, permissions), there is nothing useful to do
      // here and we must not block the transcript commit.
    }
  }
}
