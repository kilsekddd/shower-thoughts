import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'app/third_party_licenses.dart';
import 'data/database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // showLicensePage() auto-discovers LICENSE files in pub packages but does
  // not know about native artifacts vendored outside pub-cache. Register the
  // whisper.cpp xcframework + bundled model + SQLite attributions so they
  // appear alongside the Dart packages.
  registerNativeArtifactLicenses();

  // Open the database synchronously here so widgets can read it directly.
  // The 77 MB model copy is intentionally NOT awaited — it runs via
  // bootstrapProvider so the UI can show a splash instead of a black
  // screen on first launch.
  final AppDatabase database = AppDatabase();
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: <Override>[
        databaseProvider.overrideWithValue(database),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const ShowerThoughtsApp(),
    ),
  );
}
