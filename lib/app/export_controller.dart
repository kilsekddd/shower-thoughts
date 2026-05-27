// ignore_for_file: prefer_initializing_formals
//
// Same rationale as in capture_controller.dart: public named args + private
// fields beats forcing `_exporter:` at every call site.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../export/json_exporter.dart';

/// State of the one-shot "export to JSON" action surfaced on the Export page.
sealed class ExportState {
  const ExportState();
}

final class ExportIdle extends ExportState {
  const ExportIdle();
}

final class ExportRunning extends ExportState {
  const ExportRunning();
}

final class ExportDone extends ExportState {
  const ExportDone({required this.filePath});
  final String filePath;
}

final class ExportFailed extends ExportState {
  const ExportFailed({required this.error});
  final Object error;
}

/// Where the share sheet anchors. On iPad iOS demands a popover anchor; on
/// iPhone iOS 26+ also rejects `Rect.zero`, so the page must hand the
/// controller a real rect (typically the share button's bounds in screen
/// coordinates).
typedef ShareCallback = Future<void> Function(
  String filePath, {
  Rect? sharePositionOrigin,
});

class ExportController extends StateNotifier<ExportState> {
  ExportController({
    required JsonExporter exporter,
    ShareCallback? share,
  })  : _exporter = exporter,
        _share = share ?? _defaultShare,
        super(const ExportIdle());

  final JsonExporter _exporter;
  final ShareCallback _share;

  /// Run the exporter and hand the resulting file to the iOS share sheet.
  /// [sharePositionOrigin] is the rect (in screen coordinates) the share
  /// sheet should anchor on — required by iOS on iPad and iOS 26+ iPhone.
  Future<void> exportAndShare({Rect? sharePositionOrigin}) async {
    if (state is ExportRunning) return;
    state = const ExportRunning();
    try {
      final String path = await _exporter.exportAll();
      await _share(path, sharePositionOrigin: sharePositionOrigin);
      state = ExportDone(filePath: path);
    } catch (e) {
      state = ExportFailed(error: e);
    }
  }

  void dismiss() {
    if (state is ExportDone || state is ExportFailed) {
      state = const ExportIdle();
    }
  }
}

Future<void> _defaultShare(
  String filePath, {
  Rect? sharePositionOrigin,
}) async {
  await Share.shareXFiles(
    <XFile>[XFile(filePath, mimeType: 'application/json')],
    subject: 'shower-thoughts export',
    sharePositionOrigin: sharePositionOrigin,
  );
}
