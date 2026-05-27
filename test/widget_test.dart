import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shower_thoughts/app/app.dart';
import 'package:shower_thoughts/app/providers.dart';
import 'package:shower_thoughts/data/database.dart';

void main() {
  testWidgets('app boots to the capture tab', (WidgetTester tester) async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[databaseProvider.overrideWithValue(db)],
        child: const ShowerThoughtsApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Capture'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);
  });
}
