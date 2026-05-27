// ignore_for_file: prefer_initializing_formals
//
// Public named-arg API with private fields — same rationale as the other
// controllers.

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../data/database.dart';
import '../data/notes_repository.dart';

/// The schema tag baked into every export. Per CLAUDE.md, this value is a
/// contract: external consumers key off it, so bump the version if the shape
/// ever changes.
const String exportSchemaV1 = 'shower-thoughts.export.v1';

/// Serializes every note in the database into the v1 export JSON shape and
/// writes it to a file in the app's documents directory. Returns the file path
/// so the controller can hand it to the iOS share sheet.
class JsonExporter {
  JsonExporter(this._repository, {Directory? documentsDirOverride})
      : _documentsDirOverride = documentsDirOverride,
        _now = DateTime.now;

  /// Test seam: inject the docs dir + clock without faking path_provider.
  JsonExporter.forTesting(
    this._repository, {
    required Directory documentsDir,
    DateTime Function() now = DateTime.now,
  })  : _documentsDirOverride = documentsDir,
        _now = now;

  final NotesRepository _repository;
  final Directory? _documentsDirOverride;
  final DateTime Function() _now;

  /// Writes the export JSON to `<documents>/shower-thoughts-export-<ts>.json`
  /// and returns the path. Overwrites any existing file at the same path.
  Future<String> exportAll() async {
    final List<Note> all = await _repository.listAllNewestFirst();
    final Map<String, Object?> body = buildJsonObject(all, exportedAt: _now());

    final Directory docs =
        _documentsDirOverride ?? await getApplicationDocumentsDirectory();
    await docs.create(recursive: true);
    final String path =
        '${docs.path}${Platform.pathSeparator}${_filename(_now())}';
    final File file = File(path);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(body),
      flush: true,
    );
    return path;
  }

  /// Pure transformation: rows in → v1-shaped JSON map. Pulled out so tests
  /// can assert on the shape without going through the filesystem.
  static Map<String, Object?> buildJsonObject(
    List<Note> notes, {
    required DateTime exportedAt,
  }) {
    return <String, Object?>{
      'schema': exportSchemaV1,
      'exported_at': exportedAt.toUtc().toIso8601String(),
      'notes': notes
          .map((Note n) => <String, Object?>{
                'id': n.id,
                'created_at':
                    DateTime.fromMillisecondsSinceEpoch(n.createdAt, isUtc: true)
                        .toIso8601String(),
                'duration_ms': n.durationMs,
                'transcript': n.transcript,
                'model_id': n.modelId,
              })
          .toList(growable: false),
    };
  }

  String _filename(DateTime when) {
    // Compact timestamp suffix so multiple exports don't clobber each other in
    // the user's Files app.
    final String ts = when.toUtc().toIso8601String().replaceAll(':', '-');
    return 'shower-thoughts-export-$ts.json';
  }
}
