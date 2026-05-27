import 'package:flutter/material.dart';

class NoteDetailPage extends StatelessWidget {
  const NoteDetailPage({required this.noteId, super.key});

  final int noteId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Note #$noteId')),
      body: const Center(child: Text('Detail (placeholder — wired in M6)')),
    );
  }
}
