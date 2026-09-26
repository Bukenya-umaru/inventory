import 'package:flutter/material.dart';
import '../utils/theme.dart';

bool matchesSectionSearch(String query, Iterable<Object?> values) {
  final normalized = query.trim().toLowerCase();
  return normalized.isEmpty ||
      values.any(
        (value) => value?.toString().toLowerCase().contains(normalized) == true,
      );
}

class SectionSearchBar extends StatefulWidget {
  final String hintText;
  final ValueChanged<String> onSearch;

  const SectionSearchBar({
    super.key,
    required this.hintText,
    required this.onSearch,
  });

  @override
  State<SectionSearchBar> createState() => _SectionSearchBarState();
}

class _SectionSearchBarState extends State<SectionSearchBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search() => widget.onSearch(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppTheme.pad(context, 16)),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: widget.hintText,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _search,
            icon: const Icon(Icons.search, size: 18),
            label: const Text('Search'),
          ),
        ],
      ),
    );
  }
}
