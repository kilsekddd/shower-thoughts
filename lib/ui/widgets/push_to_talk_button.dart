import 'package:flutter/material.dart';

import '../../data/settings_repository.dart';

/// Large, glanceable record control. In [RecordGesture.hold] mode it fires
/// [onStart] the moment the user touches it and [onStop] when they release or
/// drag off — the walkie-talkie / intercom model. In [RecordGesture.toggle]
/// mode it flips between started / stopped on every tap, for longer recordings
/// where holding the button down isn't comfortable.
class PushToTalkButton extends StatefulWidget {
  const PushToTalkButton({
    super.key,
    required this.onStart,
    required this.onStop,
    this.mode = RecordGesture.hold,
    this.label,
    this.activeLabel,
    this.enabled = true,
  });

  final VoidCallback onStart;
  final VoidCallback onStop;
  final RecordGesture mode;
  final String? label;
  final String? activeLabel;
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

  void _handleTapToggle() {
    if (!widget.enabled) return;
    if (_pressed) {
      setState(() => _pressed = false);
      widget.onStop();
    } else {
      setState(() => _pressed = true);
      widget.onStart();
    }
  }

  String _defaultLabel() => switch (widget.mode) {
        RecordGesture.hold => 'Hold to record',
        RecordGesture.toggle => 'Tap to start',
      };

  String _defaultActiveLabel() => switch (widget.mode) {
        RecordGesture.hold => 'Recording…',
        RecordGesture.toggle => 'Tap to stop',
      };

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
    final String label = widget.label ?? _defaultLabel();
    final String activeLabel = widget.activeLabel ?? _defaultActiveLabel();

    final Widget child = AnimatedContainer(
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
              active ? activeLabel : label,
              style: TextStyle(
                color: foreground,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );

    return switch (widget.mode) {
      RecordGesture.hold => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _handleDown(),
          onTapUp: (_) => _handleUp(),
          onTapCancel: _handleUp,
          child: child,
        ),
      RecordGesture.toggle => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleTapToggle,
          child: child,
        ),
    };
  }
}
