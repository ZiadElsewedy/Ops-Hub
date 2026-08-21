import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/animated_count.dart';
import 'package:opshub/core/widgets/glass_container.dart';

/// One cell in a [StatStrip] — a label + a glanceable value, optionally tinted.
///
/// A value can be supplied two ways:
/// * [count] — an integer that **counts up** (~650ms ease-out) when it changes,
///   the premium treatment for a live "today" number. Takes precedence.
/// * [value] — a ready-made string (e.g. "96%", "—") that cross-fades on change,
///   for values that aren't a plain integer.
class Stat {
  const Stat({
    required this.label,
    this.value,
    this.count,
    this.suffix = '',
    this.tone,
    this.onTap,
  }) : assert(
          value != null || count != null,
          'A Stat needs either a string value or an int count',
        );

  final String label;

  /// A ready-made string value (e.g. "96%", "—"). Cross-fades when it changes.
  /// Ignored when [count] is provided.
  final String? value;

  /// An integer value that counts up when it changes. Rendered via
  /// [AnimatedCount] with [suffix] appended (e.g. "%").
  final int? count;

  /// Suffix appended after a [count] (e.g. "%"). Unused for a string [value].
  final String suffix;

  /// Optional semantic tint for the value (null = monochrome white).
  final Color? tone;

  /// When set, the cell becomes a real tap target (press/hover feedback, a
  /// `Semantics` button label) that drills into that stat's own list — e.g.
  /// "Missed" pushes the list of missed tasks. Null keeps the cell purely
  /// informational (a context count like "Branches", or a ratio like
  /// "Complete" that isn't a list of anything).
  final VoidCallback? onTap;
}

/// **StatStrip** — a calm, single-surface row of small facts (DROP Design System
/// V2). The lightweight "here's today" layer: a few `value / label` stats inside
/// one quiet [GlassContainer], no charts. The small sibling of a metric-card
/// grid, for the supporting numbers that inform without demanding action.
///
/// Reusable anywhere a compact fact row is needed (a dashboard "Today" line, a
/// branch health summary, a detail header). Responsive: a single divided row
/// when it fits, a two-column wrap when it doesn't — so it never overflows on a
/// phone or under large text.
class StatStrip extends StatelessWidget {
  const StatStrip({super.key, required this.stats});

  final List<Stat> stats;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const SizedBox.shrink();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return GlassContainer(
      elevated: false,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Enough room for every stat side-by-side? Otherwise wrap to 2-up.
          final fitsOneRow = constraints.maxWidth >= stats.length * 118;
          return fitsOneRow
              ? _row(stats, reduceMotion)
              : _grid(stats, reduceMotion);
        },
      ),
    );
  }

  Widget _cell(
    Stat s,
    bool reduceMotion, {
    TextAlign align = TextAlign.start,
  }) {
    final cross = align == TextAlign.center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    final valueStyle = AppTypography.h2.copyWith(
      color: s.tone ?? AppColors.textPrimary,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    );
    // An integer value counts up to its new figure; a string value cross-fades.
    // Either way a live "Today" number moves rather than snapping, so it feels
    // alive and premium.
    final Widget valueWidget = s.count != null
        ? AnimatedCount(
            value: s.count!,
            suffix: s.suffix,
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 650),
            style: valueStyle,
          )
        : AnimatedSwitcher(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 320),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.35),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: Text(
              s.value!,
              key: ValueKey('${s.label}:${s.value}'),
              textAlign: align,
              style: valueStyle,
            ),
          );
    final content = Column(
      crossAxisAlignment: cross,
      mainAxisSize: MainAxisSize.min,
      children: [
        valueWidget,
        const SizedBox(height: 3),
        // Supporting label under the white metric → light grey.
        Text(
          s.label,
          textAlign: align,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
    if (s.onTap == null) return content;
    // A real tap target (>=44pt via the vertical padding) with press/hover
    // feedback — this app runs on macOS desktop too, so hover matters.
    return Semantics(
      button: true,
      label: '${s.label}: ${s.value ?? s.count}',
      child: InkWell(
        onTap: s.onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: content,
        ),
      ),
    );
  }

  /// A single row with hairline dividers between cells.
  Widget _row(List<Stat> stats, bool reduceMotion) {
    final children = <Widget>[];
    for (var i = 0; i < stats.length; i++) {
      if (i > 0) {
        children.add(
          Container(
            width: 1,
            height: 34,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            color: AppColors.darkBorder,
          ),
        );
      }
      children.add(Expanded(child: _cell(stats[i], reduceMotion)));
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: children);
  }

  /// A two-column wrap for narrow widths (no vertical dividers).
  Widget _grid(List<Stat> stats, bool reduceMotion) {
    return Column(
      children: [
        for (var i = 0; i < stats.length; i += 2) ...[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: _cell(stats[i], reduceMotion)),
              const SizedBox(width: AppSpacing.md),
              if (i + 1 < stats.length)
                Expanded(child: _cell(stats[i + 1], reduceMotion))
              else
                const Spacer(),
            ],
          ),
        ],
      ],
    );
  }
}
