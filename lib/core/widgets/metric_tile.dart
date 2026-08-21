import 'package:flutter/material.dart';
import 'package:opshub/core/responsive/breakpoints.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/animated_count.dart';
import 'package:opshub/core/widgets/glass_container.dart';

/// **MetricTile** — a light, **always tappable** figure cell (DROP Design System
/// V2). A big counting-up number, a glyph + label, and an `arrow_outward`
/// affordance so it reads as a door rather than as printed text.
///
/// The quieter sibling of `AttentionTile`: that one is the *triage* layer (it
/// rewards a cleared queue with a reassurance instead of a number, and tints
/// itself when there is work). A `MetricTile` always shows its figure, because
/// its job is a fact you can open — "3 Open", "1 Late", "2 Staff active".
///
/// **Every tile opens something.** A figure no list can reproduce does not
/// belong here: a cell that looks identical to its tappable neighbours but does
/// nothing is worse than one that isn't drawn at all. Where a count and its
/// drill-down could disagree, derive the count with the same predicate the
/// drill-down filters on.
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.onTap,
    this.alert = false,
  });

  /// The figure. Counts up (~650ms) when it moves, unless motion is reduced.
  final int value;

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  /// Draw this tile in the error tone — the one thing on the row that is wrong.
  /// Only ever true when [value] is non-zero.
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final hot = alert && value > 0;
    final tone = hot ? AppColors.error : AppColors.textPrimary;
    return Semantics(
      button: true,
      label: '$value $label',
      child: GlassContainer(
        onTap: onTap,
        highlight: hot,
        accent: AppColors.error,
        borderRadius: AppRadius.lgAll,
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                AnimatedCount(
                  value: value,
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 650),
                  style: AppTypography.h1.copyWith(
                    fontSize: 26,
                    height: 1.1,
                    color: tone,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.arrow_outward_rounded,
                  size: 16,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(icon, size: 13, color: tone.withAlpha(180)),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Lays [tiles] out the way a metric row should read: **one tight row** on
/// desktop, **2-up rows** on mobile and tablet — never the single stretched
/// column a generic card grid would give a phone, which turns four facts into
/// four full-width bands.
class MetricTileRow extends StatelessWidget {
  const MetricTileRow({super.key, required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();

    // `IntrinsicHeight` on every row: the tiles stretch to match the tallest
    // sibling so a row never shows a ragged bottom edge, and a bare `stretch`
    // Row inside a Column would otherwise be handed an infinite height.
    if (context.isDesktop) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, t) in tiles.indexed) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              Expanded(child: t),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < tiles.length; i += 2) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tiles[i]),
                // An odd last tile spans the full width instead of sitting
                // beside a `Spacer`. The hole read as a tile that had failed to
                // load — the one shape on the page with nothing in it.
                if (i + 1 < tiles.length) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: tiles[i + 1]),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
