import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/theme.dart';

/// Column definition for [CompactDataTable].
class CompactTableColumn {
  final String label;
  final int flex;

  /// Right-align the cell contents (numbers, actions).
  final bool rightAligned;

  const CompactTableColumn(
    this.label, {
    this.flex = 1,
    this.rightAligned = false,
  });
}

/// One table row: one cell widget per column, in column order.
class CompactDataRow {
  final List<Widget> cells;
  final VoidCallback? onTap;

  const CompactDataRow(this.cells, {this.onTap});
}

/// Compact, dense data table styled like modern admin dashboards:
/// uppercase muted headers, numbered row badges, pill status chips,
/// hover row highlight and a "Showing x to y of z entries" pager footer.
///
/// Give it a bounded width (it fills its parent) — on narrow parents the
/// table overflows into horizontal scrolling at [minWidth].
class CompactDataTable extends StatefulWidget {
  final List<CompactTableColumn> columns;
  final List<CompactDataRow> rows;

  /// Rows shown per page; the footer pager appears when rows exceed this.
  final int pageSize;

  /// Minimum table width before horizontal scrolling kicks in.
  final double minWidth;

  const CompactDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.pageSize = 10,
    this.minWidth = 880,
  });

  // ---- Cell helpers for the screens ----

  static Widget cell(
    BuildContext context,
    String text, {
    Color? color,
    FontWeight weight = FontWeight.w400,
    double size = 12,
  }) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontSize: AppTheme.fontSize(context, size),
      fontWeight: weight,
      color: color ?? AppTheme.textColor(context),
    ),
  );

  /// Blue accent text — item names / primary links.
  static Widget accent(BuildContext context, String text, {double size = 12}) =>
      cell(
        context,
        text,
        color: AppTheme.blueBright(context),
        weight: FontWeight.w600,
        size: size,
      );

  /// Muted secondary text.
  static Widget muted(BuildContext context, String text, {double size = 12}) =>
      cell(context, text, color: AppTheme.secondaryText(context), size: size);

  /// Pill status chip, tinted with [color].
  static Widget chip(BuildContext context, String text, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: AppTheme.fontSize(context, 10.5),
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      );

  /// A row of small action icon buttons for the trailing column.
  static Widget actions(List<Widget> children) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerRight,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          children[i],
        ],
      ],
    ),
  );

  /// Small rounded icon action button (30x30) with a tooltip.
  static Widget actionIcon({
    required IconData icon,
    required Color color,
    required String tooltip,
    VoidCallback? onTap,
  }) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    ),
  );

  @override
  State<CompactDataTable> createState() => _CompactDataTableState();
}

class _CompactDataTableState extends State<CompactDataTable> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        // Finite width when the parent provides one; otherwise the table
        // renders at [minWidth] and scrolls horizontally.
        final w = c.maxWidth.isFinite
            ? math.max(c.maxWidth, widget.minWidth)
            : widget.minWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: w, child: _table(context)),
        );
      },
    );
  }

  Widget _table(BuildContext context) {
    final total = widget.rows.length;
    final totalPages = math.max(1, (total / widget.pageSize).ceil());
    final page = _page.clamp(0, totalPages - 1);
    final start = page * widget.pageSize;
    final end = math.min(start + widget.pageSize, total);
    final pageRows = widget.rows.sublist(start, end);

    return Material(
      color: AppTheme.cardColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.dividerColor(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context),
          for (var i = 0; i < pageRows.length; i++)
            _row(
              context,
              pageRows[i],
              start + i,
              isLast: i == pageRows.length - 1,
            ),
          if (pageRows.isEmpty) _empty(context),
          _footer(context, start, end, total, page, totalPages),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.panelColor(context),
        border: Border(
          bottom: BorderSide(color: AppTheme.dividerColor(context)),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 38), // space for the row number badges
          for (var i = 0; i < widget.columns.length; i++)
            Expanded(
              flex: widget.columns[i].flex,
              child: Align(
                alignment: widget.columns[i].rightAligned
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Text(
                  widget.columns[i].label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppTheme.fontSize(context, 10),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppTheme.secondaryText(context),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    CompactDataRow row,
    int index, {
    required bool isLast,
  }) {
    return _HoverRow(
      onTap: row.onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 46),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                    color: AppTheme.dividerColor(
                      context,
                    ).withValues(alpha: 0.7),
                  ),
                ),
        ),
        child: Row(
          children: [
            _badge(context, index + 1),
            const SizedBox(width: 12),
            for (var i = 0; i < row.cells.length; i++)
              Expanded(
                flex: widget.columns[i].flex,
                child: Align(
                  alignment: widget.columns[i].rightAligned
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: row.cells[i],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _badge(BuildContext context, int n) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Text(
        '$n',
        style: TextStyle(
          fontSize: AppTheme.fontSize(context, 10),
          color: AppTheme.secondaryText(context),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Text(
          'No records found',
          style: TextStyle(
            fontSize: AppTheme.fontSize(context, 12),
            color: AppTheme.secondaryText(context),
          ),
        ),
      ),
    );
  }

  Widget _footer(
    BuildContext context,
    int start,
    int end,
    int total,
    int page,
    int totalPages,
  ) {
    final mutedStyle = TextStyle(
      fontSize: AppTheme.fontSize(context, 11),
      color: AppTheme.secondaryText(context),
    );

    Widget navBtn(String label, VoidCallback? onTap) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderColor(context)),
        ),
        child: Text(
          label,
          style: mutedStyle.copyWith(
            color: onTap == null
                ? AppTheme.secondaryText(context).withValues(alpha: 0.4)
                : AppTheme.textColor(context),
          ),
        ),
      ),
    );

    Widget pageBtn(int p) {
      final isCurrent = p == page;
      return InkWell(
        onTap: isCurrent ? null : () => setState(() => _page = p),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 28,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isCurrent ? AppTheme.blueBright(context) : null,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isCurrent
                  ? AppTheme.blueBright(context)
                  : AppTheme.borderColor(context),
            ),
          ),
          child: Text(
            '${p + 1}',
            style: mutedStyle.copyWith(
              color: isCurrent ? Colors.white : AppTheme.textColor(context),
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      );
    }

    final pages = _pageWindow(page, totalPages);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.dividerColor(context))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Showing ${total == 0 ? 0 : start + 1} to $end of $total entries',
              style: mutedStyle,
            ),
          ),
          navBtn(
            'Previous',
            page > 0 ? () => setState(() => _page = page - 1) : null,
          ),
          const SizedBox(width: 8),
          for (var i = 0; i < pages.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            pageBtn(pages[i]),
          ],
          const SizedBox(width: 8),
          navBtn(
            'Next',
            page < totalPages - 1
                ? () => setState(() => _page = page + 1)
                : null,
          ),
        ],
      ),
    );
  }

  /// Window of page indices to show in the footer (max 7).
  List<int> _pageWindow(int page, int totalPages) {
    if (totalPages <= 7) return List.generate(totalPages, (i) => i);
    final s = (page - 3).clamp(0, totalPages - 7);
    return [for (var i = s; i < s + 7; i++) i];
  }
}

/// Row wrapper that highlights on mouse hover and optionally responds to taps.
class _HoverRow extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _HoverRow({required this.child, this.onTap});

  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: _hover
              ? AppTheme.blueBright(context).withValues(alpha: 0.06)
              : null,
          child: widget.child,
        ),
      ),
    );
  }
}
