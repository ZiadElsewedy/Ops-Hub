import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_weekly_report.dart';

class AttendanceWeeklyEmployeeRows extends StatelessWidget {
  const AttendanceWeeklyEmployeeRows({
    super.key,
    required this.employees,
    this.emptyMessage = 'Nobody has a recorded shift this week yet.',
  });

  final List<WeeklyAttendanceEmployeeAggregate> employees;

  /// The Monthly report renders the same employee facts over a month window and
  /// only needs different empty-state copy.
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The defensive sentence that used to sit here — "Alphabetical facts
          // only. This report does not rank people or compute performance
          // scores." — was written because we already suspected the table would
          // be misread. A UI that has to explain what it is not is telling you
          // the design is wrong; the fix is to remove the need for the
          // disclaimer, not to word it better. Not ranking people is enforced by
          // refusing to compute a score (ADR-017), not by a caption.
          Text('By person', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.lg),
          if (employees.isEmpty)
            Text(
              emptyMessage,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else
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
                    constraints: const BoxConstraints(minWidth: 780),
                    child: Column(
                      children: [
                        const _EmployeeRow(
                          cells: [
                            'Employee',
                            'Scheduled',
                            'Worked',
                            'Absent',
                            'Late min',
                            'Hours',
                            'Overtime',
                            'Issues',
                          ],
                          header: true,
                        ),
                        for (final employee in employees)
                          _EmployeeRow(cells: _cellsFor(employee)),
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

  static List<String> _cellsFor(WeeklyAttendanceEmployeeAggregate employee) => [
    employee.displayName,
    '${employee.expected}',
    '${employee.present}',
    '${employee.absent}',
    '${employee.lateMinutes}',
    _minutes(employee.workedMinutes),
    _minutes(employee.overtimeMinutes),
    '${employee.exceptionCount}',
  ];

  static String _minutes(int minutes) {
    if (minutes <= 0) return '0h';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return mins == 0 ? '${hours}h' : '${hours}h ${mins}m';
  }
}

class _EmployeeRow extends StatelessWidget {
  const _EmployeeRow({required this.cells, this.header = false});

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
              width: i == 0 ? 180 : 82,
              child: Text(
                cells[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (header ? AppTypography.caption : AppTypography.label)
                    .copyWith(
                      color: header
                          ? AppColors.textTertiary
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
