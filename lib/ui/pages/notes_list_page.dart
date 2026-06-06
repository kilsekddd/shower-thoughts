import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../data/database.dart';
import '../layout/responsive.dart';
import '../widgets/note_tile.dart';
import '../widgets/search_field.dart';

/// Two-tab list: Active notes (default) and Completed notes. The search field
/// sits above the tabs and applies to whichever tab is selected, so switching
/// tabs with a query active filters the other view by the same text.
class NotesListPage extends ConsumerWidget {
  const NotesListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: ResponsiveColumn(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: SearchField(
                onChanged: (String q) =>
                    ref.read(notesSearchQueryProvider.notifier).update(q),
              ),
            ),
            // `isScrollable: true` keeps the two tab labels readable when
            // the user has bumped dynamic type up — without it, "Completed"
            // can clip on smaller screens at larger text sizes.
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: <Widget>[
                Tab(text: 'Active'),
                Tab(text: 'Completed'),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: <Widget>[
                  _NotesTabBody(filter: _NotesFilter.active),
                  _NotesTabBody(filter: _NotesFilter.completed),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _NotesFilter { active, completed }

class _NotesTabBody extends ConsumerWidget {
  const _NotesTabBody({required this.filter});

  final _NotesFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Note>> notes = switch (filter) {
      _NotesFilter.active => ref.watch(notesActiveStreamProvider),
      _NotesFilter.completed => ref.watch(notesCompletedStreamProvider),
    };

    return notes.when(
      data: (List<Note> list) {
        if (list.isEmpty) return _EmptyState(filter: filter);
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
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});

  final _NotesFilter filter;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String message = switch (filter) {
      _NotesFilter.active =>
        'No notes yet. Hold the record button on the Capture tab to add one.',
      _NotesFilter.completed =>
        'Nothing completed yet. Swipe a note on the Active tab to mark it done.',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style:
              theme.textTheme.bodyMedium?.copyWith(color: theme.disabledColor),
        ),
      ),
    );
  }
}
