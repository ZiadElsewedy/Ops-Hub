import 'package:flutter/material.dart';
import 'package:opshub/core/responsive/breakpoints.dart';
import 'package:opshub/core/theme/app_spacing.dart';

/// Lays a list of cards out in a width-aware grid so wide desktop windows show
/// several cards per row instead of one stretched, over-wide card — while mobile
/// stays a single readable column.
///
/// Two sizing modes:
/// * **[maxItemWidth] set (preferred for content cards)** — the column count is
///   derived from the available width so **no card is ever wider than
///   [maxItemWidth]**. This keeps cards a comfortable, consistent size at every
///   window size (a lone card sits in one narrow cell rather than stretching).
/// * **breakpoint columns** — a fixed count per tier ([desktopColumns] /
///   [ultrawideColumns]); mobile always 1.
///
/// Lays children out row by row (not a [GridView], so rows can hold a ragged
/// final count). Within each row, cards **stretch to match the tallest
/// sibling in that row** — so a short card never sits next to a tall one with
/// a visible height mismatch — while rows are otherwise free to be as tall or
/// short as their content needs. Intended to wrap card children inside an
/// existing scroll view.
class ResponsiveCardGrid extends StatelessWidget {
  const ResponsiveCardGrid({
    super.key,
    required this.children,
    this.spacing = AppSpacing.md,
    double? runSpacing,
    this.maxItemWidth,
    this.tabletColumns = 2,
    this.desktopColumns = 2,
    this.ultrawideColumns = 3,
  }) : runSpacing = runSpacing ?? spacing;

  final List<Widget> children;

  /// Horizontal gap between cards in a row.
  final double spacing;

  /// Vertical gap between rows (and between items in the single-column layout).
  /// Pass `0` when the cards already carry their own bottom margin/padding, to
  /// avoid double spacing.
  final double runSpacing;

  /// When set, column count is derived so each card is at most this wide
  /// (comfortable, consistent card size). Overrides the breakpoint columns.
  final double? maxItemWidth;

  final int tabletColumns;
  final int desktopColumns;
  final int ultrawideColumns;

  int _breakpointColumns(BuildContext context) {
    if (context.isUltrawide) return ultrawideColumns;
    if (context.isDesktop) return desktopColumns;
    if (context.isTablet) return tabletColumns;
    return 1;
  }

  Widget _singleColumn() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0 && runSpacing > 0) SizedBox(height: runSpacing),
            children[i],
          ],
        ],
      );

  Widget _grid(int columns, double maxWidth) {
    final itemWidth = (maxWidth - spacing * (columns - 1)) / columns;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      final rowChildren = children.skip(i).take(columns).toList();
      if (rows.isNotEmpty && runSpacing > 0) {
        rows.add(SizedBox(height: runSpacing));
      }
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < rowChildren.length; j++) ...[
                if (j > 0) SizedBox(width: spacing),
                SizedBox(width: itemWidth, child: rowChildren[j]),
              ],
            ],
          ),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    // Width-derived columns: no card wider than [maxItemWidth].
    if (maxItemWidth != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final columns =
              (constraints.maxWidth / maxItemWidth!).ceil().clamp(1, 6);
          if (columns <= 1) return _singleColumn();
          return _grid(columns, constraints.maxWidth);
        },
      );
    }

    // Breakpoint columns.
    final columns = _breakpointColumns(context);
    if (columns <= 1) return _singleColumn();
    return LayoutBuilder(
      builder: (context, constraints) => _grid(columns, constraints.maxWidth),
    );
  }
}
