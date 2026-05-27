import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../data/database.dart';
import '../layout/responsive.dart';
import '../widgets/note_tile.dart';
import '../widgets/search_field.dart';

class NotesListPage extends ConsumerWidget {
  const NotesListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Note>> notes = ref.watch(notesStreamProvider);

    return ResponsiveColumn(
      child: Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SearchField(
            onChanged: (String q) =>
                ref.read(notesSearchQueryProvider.notifier).update(q),
          ),
        ),
        Expanded(
          child: notes.when(
            data: (List<Note> list) {
              if (list.isEmpty) return const _EmptyState();
              return ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (BuildContext context, int i) {
                  final Note note = list[i];
                  return NoteTile(
                    note: note,
                    onTap: () => Navigator.of(context).push(
                      noteDetailRoute(note.id),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object e, StackTrace _) =>
                Center(child: Text('Could not load notes: $e')),
          ),
        ),
      ],
    ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          'No notes yet. Hold the record button on the Capture tab to add one.',
          textAlign: TextAlign.center,
          style:
              theme.textTheme.bodyMedium?.copyWith(color: theme.disabledColor),
        ),
      ),
    );
  }
}
