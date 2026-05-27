import 'package:flutter/material.dart';

import '../../data/database.dart';

/// One row in the notes list: relative timestamp + transcript snippet. Tap
/// fires [onTap] (typically pushes the detail page).
class NoteTile extends StatelessWidget {
  const NoteTile({super.key, required this.note, required this.onTap});

  final Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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

    return ListTile(
      onTap: onTap,
      title: Text(
        snippet,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: snippetStyle,
      ),
      subtitle: Text(
        _relativeTimestamp(created),
        style: theme.textTheme.bodySmall,
      ),
    );
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
