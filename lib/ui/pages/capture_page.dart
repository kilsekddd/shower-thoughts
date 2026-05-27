import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/capture_controller.dart';
import '../../app/providers.dart';
import '../widgets/push_to_talk_button.dart';

class CapturePage extends ConsumerWidget {
  const CapturePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CaptureState state = ref.watch(captureControllerProvider);
    final CaptureController controller =
        ref.read(captureControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Center(
              child: PushToTalkButton(
                enabled: state is CaptureIdle ||
                    state is CaptureCommitted ||
                    state is CaptureFailed,
                onStart: controller.startRecording,
                onStop: controller.stopRecording,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _StatusPanel(state: state, controller: controller),
        ],
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.state, required this.controller});

  final CaptureState state;
  final CaptureController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return switch (state) {
      CaptureIdle() => Text(
          'Tap and hold the button to record a note.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      CaptureRecording() => Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Recording — release to transcribe.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // Tap-up sometimes never fires (e.g. when iOS pops the mic
            // permission modal mid-press and steals the gesture). The Stop
            // button is the always-reachable escape hatch back to idle.
            FilledButton.tonal(
              onPressed: controller.stopRecording,
              child: const Text('Stop'),
            ),
          ],
        ),
      CaptureTranscribing() => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text('Transcribing…', style: theme.textTheme.bodyMedium),
          ],
        ),
      CaptureCommitted() => Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Saved.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
            TextButton(
              onPressed: controller.dismiss,
              child: const Text('Record another'),
            ),
          ],
        ),
      CaptureFailed(:final Object error, :final bool canRetry) => Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Something went wrong: $error',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (canRetry)
                  FilledButton(
                    onPressed: controller.retry,
                    child: const Text('Retry transcription'),
                  ),
                if (canRetry) const SizedBox(width: 8),
                TextButton(
                  onPressed: controller.dismiss,
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          ],
        ),
    };
  }
}
