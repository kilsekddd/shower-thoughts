import 'dart:async';

import 'package:flutter/material.dart';

/// Debounced text field. Calls [onChanged] only after the user has stopped
/// typing for [debounce], so we don't fire a new FTS query on every keystroke.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.onChanged,
    this.hintText = 'Search notes',
    this.debounce = const Duration(milliseconds: 200),
  });

  final ValueChanged<String> onChanged;
  final String hintText;
  final Duration debounce;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _handleChange(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounce, () => widget.onChanged(value));
    setState(() {}); // refresh the suffix-clear button
  }

  void _clear() {
    _debounceTimer?.cancel();
    _controller.clear();
    widget.onChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: _handleChange,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(icon: const Icon(Icons.clear), onPressed: _clear),
        border: const OutlineInputBorder(),
        // Default (non-dense) vertical padding — `isDense: true` clips
        // ascenders / descenders at larger dynamic-type sizes.
      ),
    );
  }
}
