import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'data/database.dart';
import 'transcription/model_assets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Open the database synchronously-from-the-widget-tree's POV: we await the
  // first-launch model copy here so widgets that read providers don't have to
  // deal with async bootstrap.
  final AppDatabase database = AppDatabase();
  await ensureModelInstalled();

  runApp(
    ProviderScope(
      overrides: <Override>[
        databaseProvider.overrideWithValue(database),
      ],
      child: const ShowerThoughtsApp(),
    ),
  );
}
