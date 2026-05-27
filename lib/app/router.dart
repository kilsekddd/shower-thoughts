import 'package:flutter/material.dart';

import '../ui/pages/capture_page.dart';
import '../ui/pages/export_page.dart';
import '../ui/pages/note_detail_page.dart';
import '../ui/pages/notes_list_page.dart';

class RootScaffold extends StatefulWidget {
  const RootScaffold({super.key});

  @override
  State<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<RootScaffold> {
  int _index = 0;

  static const List<Widget> _tabs = <Widget>[
    CapturePage(),
    NotesListPage(),
    ExportPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
    );
  }
}

Route<void> noteDetailRoute(int noteId) {
  return MaterialPageRoute<void>(
    builder: (BuildContext _) => NoteDetailPage(noteId: noteId),
  );
}
