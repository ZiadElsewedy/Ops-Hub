import 'package:flutter/material.dart';
import 'package:drop/core/enums/attendance_status.dart';
import 'package:drop/core/enums/swap_status.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_typography.dart';

/// Small tinted status pill — one component for every Pending / Approved /
/// Rejected / Completed / Active … indicator. Background + border are tinted in
/// the status colour (the look the task card already used).
///
/// Use a typed factory (`StatusBadge.task(...)`, `.swap(...)`, `.active(...)`) so
/// the colour + label mapping lives in exactly one place, or the default
/// constructor for an ad-hoc label/colour.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.compact = false,
  });

  final String label;
  final Color color;
  final bool compact;

  factory StatusBadge.task(TaskStatus status) =>
      StatusBadge(label: _taskLabel(status), color: _taskColor(status));

  factory StatusBadge.swap(SwapStatus status) =>
      StatusBadge(label: _swapLabel(status), color: _swapColor(status));

  factory StatusBadge.active(bool isActive, {bool compact = false}) =>
      StatusBadge(
        label: isActive ? 'Active' : 'Inactive',
        color: isActive ? AppColors.success : AppColors.error,
        compact: compact,
      );

  factory StatusBadge.attendance(AttendanceStatus status) =>
      StatusBadge(label: status.label, color: attendanceStatusColor(status));

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Text(label, style: AppTypography.caption.copyWith(color: color)),
    );
  }
}

/// The single source for a task status' semantic colour — reused by
/// [StatusBadge.task] and the premium card glow ([AppGlassCard]) so the mapping
/// lives in exactly one place.
Color taskStatusColor(TaskStatus s) => _taskColor(s);

/// The single source for an attendance record's status colour — reused by
/// [StatusBadge.attendance] and the History ledger. Calm by default: only the
/// states that call for action carry a semantic tint (working = success, pending
/// review = warning, absent = error); planned/neutral states stay grey.
Color attendanceStatusColor(AttendanceStatus s) {
  switch (s) {
    case AttendanceStatus.scheduled:
      return AppColors.textTertiary;
    case AttendanceStatus.inProgress:
      return AppColors.success;
    case AttendanceStatus.completed:
      return AppColors.textSecondary;
    case AttendanceStatus.pendingReview:
      return AppColors.warning;
    case AttendanceStatus.absent:
      return AppColors.error;
    case AttendanceStatus.onLeave:
      return AppColors.textSecondary;
    case AttendanceStatus.excused:
      // A forgiven absence — neutral, not an error tint.
      return AppColors.textSecondary;
  }
}

Color _taskColor(TaskStatus s) {
  switch (s) {
    case TaskStatus.pending:
      return AppColors.textTertiary;
    case TaskStatus.started:
    case TaskStatus.waitingReview:
      return AppColors.warning;
    case TaskStatus.completed:
      return AppColors.primary;
    case TaskStatus.approved:
      return AppColors.success;
    case TaskStatus.rejected:
      return AppColors.error;
    case TaskStatus.missed:
      return AppColors.error;
  }
}

String _taskLabel(TaskStatus s) {
  switch (s) {
    case TaskStatus.pending:
      return 'Pending';
    case TaskStatus.started:
      return 'Started';
    case TaskStatus.completed:
      return 'Completed';
    case TaskStatus.waitingReview:
      return 'Waiting Review';
    case TaskStatus.approved:
      return 'Approved';
    case TaskStatus.rejected:
      return 'Rejected';
    case TaskStatus.missed:
      return 'Missed';
  }
}

Color _swapColor(SwapStatus s) {
  switch (s) {
    case SwapStatus.pending:
    case SwapStatus.employeeApproved:
      return AppColors.warning; // pending stages = amber
    case SwapStatus.managerApproved:
      return AppColors.success; // approved = emerald
    case SwapStatus.rejected:
      return AppColors.error; // rejected = red
    case SwapStatus.cancelled:
      return AppColors.textTertiary; // cancelled = neutral grey
  }
}

String _swapLabel(SwapStatus s) {
  switch (s) {
    case SwapStatus.pending:
      return 'Pending';
    case SwapStatus.employeeApproved:
      return 'Coworker approved';
    case SwapStatus.managerApproved:
      return 'Approved';
    case SwapStatus.rejected:
      return 'Rejected';
    case SwapStatus.cancelled:
      return 'Cancelled';
  }
}
