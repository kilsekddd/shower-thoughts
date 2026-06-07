import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shower_thoughts/app/app.dart';
import 'package:shower_thoughts/app/providers.dart';
import 'package:shower_thoughts/audio/cue_player.dart';
import 'package:shower_thoughts/audio/haptic_adapter.dart';
import 'package:shower_thoughts/data/database.dart';

class _NoopCuePlayer implements CuePlayer {
  @override
  Future<void> playStart() async {}
  @override
  Future<void> playStop() async {}
  @override
  Future<void> dispose() async {}
}

class _NoopHapticAdapter implements HapticAdapter {
  @override
  void startCue() {}
  @override
  void stopCue() {}
}

void main() {
  testWidgets('app boots to the capture tab', (WidgetTester tester) async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          cuePlayerProvider.overrideWithValue(_NoopCuePlayer()),
          hapticAdapterProvider.overrideWithValue(_NoopHapticAdapter()),
          // Skip the model-copy bootstrap so the splash doesn't gate the test.
          bootstrapProvider.overrideWith((Ref ref) => Future<void>.value()),
        ],
        child: const ShowerThoughtsApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Capture'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);
  });
}
