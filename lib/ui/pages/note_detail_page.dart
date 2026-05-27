import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/database.dart';

class NoteDetailPage extends ConsumerWidget {
  const NoteDetailPage({required this.noteId, super.key});

  final int noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Note?> noteAsync = ref.watch(noteByIdProvider(noteId));

    return Scaffold(
      appBar: AppBar(title: const Text('Note')),
      body: noteAsync.when(
        data: (Note? note) => note == null
            ? const Center(child: Text('Note not found.'))
            : _NoteBody(note: note),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) =>
            Center(child: Text('Could not load note: $e')),
      ),
    );
  }
}

class _NoteBody extends StatelessWidget {
  const _NoteBody({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTime created =
        DateTime.fromMillisecondsSinceEpoch(note.createdAt, isUtc: true)
            .toLocal();
    final String durationStr =
        '${(note.durationMs / 1000).toStringAsFixed(1)}s';
    final String transcriptText = note.transcript.trim().isEmpty
        ? '(no speech detected)'
        : note.transcript;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _absoluteTimestamp(created),
            style:
                theme.textTheme.bodySmall?.copyWith(color: theme.disabledColor),
          ),
          const SizedBox(height: 4),
          Text(
            'Duration: $durationStr · Model: ${note.modelId}',
            style:
                theme.textTheme.bodySmall?.copyWith(color: theme.disabledColor),
          ),
          const SizedBox(height: 24),
          SelectableText(
            transcriptText,
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

String _absoluteTimestamp(DateTime when) {
  const List<String> months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final String hh = when.hour.toString().padLeft(2, '0');
  final String mm = when.minute.toString().padLeft(2, '0');
  return '${months[when.month - 1]} ${when.day}, ${when.year}  $hh:$mm';
}
