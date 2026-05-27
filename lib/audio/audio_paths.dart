import 'dart:io';

import 'package:path_provider/path_provider.dart';

class AudioPaths {
  AudioPaths._();

  static const String _fileName = 'capture.wav';

  /// Deterministic scratch path under the app's temp directory.
  /// A new capture overwrites the previous file at this exact path, and the
  /// repository deletes it on successful transcript commit — so no orphans
  /// can accumulate.
  static Future<String> scratchWavPath() async {
    final Directory tmp = await getTemporaryDirectory();
    return '${tmp.path}${Platform.pathSeparator}$_fileName';
  }
}
