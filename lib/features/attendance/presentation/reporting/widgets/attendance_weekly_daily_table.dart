import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/utils/app_date_formatter.dart';
import 'package:opshub/core/widgets/glass_container.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_weekly_report.dart';

class AttendanceWeeklyDailyTable extends StatelessWidget {
  const AttendanceWeeklyDailyTable({
    super.key,
    required this.days,
    this.onOpenDay,
  });

  final List<WeeklyAttendanceDayBreakdown> days;

  /// Opens Daily Review for that business date (`ATTENDANCE_REPORTS_IA` §6.8).
  /// Null leaves the rows inert — Monthly has no day rows to open.
  final void Function(WeeklyAttendanceDayBreakdown day)? onOpenDay;

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
            'All seven days. A day with nothing recorded shows No data — that '
            'usually means nobody was scheduled.',
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
                          // A day with nothing recorded has nothing to settle.
                          onTap: onOpenDay == null || !day.hasRows
                              ? null
                              : () => onOpenDay!(day),
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

  /// The per-day show-up percentage is gone with the weekly one
  /// (`ATTENDANCE_REPORTS_IA` §6.5): a rate over a single day at store volumes
  /// is the least reliable figure on the page. `Scheduled` and `Worked` sit
  /// side by side and say the same thing without the false precision.
  static List<String> _cellsFor(WeeklyAttendanceDayBreakdown day) {
    if (!day.hasRows) {
      return [_dayLabel(day.date), 'No data', '--', '--', '--', '--', '--'];
    }
    return [
      _dayLabel(day.date),
      '${day.rows.length} ${day.rows.length == 1 ? 'shift' : 'shifts'}',
      '${day.expected}',
      '${day.present}',
      '${day.absent}',
      '${day.lateMinutes}',
      '${day.exceptionCount}',
    ];
  }

  static String _dayLabel(DateTime date) {
    final weekday = AppDateFormatter.weekdayDayMonth(date).split(',').first;
    return '$weekday ${AppDateFormatter.dayMonth(date)}';
  }

}

class _DailyRow extends StatelessWidget {
  const _DailyRow({
    required this.cells,
    this.header = false,
    this.nobodyCame = false,
    this.onTap,
  });

  final List<String> cells;
  final bool header;
  final bool nobodyCame;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = _row(context);
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }

  Widget _row(BuildContext context) {
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
                          : nobodyCame && (i == 3 || i == 4)
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
