import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/stat_strip.dart';
import 'package:drop/features/sales/domain/entities/sales_kpis.dart';
import 'package:drop/features/sales/domain/entities/sales_month_snapshot.dart';
import 'package:drop/features/sales/domain/sales_calculator.dart';
import 'package:drop/features/sales/presentation/sales_format.dart';

/// Read-only monthly pace figures, each labelled in plain words, under one
/// sentence that states the verdict those figures add up to.
class SalesKpiStrip extends StatelessWidget {
  const SalesKpiStrip({super.key, required this.snapshot, required this.kpis});

  final SalesMonthSnapshot snapshot;
  final SalesKpis kpis;

  @override
  Widget build(BuildContext context) {
    if (!snapshot.hasTarget) return const SizedBox.shrink();
    final target = snapshot.target!.targetPiastres;
    final approved = snapshot.approvedTotalPiastres;
    final pace = salesPace(
      targetPiastres: target,
      approvedPiastres: approved,
      expectedMonthEndPiastres: kpis.expectedMonthEndPiastres,
      approvedDayCount: kpis.approvedDayCount,
    );

    final dayWord = kpis.daysRemaining == 1 ? 'day' : 'days';
    final verdict = switch (pace) {
      SalesPace.achieved =>
        'Target reached — ${formatEgp(approved - target, withSuffix: true)} above target with '
            '${kpis.daysRemaining} $dayWord still to sell.',
      SalesPace.noData =>
        'No approved day yet this month, so there is no pace to judge. Approve a '
            'daily close to start tracking.',
      SalesPace.onTrack =>
        'On track — at the current pace the month ends around '
            '${formatEgp(kpis.expectedMonthEndPiastres, withSuffix: true)}, above the target.',
      SalesPace.behind =>
        'Behind — at the current pace the month ends around '
            '${formatEgp(kpis.expectedMonthEndPiastres, withSuffix: true)}, short of the target. '
            'Each remaining day needs ${formatEgp(kpis.neededPerDayPiastres, withSuffix: true)}.',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pace', style: AppTypography.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Approved sales only — pending closes are not counted yet.',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        StatStrip(
          stats: [
            Stat(value: '${kpis.daysRemaining}', label: 'Days left'),
            Stat(
              value: formatEgp(kpis.neededPerDayPiastres, withSuffix: true),
              label: 'Needed per day',
            ),
            Stat(
              value: formatEgp(
                kpis.averagePerApprovedDayPiastres,
                withSuffix: true,
              ),
              label: 'Average per day',
            ),
            Stat(
              value: formatEgp(kpis.expectedMonthEndPiastres, withSuffix: true),
              label: 'Expected month end',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          verdict,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
