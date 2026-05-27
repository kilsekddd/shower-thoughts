import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/export_controller.dart';
import '../../app/providers.dart';

class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key});

  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  final GlobalKey _buttonKey = GlobalKey();

  Rect? _buttonRect() {
    final BuildContext? ctx = _buttonKey.currentContext;
    if (ctx == null) return null;
    final RenderObject? ro = ctx.findRenderObject();
    if (ro is! RenderBox || !ro.attached) return null;
    final Offset topLeft = ro.localToGlobal(Offset.zero);
    return topLeft & ro.size;
  }

  @override
  Widget build(BuildContext context) {
    final ExportState state = ref.watch(exportControllerProvider);
    final ExportController controller =
        ref.read(exportControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FilledButton.icon(
              key: _buttonKey,
              onPressed: state is ExportRunning
                  ? null
                  : () => controller.exportAndShare(
                      sharePositionOrigin: _buttonRect()),
              icon: const Icon(Icons.ios_share),
              label: const Text('Export all notes as JSON'),
            ),
            const SizedBox(height: 16),
            _Status(state: state, controller: controller),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: 'Shower Thoughts',
                applicationLegalese:
                    'Voice notes transcribed on-device. No cloud, no account.',
              ),
              icon: const Icon(Icons.info_outline, size: 18),
              label: const Text('Open source licenses'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.state, required this.controller});

  final ExportState state;
  final ExportController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return switch (state) {
      ExportIdle() => Text(
          'Writes a JSON file and opens the iOS share sheet so you can save '
          'or send it.',
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ExportRunning() => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text('Exporting…', style: theme.textTheme.bodyMedium),
          ],
        ),
      ExportDone() => Column(
          children: <Widget>[
            Text(
              'Export complete.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
            TextButton(
              onPressed: controller.dismiss,
              child: const Text('OK'),
            ),
          ],
        ),
      ExportFailed(:final Object error) => Column(
          children: <Widget>[
            Text(
              'Export failed: $error',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
            TextButton(
              onPressed: controller.dismiss,
              child: const Text('Dismiss'),
            ),
          ],
        ),
    };
  }
}
