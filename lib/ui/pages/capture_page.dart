import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/capture_controller.dart';
import '../../app/providers.dart';
import '../../data/settings_repository.dart';
import '../widgets/push_to_talk_button.dart';

class CapturePage extends ConsumerWidget {
  const CapturePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CaptureState state = ref.watch(captureControllerProvider);
    final CaptureController controller =
        ref.read(captureControllerProvider.notifier);
    final RecordGesture mode = ref.watch(recordGestureProvider);

    // Lock the mode picker while a recording is in flight: switching gesture
    // mid-recording would orphan the button's pressed-state vs. the controller.
    final bool modePickerEnabled =
        state is! CaptureRecording && state is! CaptureTranscribing;

    // Equal Expanded slices above and below the fixed-size PTT button keep
    // the button at vertical screen-center regardless of how the status
    // text wraps under bumped dynamic type. The SegmentedButton hugs the top
    // of its slice and the status panel hugs the top of its slice (just
    // under the button) so growth in either area extends away from, not
    // into, the centered button.
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: <Widget>[
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: SegmentedButton<RecordGesture>(
                segments: const <ButtonSegment<RecordGesture>>[
                  ButtonSegment<RecordGesture>(
                    value: RecordGesture.hold,
                    label: Text('Hold'),
                  ),
                  ButtonSegment<RecordGesture>(
                    value: RecordGesture.toggle,
                    label: Text('Toggle'),
                  ),
                ],
                selected: <RecordGesture>{mode},
                onSelectionChanged: modePickerEnabled
                    ? (Set<RecordGesture> s) =>
                        ref.read(recordGestureProvider.notifier).set(s.first)
                    : null,
              ),
            ),
          ),
          PushToTalkButton(
            mode: mode,
            // Stay interactive while recording so toggle mode can stop on
            // a second tap and hold mode keeps its active-red visual.
            // Only transcribing is a genuine no-gestures window.
            enabled: state is! CaptureTranscribing,
            onStart: controller.startRecording,
            onStop: controller.stopRecording,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Align(
                alignment: Alignment.topCenter,
                child: _StatusPanel(
                  state: state,
                  controller: controller,
                  mode: mode,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown alongside the transcribing spinner and the "Saved." confirmation when
/// the recording was auto-stopped by the cap. Kept short — the user just needs
/// to know their hold was cut short so a missing-tail won't read as a bug.
const String _capReachedMessage =
    'Recording reached the 10-minute cap.';

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.state,
    required this.controller,
    required this.mode,
  });

  final CaptureState state;
  final CaptureController controller;
  final RecordGesture mode;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isHold = mode == RecordGesture.hold;
    return switch (state) {
      CaptureIdle() => Text(
          isHold
              ? 'Tap and hold the button to record a note.'
              : 'Tap the button to start recording.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      CaptureRecording() => Text(
          isHold
              ? 'Recording — release to transcribe.'
              : 'Recording — tap the button again to stop.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.error),
          textAlign: TextAlign.center,
        ),
      CaptureTranscribing(:final bool autoStoppedByCap) => Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
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
            if (autoStoppedByCap) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _capReachedMessage,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      CaptureCommitted(:final bool autoStoppedByCap) => Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Saved.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
            if (autoStoppedByCap) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                _capReachedMessage,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
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
