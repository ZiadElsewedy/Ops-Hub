import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/stat_strip.dart';
import 'package:drop/features/sales/domain/entities/sales_kpis.dart';
import 'package:drop/features/sales/domain/entities/sales_month_snapshot.dart';
import 'package:drop/features/sales/presentation/sales_format.dart';

/// Read-only monthly KPIs that help a manager decide whether to intervene.
class SalesKpiStrip extends StatelessWidget {
  const SalesKpiStrip({
    super.key,
    required this.snapshot,
    required this.kpis,
  });

  final SalesMonthSnapshot snapshot;
  final SalesKpis kpis;

  @override
  Widget build(BuildContext context) {
    if (!snapshot.hasTarget) return const SizedBox.shrink();
    final completion = kpis.completionDateEstimate;
    final monthKey = snapshot.target!.monthKey;
    final monthEnd = DateTime(
      int.parse(monthKey.substring(0, 4)),
      int.parse(monthKey.substring(4, 6)) + 1,
      0,
    );
    final isOnTrack = completion != null && !completion.isAfter(monthEnd);
    final dateText = completion == null
        ? null
        : MaterialLocalizations.of(context).formatMediumDate(completion);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pace', style: AppTypography.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Use these signals to decide whether action is needed today.',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        StatStrip(
          stats: [
            Stat(value: '${kpis.daysRemaining}', label: 'Days left · time pressure'),
            Stat(
              value: formatEgp(kpis.requiredDailyRunRatePiastres, withSuffix: true),
              label: 'Need / day · intervene today?',
            ),
            Stat(
              value: formatEgp(kpis.averageApprovedDailyPiastres, withSuffix: true),
              label: 'Avg / day · current pace',
            ),
            Stat(
              value: formatEgp(kpis.monthEndForecastPiastres, withSuffix: true),
              label: 'Forecast · on track?',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          completion == null
              ? 'Behind pace · intervene today?'
              : isOnTrack
              ? 'On track by $dateText'
              : 'Behind pace · projected completion $dateText',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
