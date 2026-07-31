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
          Text('By day', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'All seven days. A day with shifts recorded but nobody in shows 0%; '
            'a day with nothing recorded shows No data.',
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
                          'Recorded',
                          'Scheduled',
                          'Worked',
                          'Show-up',
                          'Absent',
                          'Late min',
                          'Issues',
                        ],
                        header: true,
                      ),
                      for (final day in days)
                        _DailyRow(
                          cells: _cellsFor(day),
                          nobodyCame: _nobodyCame(day),
                        ),
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

  /// A day that had scheduled shifts and nobody worked them. This is the only
  /// day-level situation that is a genuine attendance *result*, and so the only
  /// one that earns an alarm colour.
  ///
  /// A day with no records at all is not this. It is unknown — the report reads
  /// recorded shifts only, so it cannot yet tell "nobody was scheduled" from
  /// "somebody was and it was never captured". Colouring that amber is what made
  /// a week with six unrostered days read as a disaster.
  static bool _nobodyCame(WeeklyAttendanceDayBreakdown day) =>
      day.hasRows && day.expected > 0 && day.present == 0;

  static List<String> _cellsFor(WeeklyAttendanceDayBreakdown day) {
    if (!day.hasRows) {
      return [
        _dayLabel(day.date),
        'No data',
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
      '${day.rows.length} ${day.rows.length == 1 ? 'shift' : 'shifts'}',
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
  const _DailyRow({
    required this.cells,
    this.header = false,
    this.nobodyCame = false,
  });

  final List<String> cells;
  final bool header;
  final bool nobodyCame;

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
                      // Three states, three treatments (PP6). "No data" is
                      // quieter than an ordinary row, not louder: it is the
                      // absence of a result, not a bad one. Only a day that was
                      // scheduled and worked by nobody is toned.
                      color: header
                          ? AppColors.textTertiary
                          : cells[1] == 'No data'
                          ? AppColors.textTertiary
                          : nobodyCame && (i == 4 || i == 5)
                          ? AppColors.error
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
