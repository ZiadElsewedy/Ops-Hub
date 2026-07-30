import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_weekly_report.dart';

class AttendanceWeeklyDailyTable extends StatelessWidget {
  const AttendanceWeeklyDailyTable({super.key, required this.days});

  final List<WeeklyAttendanceDayBreakdown> days;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Daily rhythm', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Seven business dates are shown. Rows with zero clock-ins report 0%; dates with no rows are ledger data gaps.',
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
                  constraints: const BoxConstraints(minWidth: 720),
                  child: Column(
                    children: [
                      const _DailyRow(
                        cells: [
                          'Day',
                          'Close state',
                          'Expected',
                          'Present',
                          'Show-up',
                          'Absent',
                          'Late min',
                          'Exceptions',
                        ],
                        header: true,
                      ),
                      for (final day in days) _DailyRow(cells: _cellsFor(day)),
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

  static List<String> _cellsFor(WeeklyAttendanceDayBreakdown day) {
    if (!day.hasRows) {
      return [
        _dayLabel(day.date),
        'No ledger data',
        '--',
        '--',
        '--',
        '--',
        '--',
        '--',
      ];
    }
    return [
      _dayLabel(day.date),
      '${day.rows.length} ledger rows',
      '${day.expected}',
      '${day.present}',
      _showUp(day),
      '${day.absent}',
      '${day.lateMinutes}',
      '${day.exceptionCount}',
    ];
  }

  static String _dayLabel(DateTime date) {
    final weekday = AppDateFormatter.weekdayDayMonth(date).split(',').first;
    return '$weekday ${AppDateFormatter.dayMonth(date)}';
  }

  static String _showUp(WeeklyAttendanceDayBreakdown day) {
    if (day.expected == 0) return '--';
    return '${((day.present / day.expected) * 100).round()}%';
  }
}

class _DailyRow extends StatelessWidget {
  const _DailyRow({required this.cells, this.header = false});

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
              width: i == 0 ? 150 : 95,
              child: Text(
                cells[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (header ? AppTypography.caption : AppTypography.label)
                    .copyWith(
                      color: header
                          ? AppColors.textTertiary
                          : i == 1 && cells[i] == 'No ledger data'
                          ? AppColors.warning
                          : AppColors.textSecondary,
                      fontWeight: header ? FontWeight.w600 : FontWeight.w500,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}
