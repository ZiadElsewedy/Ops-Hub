import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/rolling_number.dart';
import 'package:drop/features/sales/domain/sales_calculator.dart';
import 'package:drop/features/sales/presentation/sales_format.dart';

/// **Needed per day** — the one pace figure the sales surfaces keep.
///
/// It reports *today* in the muted sales palette: [AppColors.salesEmerald] when
/// today's close met the requirement, [AppColors.salesAmber] at 50–99%, and
/// [AppColors.salesCoral] (a softened red — intentional, not aggressive) below
/// half. With nothing to judge (no target, target met, or no close yet) it stays
/// monochrome — an unsubmitted day is not a failed one.
///
/// Colour is carried by a hairline, a tinted glyph and the [RollingNumber]
/// figure itself, never by a filled block: colour expresses status, not surface.
class SalesNeededPerDay extends StatelessWidget {
  const SalesNeededPerDay({
    super.key,
    required this.neededPerDayPiastres,
    required this.todayPiastres,
    required this.daysRemaining,
  });

  final int neededPerDayPiastres;

  /// Today's submitted amount, or null when the day has not been closed.
  final int? todayPiastres;
  final int daysRemaining;

  @override
  Widget build(BuildContext context) {
    final pace = salesDayPace(
      neededPerDayPiastres: neededPerDayPiastres,
      todayPiastres: todayPiastres,
    );
    final tone = switch (pace) {
      SalesDayPace.onPace => AppColors.salesEmerald,
      SalesDayPace.close => AppColors.salesAmber,
      SalesDayPace.behind => AppColors.salesCoral,
      SalesDayPace.none => AppColors.darkBorder,
    };
    final valueColor = pace == SalesDayPace.none
        ? AppColors.textPrimary
        : tone;

    final caption = switch (pace) {
      SalesDayPace.onPace =>
        'Today’s ${formatEgp(todayPiastres!, withSuffix: true)} covers it.',
      SalesDayPace.close =>
        'Today’s ${formatEgp(todayPiastres!, withSuffix: true)} is short of it.',
      SalesDayPace.behind =>
        'Today’s ${formatEgp(todayPiastres!, withSuffix: true)} is well under it.',
      SalesDayPace.none when neededPerDayPiastres <= 0 =>
        'The monthly target is already covered.',
      SalesDayPace.none => 'Today hasn’t been submitted yet.',
    };

    return Semantics(
      label:
          'Needed per day ${formatEgp(neededPerDayPiastres, withSuffix: true)}. $caption',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardAll,
            border: Border.all(color: tone.withValues(alpha: 0.55)),
            color: AppColors.darkSurface,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NEEDED PER DAY',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    RollingNumber(
                      value: neededPerDayPiastres,
                      formatter: (v) => formatEgp(v.round(), withSuffix: true),
                      animateOnMount: true,
                      delay: const Duration(milliseconds: 480),
                      style: AppTypography.h2.copyWith(
                        color: valueColor,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      caption,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$daysRemaining',
                    style: AppTypography.h3.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    daysRemaining == 1 ? 'day left' : 'days left',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
