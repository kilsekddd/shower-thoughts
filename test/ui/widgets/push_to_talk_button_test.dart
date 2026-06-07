import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shower_thoughts/data/settings_repository.dart';
import 'package:shower_thoughts/ui/widgets/push_to_talk_button.dart';

void main() {
  testWidgets('toggle mode fires onStart then onStop on alternating taps',
      (WidgetTester tester) async {
    int starts = 0;
    int stops = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PushToTalkButton(
              mode: RecordGesture.toggle,
              onStart: () => starts++,
              onStop: () => stops++,
            ),
          ),
        ),
      ),
    );

    expect(starts, 0);
    expect(stops, 0);

    await tester.tap(find.byType(PushToTalkButton));
    await tester.pump();
    expect(starts, 1);
    expect(stops, 0);

    await tester.tap(find.byType(PushToTalkButton));
    await tester.pump();
    expect(starts, 1);
    expect(stops, 1);
  });

  testWidgets('hold mode fires onStart on tap-down and onStop on tap-up',
      (WidgetTester tester) async {
    int starts = 0;
    int stops = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PushToTalkButton(
              onStart: () => starts++,
              onStop: () => stops++,
            ),
          ),
        ),
      ),
    );

    final TestGesture gesture =
        await tester.startGesture(tester.getCenter(find.byType(PushToTalkButton)));
    await tester.pump();
    expect(starts, 1);
    expect(stops, 0);

    await gesture.up();
    await tester.pump();
    expect(starts, 1);
    expect(stops, 1);
  });
}
