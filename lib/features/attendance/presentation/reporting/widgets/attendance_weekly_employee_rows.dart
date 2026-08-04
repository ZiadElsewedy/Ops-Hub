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
    this.showStatus = false,
    this.onOpenEmployee,
  });

  final List<WeeklyAttendanceEmployeeAggregate> employees;

  /// Opens one person's records. Slot-based so this widget stays
  /// presentation-only: the report screen owns which branch and period the row
  /// was read in, and this table never needs to know. Null leaves the rows
  /// inert, exactly as before.
  final ValueChanged<WeeklyAttendanceEmployeeAggregate>? onOpenEmployee;

  /// The Monthly report renders the same employee facts over a month window and
  /// only needs different empty-state copy.
  final String emptyMessage;

  /// Adds the Status column and tones the rows that need attention.
  ///
  /// Weekly only. Monthly stays a plain alphabetical roll of the month: a status
  /// word there would imply the month is a queue of things to act on, when the
  /// week is where acting happens.
  final bool showStatus;

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
          if (showStatus || onOpenEmployee != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              // Hover and the pointer cursor carry the affordance on desktop;
              // on a phone there is neither, so the one place a reviewer can
              // reach a single person's record has to say so.
              [
                if (showStatus) 'Anyone needing attention is listed first.',
                if (onOpenEmployee != null)
                  'Open anyone to see their own records for this period.',
              ].join(' '),
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
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
                    constraints: BoxConstraints(
                      minWidth: showStatus ? 900 : 780,
                    ),
                    child: Column(
                      children: [
                        _EmployeeRow(
                          cells: [
                            'Employee',
                            'Scheduled',
                            'Worked',
                            'Absent',
                            'Late min',
                            'Hours',
                            'Overtime',
                            if (showStatus) 'Status' else 'Issues',
                          ],
                          header: true,
                        ),
                        for (final employee in employees)
                          _EmployeeRow(
                            cells: _cellsFor(employee, showStatus),
                            band: showStatus ? employee.attentionBand : null,
                            onTap: onOpenEmployee == null
                                ? null
                                : () => onOpenEmployee!(employee),
                            semanticName: employee.displayName,
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

  static List<String> _cellsFor(
    WeeklyAttendanceEmployeeAggregate employee,
    bool showStatus,
  ) => [
    employee.displayName,
    '${employee.expected}',
    '${employee.present}',
    '${employee.absent}',
    '${employee.lateMinutes}',
    _minutes(employee.workedMinutes),
    _minutes(employee.overtimeMinutes),
    if (showStatus)
      employee.attentionBand.label
    else
      '${employee.exceptionCount}',
  ];

  static String _minutes(int minutes) {
    if (minutes <= 0) return '0h';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return mins == 0 ? '${hours}h' : '${hours}h ${mins}m';
  }
}

class _EmployeeRow extends StatefulWidget {
  const _EmployeeRow({
    required this.cells,
    this.header = false,
    this.band,
    this.onTap,
    this.semanticName,
  });

  final List<String> cells;
  final bool header;
  final AttendanceAttentionBand? band;
  final VoidCallback? onTap;
  final String? semanticName;

  @override
  State<_EmployeeRow> createState() => _EmployeeRowState();
}

class _EmployeeRowState extends State<_EmployeeRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cells = widget.cells;
    final header = widget.header;
    final band = widget.band;
    final last = cells.length - 1;
    final tappable = widget.onTap != null && !header;
    final lit = tappable && _hovered;

    final row = Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: header
            ? AppColors.darkSurfaceElevated
            : lit
            ? AppColors.darkSurfaceElevated
            : AppColors.darkSurface.withValues(alpha: 0.72),
        border: const Border(bottom: BorderSide(color: AppColors.darkBorder)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            SizedBox(
              width: i == 0
                  ? 180
                  : i == last && band != null
                  ? 150
                  : 82,
              child: Text(
                cells[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (header ? AppTypography.caption : AppTypography.label)
                    .copyWith(
                      // Only the Status cell carries tone, and only when the
                      // person needs something. Toning the whole row would make
                      // a late arrival look like an emergency. On hover the
                      // *name* brightens — the affordance points at the thing
                      // the row opens, not at the numbers.
                      color: header
                          ? AppColors.textTertiary
                          : i == last
                          ? _statusColour(band)
                          : lit && i == 0
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: header ? FontWeight.w600 : FontWeight.w500,
                    ),
              ),
            ),
        ],
      ),
    );

    if (!tappable) return row;

    return Semantics(
      button: true,
      label: widget.semanticName == null
          ? 'Open attendance history'
          : 'Open ${widget.semanticName}\'s attendance history',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: row,
        ),
      ),
    );
  }

  static Color _statusColour(AttendanceAttentionBand? band) => switch (band) {
    null => AppColors.textSecondary,
    AttendanceAttentionBand.needsDecision => AppColors.warning,
    AttendanceAttentionBand.absent => AppColors.error,
    AttendanceAttentionBand.late => AppColors.textSecondary,
    AttendanceAttentionBand.clean => AppColors.textTertiary,
  };
}
