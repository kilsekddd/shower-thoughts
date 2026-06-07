import 'package:flutter/services.dart';

abstract class HapticAdapter {
  void startCue();
  void stopCue();
}

class SystemHapticAdapter implements HapticAdapter {
  const SystemHapticAdapter();

  @override
  void startCue() {
    HapticFeedback.mediumImpact();
  }

  @override
  void stopCue() {
    HapticFeedback.lightImpact();
  }
}
