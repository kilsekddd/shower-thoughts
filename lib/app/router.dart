import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/pages/capture_page.dart';
import '../ui/pages/export_page.dart';
import '../ui/pages/note_detail_page.dart';
import '../ui/pages/notes_list_page.dart';
import 'providers.dart';

class RootScaffold extends ConsumerStatefulWidget {
  const RootScaffold({super.key});

  @override
  ConsumerState<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends ConsumerState<RootScaffold> {
  int _index = 0;

  static const List<Widget> _tabs = <Widget>[
    CapturePage(),
    NotesListPage(),
    ExportPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final AsyncValue<void> boot = ref.watch(bootstrapProvider);
    return boot.when(
      data: (_) => Scaffold(
        body: SafeArea(child: _tabs[_index]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (int i) => setState(() => _index = i),
          destinations: const <NavigationDestination>[
            NavigationDestination(icon: Icon(Icons.mic_none), label: 'Capture'),
            NavigationDestination(icon: Icon(Icons.list), label: 'Notes'),
            NavigationDestination(icon: Icon(Icons.ios_share), label: 'Export'),
          ],
        ),
      ),
      loading: () => const _BootstrapSplash(),
      error: (Object e, StackTrace _) => _BootstrapError(error: e),
    );
  }
}

class _BootstrapSplash extends StatelessWidget {
  const _BootstrapSplash();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 24),
            Text(
              'Setting things up…',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _BootstrapError extends StatelessWidget {
  const _BootstrapError({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            'Could not finish first-launch setup:\n\n$error',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.error),
          ),
        ),
      ),
    );
  }
}

Route<void> noteDetailRoute(int noteId) {
  return MaterialPageRoute<void>(
    builder: (BuildContext _) => NoteDetailPage(noteId: noteId),
  );
}
