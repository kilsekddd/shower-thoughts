import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shower_thoughts/data/settings_repository.dart';

void main() {
  group('SettingsRepository.recordGesture', () {
    test('defaults to hold when nothing is stored', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SettingsRepository repo = SettingsRepository(prefs);

      expect(repo.recordGesture, RecordGesture.hold);
    });

    test('round-trips set/get', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SettingsRepository repo = SettingsRepository(prefs);

      await repo.setRecordGesture(RecordGesture.toggle);
      expect(repo.recordGesture, RecordGesture.toggle);

      await repo.setRecordGesture(RecordGesture.hold);
      expect(repo.recordGesture, RecordGesture.hold);
    });

    test('falls back to hold on an unknown stored value', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'record_gesture': 'something_unknown',
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SettingsRepository repo = SettingsRepository(prefs);

      expect(repo.recordGesture, RecordGesture.hold);
    });

    test('reads a pre-existing valid value', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'record_gesture': 'toggle',
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SettingsRepository repo = SettingsRepository(prefs);

      expect(repo.recordGesture, RecordGesture.toggle);
    });
  });
}
