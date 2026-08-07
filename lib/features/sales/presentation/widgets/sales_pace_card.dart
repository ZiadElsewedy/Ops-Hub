import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/features/sales/domain/sales_calculator.dart';
import 'package:drop/features/sales/domain/sales_trend.dart';
import 'package:drop/features/sales/presentation/sales_format.dart';
import 'package:drop/features/sales/presentation/sales_outlook_tint.dart';

/// **Pace** — how the month is trending, in one card: the target verdict up top
/// (are we going to make it?), then the last-7-days approved-takings chart that
/// backs it up. The two used to be a separate banner and a separate chart; the
/// verdict is the read and the chart is the evidence, so they belong together.
///
/// The verdict is the feature's only coloured surface besides *needed per day*,
/// and it colours **status only**: success when projected to beat target, amber
/// when projected short, neutral before there is anything to project from.
class SalesPaceCard extends StatelessWidget {
  const SalesPaceCard({
    super.key,
    required this.trend,
    required this.outlook,
    required this.projectedDeltaPiastres,
  });

  final SalesTrend trend;
  final SalesTargetOutlook outlook;

  /// Forecast month-end minus target. Positive = projected over, negative =
  /// projected short. Its sign is trusted only for [SalesTargetOutlook.ahead] /
  /// [SalesTargetOutlook.behind]; ignored when [tooEarly].
  final int projectedDeltaPiastres;

  @override
  Widget build(BuildContext context) {
    final tone = switch (outlook) {
      SalesTargetOutlook.ahead => AppColors.success,
      SalesTargetOutlook.behind => AppColors.warning,
      SalesTargetOutlook.tooEarly => AppColors.textTertiary,
    };
    final over = projectedDeltaPiastres.abs();
    final (title, subtitle) = switch (outlook) {
      SalesTargetOutlook.ahead => (
        'You’re ahead of target',
        'On pace to finish ${formatEgp(over, withSuffix: true)} over target.',
      ),
      SalesTargetOutlook.behind => (
        'Behind target pace',
        'On pace to finish ${formatEgp(over, withSuffix: true)} short of target.',
      ),
      SalesTargetOutlook.tooEarly => (
        'Pace is still settling',
        'Approve a few daily closes to project the month.',
      ),
    };
    final average = trend.averagePerDayPiastres;
    final changeRatio = trend.changeRatio;

    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'PACE · LAST ${SalesTrend.window} DAYS',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                    letterSpacing: 1,
                  ),
                ),
              ),
              if (changeRatio != null) _TrendChip(ratio: changeRatio),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Verdict ──────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tone.withValues(alpha: 0.14),
                ),
                child: Icon(
                  outlook == SalesTargetOutlook.behind
                      ? Icons.trending_down_rounded
                      : Icons.trending_up_rounded,
                  size: 22,
                  color: tone,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.labelLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Chart ────────────────────────────────────────────────────────
          _TrendChart(trend: trend, todayTint: salesOutlookTint(outlook)),

          if (average > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Averaging ${formatEgp(average, withSuffix: true)} per selling day.',
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The `↑ 12%` (or `↓ 8%`) pill comparing this week's average to last week's.
class _TrendChip extends StatelessWidget {
  const _TrendChip({required this.ratio});
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final up = ratio >= 0;
    final tone = up ? AppColors.success : AppColors.error;
    final percent = (ratio.abs() * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: AppRadius.smAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 12,
            color: tone,
          ),
          const SizedBox(width: 3),
          Text(
            '$percent% vs prev ${SalesTrend.window}d',
            style: AppTypography.caption.copyWith(
              color: tone,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.trend, required this.todayTint});
  final SalesTrend trend;

  /// The status tint for today's bar — matches the hero ACHIEVED figure.
  final Color todayTint;

  static const double _height = 128;

  @override
  Widget build(BuildContext context) {
    final peak = math.max(1, trend.peakPiastres);
    return Semantics(
      label: _semanticSummary(),
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final day in trend.days)
              Expanded(
                child: _Bar(
                  fraction: day.approvedPiastres / peak,
                  valueLabel: day.hasApproved
                      ? formatEgpCompact(day.approvedPiastres)
                      : '—',
                  dayLabel: day.isToday
                      ? 'Today'
                      : _weekday(day.businessDateKey),
                  isToday: day.isToday,
                  todayTint: todayTint,
                  maxBarHeight: _height,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _weekday(String businessDateKey) {
    final date = businessDateFromKey(businessDateKey);
    return date == null ? '' : AppDateFormatter.weekdayShort(date);
  }

  String _semanticSummary() {
    final parts = trend.days.map((d) {
      final label = d.isToday ? 'today' : _weekday(d.businessDateKey);
      return '$label ${formatEgp(d.approvedPiastres, withSuffix: true)}';
    });
    return 'Approved sales, last ${SalesTrend.window} days: ${parts.join(', ')}.';
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.fraction,
    required this.valueLabel,
    required this.dayLabel,
    required this.isToday,
    required this.todayTint,
    required this.maxBarHeight,
  });

  final double fraction;
  final String valueLabel;
  final String dayLabel;
  final bool isToday;
  final Color todayTint;
  final double maxBarHeight;

  @override
  Widget build(BuildContext context) {
    // A day with no approved close still shows a faint stub so the axis reads
    // as seven days, not a gap.
    final barHeight = fraction <= 0
        ? 4.0
        : math.max(6.0, maxBarHeight * fraction.clamp(0.0, 1.0));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            valueLabel,
            style: AppTypography.caption.copyWith(
              color: isToday ? todayTint : AppColors.textTertiary,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              fontSize: 10,
            ),
            maxLines: 1,
          ),
          const SizedBox(height: 6),
          Container(
            height: barHeight,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(6),
                bottom: Radius.circular(2),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isToday
                    ? [
                        todayTint,
                        Color.lerp(todayTint, AppColors.darkBg, 0.55)!,
                      ]
                    : const [
                        AppColors.darkSurfaceElevated,
                        AppColors.darkBorder,
                      ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            dayLabel,
            style: AppTypography.caption.copyWith(
              color: isToday ? todayTint : AppColors.textTertiary,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
              fontSize: 10,
            ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}
