import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shower_thoughts/app/app.dart';

void main() {
  testWidgets('app boots to the capture tab', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: ShowerThoughtsApp()),
    );
    await tester.pump();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Capture'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);
  });
}
