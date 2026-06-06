import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../app/providers.dart';
import '../../data/database.dart';

/// One row in the notes list: relative timestamp + transcript snippet.
///
/// Swipe-left reveals two end-pane actions:
/// - Complete (active notes) / Reopen (completed notes) — fires immediately,
///   reversible from the other tab.
/// - Delete — confirmed via a Cupertino-style dialog before destroying the
///   row. Deletes are permanent (no trash, no undo) per product decision.
class NoteTile extends ConsumerWidget {
  const NoteTile({super.key, required this.note, required this.onTap});

  final Note note;
  final VoidCallback onTap;

  bool get _isCompleted => note.completedAt != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final DateTime created =
        DateTime.fromMillisecondsSinceEpoch(note.createdAt, isUtc: true)
            .toLocal();
    final bool empty = note.transcript.trim().isEmpty;
    final String snippet = empty ? '(no speech detected)' : note.transcript;
    final TextStyle? snippetStyle = empty
        ? theme.textTheme.bodyMedium
            ?.copyWith(fontStyle: FontStyle.italic, color: theme.disabledColor)
        : theme.textTheme.bodyMedium;

    return Slidable(
      // Group key so revealing a new tile's actions auto-closes any other
      // open tile in the same list. Standard iOS-app behavior.
      groupTag: 'notes_list',
      key: ValueKey<int>(note.id),
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.4,
        children: <Widget>[
          // Icon-only via `CustomSlidableAction` so we can size the glyph
          // explicitly — `SlidableAction`'s default 24px icon looks lost
          // inside the roomier swipe area at expanded dynamic-type sizes.
          CustomSlidableAction(
            onPressed: (_) => _toggleCompleted(ref),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            child: Icon(
              _isCompleted ? Icons.undo : Icons.check,
              size: 34,
            ),
          ),
          CustomSlidableAction(
            onPressed: (_) => _confirmDelete(context, ref),
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
            child: const Icon(Icons.delete_outline, size: 34),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        // Roomier padding so the row breathes at larger dynamic-type sizes
        // and doesn't crowd the swipe-action edge.
        contentPadding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 8),
        minVerticalPadding: 12,
        title: Text(
          snippet,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: snippetStyle,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _relativeTimestamp(created),
            style: theme.textTheme.bodySmall,
          ),
        ),
      ),
    );
  }

  Future<void> _toggleCompleted(WidgetRef ref) async {
    final repo = ref.read(notesRepositoryProvider);
    if (_isCompleted) {
      await repo.markActive(note.id);
    } else {
      await repo.markCompleted(note.id);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => CupertinoAlertDialog(
        title: const Text('Delete note?'),
        content: const Text('This cannot be undone.'),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(notesRepositoryProvider).deleteById(note.id);
  }
}

/// Human-friendly relative timestamp like "2m ago", "yesterday", "Mar 4".
/// Deliberately tiny — pulling in `timeago` for this is overkill.
String _relativeTimestamp(DateTime when) {
  final Duration delta = DateTime.now().difference(when);
  if (delta.inSeconds < 60) return 'just now';
  if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
  if (delta.inHours < 24) return '${delta.inHours}h ago';
  if (delta.inDays == 1) return 'yesterday';
  if (delta.inDays < 7) return '${delta.inDays}d ago';
  const List<String> months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[when.month - 1]} ${when.day}';
}
