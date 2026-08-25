import 'package:flutter/material.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/glass_container.dart';
import 'package:opshub/core/widgets/user_avatar.dart';
import 'package:opshub/features/operations/domain/employee_workload.dart';

/// One employee's workload as a **slim row** — the core of the Branch
/// Operations cockpit. Identity (avatar · name · role · today's shift), an
/// inline metric line, and the current-task line when there is one, on a
/// [GlassContainer] that draws a soft error border when the employee
/// [EmployeeWorkload.needsAttention] (overdue work). Tapping opens their detail.
///
/// Compressed from a ~160pt card to a ~64–78pt row: the four-up bordered metric
/// strip became one caption line, and role + shift share a line. A branch of ten
/// people is now a scannable list rather than ten screens of repeated chrome.
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
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GlassContainer(
        onTap: onTap,
        highlight: w.needsAttention,
        accent: AppColors.error,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UserAvatar.fromUser(w.user, size: 36),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTypography.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${_capitalize(w.user.role.value)} · ${w.shiftsToday.isEmpty ? 'Off' : w.shiftsToday.map((s) => s.label).join(' · ')}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
            // The strip — and its spacing — are gated on having a figure worth
            // drawing. A caught-up branch used to render one bordered box of
            // four zeros per employee, which is a component that looks failed,
            // repeated down the whole page. Idle people now collapse to a slim
            // identity row so the ones carrying work stand out by height alone.
            if (_figures(w) case final figures when figures.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                figures,
                style: AppTypography.caption.copyWith(
                  color: w.needsAttention
                      ? AppColors.error
                      : AppColors.textSecondary,
                ),
              ),
            ],
            if (w.currentTask != null) _CurrentTaskRow(w: w),
          ],
        ),
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  /// The inline metric line, built from **non-zero figures only**.
  ///
  /// A zero is context, not a metric — printing "0 active · 0 late · 0 in
  /// review" is a component that looks failed, repeated down the whole page, and
  /// avoiding exactly that is why the old four-up strip collapsed on an idle
  /// employee. Building the line from the parts that carry work keeps that
  /// property and lets `completedToday` back in: gating on
  /// [EmployeeWorkload.hasFigures] while omitting Done meant someone who had
  /// only finished work today rendered a row of zeros.
  static String _figures(EmployeeWorkload w) => [
        if (w.active > 0) '${w.active} active',
        if (w.overdue > 0) '${w.overdue} late',
        if (w.submitted > 0) '${w.submitted} in review',
        if (w.completedToday > 0) '${w.completedToday} done',
      ].join(' · ');
}

class _CurrentTaskRow extends StatelessWidget {
  const _CurrentTaskRow({required this.w});
  final EmployeeWorkload w;

  @override
  Widget build(BuildContext context) {
    final task = w.currentTask;
    final Color dot;
    final String text;

    final started = task?.status == TaskStatus.started;
    dot = started ? AppColors.success : AppColors.textTertiary;
    text = '${started ? 'Now' : 'Next'}: ${task?.title ?? ''}';

    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // No chevron here — the identity row above already carries the row's
        // single "opens their detail" affordance. Two stacked chevrons in one
        // card read as two separate destinations.
      ],
    );
  }
}
