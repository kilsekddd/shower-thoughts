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

  // Sizes are kept in sync with the LaunchImage PNG and storyboard layout in
  // ios/Runner/Assets.xcassets/LaunchImage.imageset/ and
  // ios/Runner/Base.lproj/LaunchScreen.storyboard. The launch screen shows
  // the same 160 pt rounded-corner icon centered on a white background. By
  // matching position, size, corner radius, and background here, the
  // transition from native LaunchScreen to Dart splash is invisible.
  static const double _iconSize = 160;
  static const double _iconRadius = 36;
  // Vertical offset from screen-center for the spinner/wordmark cluster,
  // measured as half the icon plus a gap. Putting the spinner+text inside a
  // Transform.translate below the centered Stack means the icon never moves
  // when they appear.
  static const double _belowIconOffset = _iconSize / 2 + 28;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (BuildContext _, BoxConstraints c) {
          final double centerX = c.maxWidth / 2;
          final double centerY = c.maxHeight / 2;
          return Stack(
            children: <Widget>[
              // Icon at exact screen center — matches the LaunchScreen
              // storyboard's centerX/centerY-constrained imageView.
              Positioned(
                left: centerX - _iconSize / 2,
                top: centerY - _iconSize / 2,
                width: _iconSize,
                height: _iconSize,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_iconRadius),
                  child: Image.asset(
                    'assets/icon.png',
                    width: _iconSize,
                    height: _iconSize,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
              // Spinner + wordmark below the icon — never pushes the icon up.
              Positioned(
                left: 0,
                right: 0,
                top: centerY + _belowIconOffset,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Shower Thoughts',
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
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
