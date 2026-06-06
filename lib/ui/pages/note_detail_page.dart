import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/database.dart';
import '../layout/responsive.dart';

/// Note detail: read + edit + complete/reopen + delete.
///
/// The transcript lives in an editable `TextField`. The app-bar actions are
/// stateful: while the field is "dirty" (text differs from what's persisted),
/// Cancel and Save replace the complete-toggle and Delete. Save writes back
/// through the repository; Cancel reverts. Delete confirms via Cupertino
/// dialog before destroying the row; the back gesture also confirms when
/// there are unsaved edits.
class NoteDetailPage extends ConsumerStatefulWidget {
  const NoteDetailPage({required this.noteId, super.key});

  final int noteId;

  @override
  ConsumerState<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends ConsumerState<NoteDetailPage> {
  final TextEditingController _controller = TextEditingController();
  // The text we last synced from the database. Used to compute dirtiness and
  // to seed the controller exactly once on first load — subsequent stream
  // emissions don't clobber in-progress edits.
  String? _persistedText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isDirty =>
      _persistedText != null && _controller.text != _persistedText;

  void _seedFromNote(Note note) {
    if (_persistedText != null) return;
    _persistedText = note.transcript;
    _controller.text = note.transcript;
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() => setState(() {});

  Future<void> _save(Note note) async {
    final String text = _controller.text;
    await ref.read(notesRepositoryProvider).updateTranscript(note.id, text);
    setState(() => _persistedText = text);
  }

  void _cancel() {
    if (_persistedText == null) return;
    _controller.text = _persistedText!;
    setState(() {});
  }

  Future<void> _toggleCompleted(Note note) async {
    final repo = ref.read(notesRepositoryProvider);
    if (note.completedAt != null) {
      await repo.markActive(note.id);
    } else {
      await repo.markCompleted(note.id);
    }
  }

  Future<void> _confirmAndDelete(Note note) async {
    final bool? ok = await _confirm(
      title: 'Delete note?',
      message: 'This cannot be undone.',
      destructiveLabel: 'Delete',
    );
    if (ok != true || !mounted) return;
    await ref.read(notesRepositoryProvider).deleteById(note.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<bool> _confirmDiscardIfDirty() async {
    if (!_isDirty) return true;
    final bool? ok = await _confirm(
      title: 'Discard changes?',
      message: 'Your edits will be lost.',
      destructiveLabel: 'Discard',
    );
    return ok ?? false;
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String destructiveLabel,
  }) {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(destructiveLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Note?> noteAsync =
        ref.watch(noteByIdProvider(widget.noteId));

    return noteAsync.when(
      data: (Note? note) {
        if (note == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Note')),
            body: const Center(child: Text('Note not found.')),
          );
        }
        _seedFromNote(note);
        return _buildLoaded(note);
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Note')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (Object e, StackTrace _) => Scaffold(
        appBar: AppBar(title: const Text('Note')),
        body: Center(child: Text('Could not load note: $e')),
      ),
    );
  }

  Widget _buildLoaded(Note note) {
    final ThemeData theme = Theme.of(context);
    final DateTime created =
        DateTime.fromMillisecondsSinceEpoch(note.createdAt, isUtc: true)
            .toLocal();
    final String durationStr =
        '${(note.durationMs / 1000).toStringAsFixed(1)}s';
    final bool completed = note.completedAt != null;

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (bool didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscardIfDirty() && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Note'),
          actions: _isDirty
              ? <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: OutlinedButton(
                      onPressed: _cancel,
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: FilledButton.tonal(
                      onPressed: () => _save(note),
                      child: const Text('Save'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ]
              : <Widget>[
                  IconButton(
                    tooltip: completed ? 'Reopen' : 'Mark complete',
                    icon: Icon(completed ? Icons.undo : Icons.check),
                    onPressed: () => _toggleCompleted(note),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmAndDelete(note),
                  ),
                ],
        ),
        body: SingleChildScrollView(
          // Roomier horizontal padding so prose doesn't kiss the screen edge
          // at larger dynamic-type sizes; vertical breathing room below the
          // app bar and above the safe-area bottom.
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: ResponsiveColumn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _absoluteTimestamp(created),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.disabledColor),
                ),
                const SizedBox(height: 6),
                Text(
                  'Duration: $durationStr · Model: ${note.modelId}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.disabledColor),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _controller,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  style: theme.textTheme.bodyLarge,
                  // `isCollapsed: true` would zero out the field's internal
                  // padding; let it use the default so the cursor and text
                  // don't sit flush against the edges at larger text sizes.
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
              ],
            ),
          ),
        ),
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
