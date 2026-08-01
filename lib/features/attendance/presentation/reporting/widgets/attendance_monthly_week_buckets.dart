import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_monthly_report.dart';

/// The month-specific section: every Schedule week (Sunday→Saturday) that
/// overlaps the month, so a change can be located inside the month.
class AttendanceMonthlyWeekBuckets extends StatelessWidget {
  const AttendanceMonthlyWeekBuckets({super.key, required this.buckets});

  final List<MonthlyAttendanceWeekBucket> buckets;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weekly buckets', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Sunday to Saturday roster weeks. A week that only partly overlaps this month is marked Partial and is never read as a full week. A week with shifts recorded but nobody in shows 0%; a week with nothing recorded shows No data.',
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ClipRRect(
            borderRadius: AppRadius.lgAll,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.darkBorder),
                borderRadius: AppRadius.lgAll,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 860),
                  child: Column(
                    children: [
                      const _BucketRow(
                        cells: [
                          'Week',
                          'Coverage',
                          'Recorded',
                          'Expected',
                          'Present',
                          'Show-up',
                          'Absent',
                          'Blockers',
                        ],
                        header: true,
                      ),
                      for (final bucket in buckets)
                        _BucketRow(cells: _cellsFor(bucket)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static List<String> _cellsFor(MonthlyAttendanceWeekBucket bucket) {
    final label =
        '${AppDateFormatter.dayMonth(bucket.weekStart)} - ${AppDateFormatter.dayMonth(bucket.weekEnd)}';
    final coverage = bucket.isPartial
        ? 'Partial · ${bucket.coveredDayCount} of 7 days in month'
        : 'Full week';
    if (!bucket.hasRows) {
      return [label, coverage, 'No data', '--', '--', '--', '--', '--'];
    }
    return [
      label,
      coverage,
      '${bucket.rows.length} rows',
      '${bucket.expected}',
      '${bucket.present}',
      _showUp(bucket),
      '${bucket.absent}',
      '${bucket.blockingExceptionCount}',
    ];
  }

  static String _showUp(MonthlyAttendanceWeekBucket bucket) {
    final percent = bucket.showUpRate.percent;
    return percent == null ? '--' : '${percent.round()}%';
  }
}

class _BucketRow extends StatelessWidget {
  const _BucketRow({required this.cells, this.header = false});

  final List<String> cells;
  final bool header;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: header
            ? AppColors.darkSurfaceElevated
            : AppColors.darkSurface.withValues(alpha: 0.72),
        border: const Border(bottom: BorderSide(color: AppColors.darkBorder)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            SizedBox(
              width: i == 0
                  ? 150
                  : i == 1
                  ? 210
                  : 95,
              child: Text(
                cells[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (header ? AppTypography.caption : AppTypography.label)
                    .copyWith(
                      color: header
                          ? AppColors.textTertiary
                          : _toneFor(i, cells[i]),
                      fontWeight: header ? FontWeight.w600 : FontWeight.w500,
                    ),
              ),
            ),
        ],
      ),
    );
  }

  static Color _toneFor(int index, String value) {
    // PP6: nothing recorded is the absence of a result, not a bad one.
    if (index == 2 && value == 'No data') return AppColors.textTertiary;
    if (index == 1 && value.startsWith('Partial')) return AppColors.warning;
    return AppColors.textSecondary;
  }
}
