import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/rolling_number.dart';
import 'package:opshub/features/sales/presentation/sales_format.dart';
import 'package:opshub/features/sales/presentation/widgets/sales_progress_ring.dart';

/// The month hero: **achieved · progress ring · remaining** across the top, a
/// hairline, then the **target** it is all measured against.
///
/// Manager-dashboard specific — the shared [SalesMoneyRow] stays the flat
/// three-figure row every other sales surface uses; this is the one screen that
/// earns the ring. Achieved is the emphasised (white) figure — the number that
/// moves; remaining and target read in the grey ramp below it.
class SalesMonthOverview extends StatelessWidget {
  const SalesMonthOverview({
    super.key,
    required this.targetPiastres,
    required this.achievedPiastres,
    required this.remainingPiastres,
    required this.progressRatio,
    this.tint = AppColors.textPrimary,
  });

  final int targetPiastres;
  final int achievedPiastres;
  final int remainingPiastres;

  /// Capped `0..1` progress toward target — the ring's fill.
  final double progressRatio;

  /// The outlook status tint for ACHIEVED + the ring (green ahead / amber
  /// behind / white early). Defaults to white so the widget reads plainly on
  /// its own; the dashboard passes `salesOutlookTint(outlook)`.
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final leftPercent = targetPiastres <= 0
        ? 0.0
        : (remainingPiastres / targetPiastres * 100).clamp(0, 100);
    return Semantics(
      label:
          'Achieved ${formatEgp(achievedPiastres, withSuffix: true)}, '
          'remaining ${formatEgp(remainingPiastres, withSuffix: true)}, '
          'target ${formatEgp(targetPiastres, withSuffix: true)}.',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _Figure(
                    label: 'ACHIEVED',
                    valuePiastres: achievedPiastres,
                    color: tint,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SalesProgressRing(ratio: progressRatio, tint: tint),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _Figure(
                    label: 'REMAINING',
                    valuePiastres: remainingPiastres,
                    alignEnd: true,
                    footnote: '${leftPercent.toStringAsFixed(1)}% left',
                    // …then Remaining follows a beat later — a left-to-right
                    // cascade across the hero row.
                    delay: const Duration(milliseconds: 260),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(height: 1, color: AppColors.darkBorder),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                const _IconBadge(icon: Icons.adjust_rounded),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TARGET',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textTertiary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: RollingNumber(
                          value: targetPiastres,
                          formatter: (v) =>
                              formatEgp(v.round(), withSuffix: true),
                          animateOnMount: true,
                          // Last in the cascade, below the hero row.
                          delay: const Duration(milliseconds: 360),
                          style: AppTypography.h3.copyWith(
                            color: AppColors.textSecondary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
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

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.valuePiastres,
    this.color,
    this.alignEnd = false,
    this.footnote,
    this.delay = Duration.zero,
  });

  final String label;
  final int valuePiastres;

  /// The figure's colour — the brand accent for the leading figures (achieved),
  /// null for a supporting figure (remaining), which reads in the grey ramp.
  final Color? color;
  final bool alignEnd;
  final String? footnote;

  /// Stagger forwarded to the rolling figure so the row resolves as a cascade.
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final cross = alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final boxAlign = alignEnd ? Alignment.centerRight : Alignment.centerLeft;
    return Column(
      crossAxisAlignment: cross,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textTertiary,
            letterSpacing: 0.8,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: boxAlign,
          child: RollingNumber(
            value: valuePiastres,
            formatter: (v) => formatEgp(v.round()),
            animateOnMount: true,
            delay: delay,
            style: AppTypography.h2.copyWith(
              color: color ?? AppColors.textSecondary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          footnote ?? 'EGP',
          style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// The soft square glyph tile the month and pace cards share for a label's icon.
class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: AppColors.darkSurfaceElevated,
      borderRadius: AppRadius.mdAll,
      border: Border.all(color: AppColors.darkBorder),
    ),
    child: Icon(icon, size: 20, color: AppColors.textSecondary),
  );
}
