import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_weekly_report.dart';

class AttendanceWeeklyEmployeeRows extends StatelessWidget {
  const AttendanceWeeklyEmployeeRows({super.key, required this.employees});

  final List<WeeklyAttendanceEmployeeAggregate> employees;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Employee rows', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Alphabetical facts only. This report does not rank people or compute performance scores.',
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (employees.isEmpty)
            Text(
              'No employee ledger rows are available for this week yet.',
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
                            'Expected',
                            'Present',
                            'Absent',
                            'Late min',
                            'Worked',
                            'OT',
                            'Exceptions',
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
