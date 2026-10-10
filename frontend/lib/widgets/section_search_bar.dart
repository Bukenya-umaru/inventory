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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppTheme.pad(context, 16)),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              onChanged: (_) => _search(),
              style: TextStyle(
                fontSize: AppTheme.fontSize(context, 13),
                color: AppTheme.textColor(context),
              ),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: TextStyle(
                  fontSize: AppTheme.fontSize(context, 13),
                  color: AppTheme.secondaryText(context),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 20,
                  color: AppTheme.secondaryText(context),
                ),
                isDense: true,
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF1A262D)
                    : Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: AppTheme.borderColor(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: AppTheme.borderColor(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(
                    color: AppTheme.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
