import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the current search query as raw user input. The widget layer debounces
/// before pushing into this notifier; downstream stream providers re-query
/// whenever it changes.
class NotesSearchQuery extends StateNotifier<String> {
  NotesSearchQuery() : super('');

  void update(String value) {
    if (value == state) return;
    state = value;
  }

  void clear() {
    if (state.isEmpty) return;
    state = '';
  }
}
