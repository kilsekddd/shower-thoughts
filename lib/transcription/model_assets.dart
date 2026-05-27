// First-launch helper that copies the bundled whisper.cpp model out of the
// Flutter asset bundle into the app's documents directory, where the native
// FFI side can mmap it by path.
//
// `ensureModelInstalled()` is idempotent — once the file exists on disk it
// short-circuits and just returns the path. Call from `main.dart` during
// startup; the cost on a cold first run is ~77 MB of file I/O.

import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

/// Logical name of the model file as it appears both under `assets/models/` in
/// the Flutter bundle and under `<documents>/` on disk after install.
const String defaultModelFilename = 'ggml-tiny.en.bin';

/// Asset key (as registered in `pubspec.yaml`) for the bundled model.
const String _kBundledModelAssetKey = 'assets/models/$defaultModelFilename';

/// The `model_id` we record on every transcript row so future model upgrades
/// don't lie about provenance. Matches the value documented in
/// ARCHITECTURE.md's data model section.
const String defaultModelId = 'ggml-tiny.en';

/// Ensure the bundled model exists at `<documents>/<defaultModelFilename>` and
/// return that path. Safe to call on every launch — does nothing if the file
/// already exists with a non-zero length.
///
/// [documentsDirOverride] is exposed for tests so they don't have to wire up
/// `path_provider`'s plugin channel.
Future<String> ensureModelInstalled({Directory? documentsDirOverride}) async {
  final docs = documentsDirOverride ?? await getApplicationDocumentsDirectory();
  final dest = File('${docs.path}/$defaultModelFilename');

  if (await dest.exists()) {
    final length = await dest.length();
    if (length > 0) return dest.path;
    // Zero-byte file means a previous install was interrupted — fall through
    // and rewrite it.
  }

  await docs.create(recursive: true);
  final data = await rootBundle.load(_kBundledModelAssetKey);
  // Cast to Uint8List without copying the underlying byte data.
  final bytes = data.buffer.asUint8List(
    data.offsetInBytes,
    data.lengthInBytes,
  );
  await dest.writeAsBytes(bytes, flush: true);
  return dest.path;
}
