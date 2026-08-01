import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_report.dart';

class AttendanceReportMetrics extends StatelessWidget {
  const AttendanceReportMetrics({
    super.key,
    required this.summary,
    this.weekly = false,
    this.exceptionCount,
    this.exceptionDenominator,
  });

  final AttendanceReportSummary summary;
  final bool weekly;
  final int? exceptionCount;
  final String? exceptionDenominator;

  @override
  Widget build(BuildContext context) {
    // PP8: a metric that cannot be computed does not render a tile reading
    // `--`. A rate with a zero denominator has no value to disclose, and a card
    // showing a dash over `0 / 0` spends full tile weight saying nothing — the
    // observed report had one of six cards in exactly that state. The hub's
    // headline already suppressed these; the grid did not.
    final metrics = (weekly ? _weeklyMetrics() : _dashboardMetrics())
        .where((metric) => metric.isComputable)
        .toList();
    if (metrics.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1120
            ? 3
            : width >= 720
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            // Must fit: 34px icon row + the display-size value + a TWO-line
            // denominator caption, inside AppSpacing.lg padding top and bottom.
            // 132 left only 98px for ~108px of content and overflowed by 9px,
            // clipping the denominator — which is the one thing every metric
            // card exists to disclose (ADR-017's metric bar). Do not lower this
            // without shortening the denominator line.
            mainAxisExtent: 152,
          ),
          itemBuilder: (context, index) => _MetricCard(metric: metrics[index]),
        );
      },
    );
  }

  List<_Metric> _dashboardMetrics() => [
    _Metric(
      label: 'Scheduled shifts',
      value: '${summary.expectedWorkShifts}',
      denominator: summary.excused + summary.onLeave > 0
          ? '${summary.excused + summary.onLeave} excluded from the roster'
          : 'Scheduled shifts, after leave and excused',
    ),
    _Metric(
      label: 'Present',
      value: '${summary.present}',
      denominator:
          '${summary.present} / ${summary.expectedWorkShifts} scheduled shifts',
    ),
    _Metric(
      label: 'Absent',
      value: '${summary.absent}',
      denominator:
          '${summary.absent} / ${summary.expectedWorkShifts} scheduled shifts',
      tone: summary.absent > 0 ? AppColors.error : null,
    ),
    _Metric(
      label: 'Show-up rate',
      value: _rateValue(summary.showUpRate),
      denominator: _rateDenominator(summary.showUpRate),
    ),
    _Metric(
      label: 'Punctual arrivals',
      value: _rateValue(summary.punctualArrivalRate),
      denominator: _rateDenominator(summary.punctualArrivalRate),
    ),
    _Metric(
      label: 'Worked time',
      value: _worked(summary.workedMinutes),
      denominator: 'Across ${summary.present} shifts worked',
    ),
    if (summary.excused > 0 || summary.onLeave > 0)
      _Metric(
        label: 'Excluded context',
        value: '${summary.excused + summary.onLeave}',
        denominator: '${summary.excused} excused · ${summary.onLeave} on leave',
      ),
  ];

  List<_Metric> _weeklyMetrics() => [
    _Metric(
      label: 'Show-up rate',
      value: _rateValue(summary.showUpRate),
      denominator: _rateDenominator(summary.showUpRate),
    ),
    _Metric(
      label: 'Punctual arrivals',
      value: _rateValue(summary.punctualArrivalRate),
      denominator: _rateDenominator(summary.punctualArrivalRate),
    ),
    _Metric(
      label: 'Unexcused absences',
      value: '${summary.absent}',
      denominator:
          '${summary.absent} / ${summary.expectedWorkShifts} scheduled shifts',
      tone: summary.absent > 0 ? AppColors.error : null,
    ),
    _Metric(
      label: 'Hours worked',
      value: _worked(summary.workedMinutes),
      denominator: 'Across ${summary.present} shifts worked',
    ),
    _Metric(
      label: 'Overtime',
      value: _worked(summary.overtimeMinutes),
      denominator: 'Across ${summary.present} shifts worked',
    ),
    _Metric(
      label: 'Needs attention',
      value: '${exceptionCount ?? 0}',
      denominator:
          exceptionDenominator ??
          'Across ${summary.expectedWorkShifts} scheduled shifts',
      tone: (exceptionCount ?? 0) > 0 ? AppColors.warning : null,
    ),
  ];

  static String _rateValue(AttendanceRate rate) {
    final percent = rate.percent;
    return percent == null ? '--' : '${percent.round()}%';
  }

  static String _rateDenominator(AttendanceRate rate) {
    return '${rate.numerator} / ${rate.denominator} ${rate.denominatorLabel}';
  }

  static String _worked(int minutes) {
    if (minutes <= 0) return '0h';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return mins == 0 ? '${hours}h' : '${hours}h ${mins}m';
  }
}

class _Metric {
  const _Metric({
    required this.label,
    required this.value,
    required this.denominator,
    this.tone,
  });

  final String label;
  final String value;
  final String denominator;
  final Color? tone;

  /// A rate with no denominator renders `--`. That is not a number, so it is
  /// not a metric card.
  bool get isComputable => value != '--';
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${metric.label}: ${metric.value}. ${metric.denominator}',
      child: GlassContainer(
        elevated: false,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.mdAll,
                    border: Border.all(color: AppColors.darkBorder),
                    color: AppColors.primarySurface.withValues(alpha: 0.08),
                  ),
                  child: Icon(
                    _iconFor(metric.label),
                    size: 18,
                    color: metric.tone ?? AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                // Flexible, not a bare Text: `maxLines`/`ellipsis` only engage
                // once the text is actually constrained. Unwrapped beside a
                // Spacer it sizes to its natural width and overflows the card
                // instead of ellipsizing — the monthly metric labels are the
                // longest in the app and overflowed a single-column card by 9px.
                Flexible(
                  child: Text(
                    metric.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                metric.value,
                style: AppTypography.displayMedium.copyWith(
                  color: metric.tone ?? AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              metric.denominator,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(String label) {
    return switch (label) {
      'Scheduled shifts' => Icons.event_available_outlined,
      'Present' => Icons.person_pin_circle_outlined,
      'Absent' => Icons.person_off_outlined,
      'Show-up rate' => Icons.percent_rounded,
      'Punctual arrivals' => Icons.schedule_rounded,
      'Worked time' => Icons.timer_outlined,
      'Unexcused absences' => Icons.person_off_outlined,
      'Hours worked' => Icons.timer_outlined,
      'Overtime' => Icons.more_time_rounded,
      'Needs attention' => Icons.report_problem_outlined,
      _ => Icons.remove_circle_outline_rounded,
    };
  }
}
