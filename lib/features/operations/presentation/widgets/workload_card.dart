import 'package:flutter/material.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/core/widgets/user_avatar.dart';
import 'package:drop/features/operations/domain/employee_workload.dart';

/// One employee's workload at a glance — the core of the Branch Operations
/// cockpit. Identity (avatar · name · role · today's shift), a four-up metric
/// strip (Active · Overdue · Review · Done) and the current-task preview, on a
/// [GlassContainer] that draws a soft error border when the employee
/// [EmployeeWorkload.needsAttention] (overdue work). Tapping opens their detail.
class WorkloadCard extends StatelessWidget {
  const WorkloadCard({super.key, required this.workload, this.onTap});

  final EmployeeWorkload workload;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final w = workload;
    final name = (w.user.displayName != null && w.user.displayName!.isNotEmpty)
        ? w.user.displayName!
        : w.user.email;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: GlassContainer(
        onTap: onTap,
        highlight: w.needsAttention,
        accent: AppColors.error,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UserAvatar.fromUser(w.user, size: 44),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: AppTypography.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(_capitalize(w.user.role.value),
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _ShiftBadge(shifts: w.shiftsToday),
              ],
            ),
            // The strip — and its spacing — are gated on having a figure worth
            // drawing. A caught-up branch used to render one bordered box of
            // four zeros per employee, which is a component that looks failed,
            // repeated down the whole page. Idle people now collapse to a slim
            // identity row so the ones carrying work stand out by height alone.
            if (w.hasFigures) ...[
              const SizedBox(height: AppSpacing.lg),
              _MetricRow(w: w),
              const SizedBox(height: AppSpacing.md),
              const Divider(color: AppColors.darkBorder, height: 1),
              const SizedBox(height: AppSpacing.sm),
            ] else
              const SizedBox(height: AppSpacing.md),
            _CurrentTaskRow(w: w),
          ],
        ),
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

class _ShiftBadge extends StatelessWidget {
  const _ShiftBadge({required this.shifts});
  final List<ScheduleShift> shifts;

  @override
  Widget build(BuildContext context) {
    final off = shifts.isEmpty;
    final label = off ? 'Off' : shifts.map((s) => s.label).join(' · ');
    final color = off ? AppColors.textTertiary : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Text(label, style: AppTypography.caption.copyWith(color: color)),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.w});
  final EmployeeWorkload w;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md, horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          _MetricCell(value: w.active, label: 'Active'),
          _cellDivider(),
          _MetricCell(value: w.overdue, label: 'Late', alert: w.overdue > 0),
          _cellDivider(),
          _MetricCell(value: w.submitted, label: 'Review'),
          _cellDivider(),
          _MetricCell(value: w.completedToday, label: 'Done'),
        ],
      ),
    );
  }

  Widget _cellDivider() =>
      Container(width: 1, height: 26, color: AppColors.darkBorder);
}

class _MetricCell extends StatelessWidget {
  const _MetricCell(
      {required this.value, required this.label, this.alert = false});
  final int value;
  final String label;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    // A zero is context, not a metric: it steps down the grey ramp so only the
    // cells that actually carry work catch the eye across a row of four.
    final Color valueColor = value == 0
        ? AppColors.textTertiary
        : (alert ? AppColors.error : AppColors.textPrimary);
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: AppTypography.label.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.caption, maxLines: 1),
        ],
      ),
    );
  }
}

class _CurrentTaskRow extends StatelessWidget {
  const _CurrentTaskRow({required this.w});
  final EmployeeWorkload w;

  @override
  Widget build(BuildContext context) {
    final task = w.currentTask;
    final Color dot;
    final String text;

    if (task == null) {
      dot = AppColors.textTertiary;
      text = w.submitted > 0 ? 'Waiting on review' : 'Idle · all caught up';
    } else {
      final started = task.status == TaskStatus.started;
      dot = started ? AppColors.success : AppColors.textTertiary;
      text = '${started ? 'Now' : 'Next'}: ${task.title}';
    }

    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(text,
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        const Icon(Icons.chevron_right_rounded,
            size: 18, color: AppColors.textTertiary),
      ],
    );
  }
}
