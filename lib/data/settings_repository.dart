import 'package:shared_preferences/shared_preferences.dart';

/// How the user drives the record button on the capture screen.
///
/// - [hold]: press-and-hold (walkie-talkie). Release stops the recording.
/// - [toggle]: tap to start, tap again to stop. Safe to leave because the
///   capture controller still enforces the 10-minute cap.
enum RecordGesture { hold, toggle }

/// Typed wrapper over [SharedPreferences]. Centralises the string keys and
/// keeps callers free of stringly-typed gets/sets. New settings live as
/// `_xxxKey` private constants alongside a typed getter + setter pair, mirroring
/// the [recordGesture] shape below.
class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String _recordGestureKey = 'record_gesture';

  RecordGesture get recordGesture {
    final String? raw = _prefs.getString(_recordGestureKey);
    if (raw == null) return RecordGesture.hold;
    for (final RecordGesture g in RecordGesture.values) {
      if (g.name == raw) return g;
    }
    return RecordGesture.hold;
  }

  Future<void> setRecordGesture(RecordGesture v) async {
    await _prefs.setString(_recordGestureKey, v.name);
  }
}
