import 'package:flutter/material.dart';

/// Large, glanceable hold-to-record control. Fires [onStart] the moment the
/// user touches it and [onStop] when they release or drag off.
///
/// Tap-down/up semantics (not long-press) so the user sees instant feedback
/// and a quick "oops" release still counts as a recording attempt — keeping
/// the model the user already built with walkie-talkies and intercoms.
class PushToTalkButton extends StatefulWidget {
  const PushToTalkButton({
    super.key,
    required this.onStart,
    required this.onStop,
    this.label = 'Hold to record',
    this.activeLabel = 'Recording…',
    this.enabled = true,
  });

  final VoidCallback onStart;
  final VoidCallback onStop;
  final String label;
  final String activeLabel;
  final bool enabled;

  @override
  State<PushToTalkButton> createState() => _PushToTalkButtonState();
}

class _PushToTalkButtonState extends State<PushToTalkButton> {
  bool _pressed = false;

  void _handleDown() {
    if (!widget.enabled || _pressed) return;
    setState(() => _pressed = true);
    widget.onStart();
  }

  void _handleUp() {
    if (!_pressed) return;
    setState(() => _pressed = false);
    widget.onStop();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool active = _pressed;
    final Color background = !widget.enabled
        ? scheme.surfaceContainerHighest
        : active
            ? scheme.error
            : scheme.primary;
    final Color foreground = !widget.enabled
        ? scheme.onSurfaceVariant
        : active
            ? scheme.onError
            : scheme.onPrimary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _handleDown(),
      onTapUp: (_) => _handleUp(),
      onTapCancel: _handleUp,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: background.withValues(alpha: 0.4),
              blurRadius: active ? 32 : 16,
              spreadRadius: active ? 4 : 0,
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                active ? Icons.mic : Icons.mic_none,
                size: 72,
                color: foreground,
              ),
              const SizedBox(height: 12),
              Text(
                active ? widget.activeLabel : widget.label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
