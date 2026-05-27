import 'package:flutter/material.dart';

import '../ui/theme.dart';
import 'router.dart';

class ShowerThoughtsApp extends StatelessWidget {
  const ShowerThoughtsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'shower-thoughts',
      theme: buildTheme(),
      home: const RootScaffold(),
      debugShowCheckedModeBanner: false,
    );
  }
}
