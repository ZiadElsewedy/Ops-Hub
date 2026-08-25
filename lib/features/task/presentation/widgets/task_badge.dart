import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';

/// The label + colour of a task's lifecycle badge. Pure + unit-testable.
/// Returns `null` when no badge applies.
///
/// The badge now carries **only what the status pill can't** — `REWORK #n`
/// (revision count) and `NEW` (unseen). Approved / Rejected were **removed**
/// (Home Dashboard redesign P1, 2026-07-03): the card's `_StatusPill` already
/// renders those from the same status, so a badge for them stacked the word
/// twice ("Approved" over "Approved"). One pill per fact. Precedence:
/// rework → new. Colours: **NEW stays monochrome** (white accent);
/// REWORK → amber (existing semantic palette).
({String label, Color color})? taskBadgeFor(TaskEntity task) {
  if (task.requiresRework) {
    return (label: 'REWORK #${task.revisionNumber}', color: AppColors.warning);
  }
  if (task.isNew) {
    return (label: 'NEW', color: AppColors.primary);
  }
  return null;
}

/// A small tinted pill rendering [taskBadgeFor]. Renders nothing when no badge
/// applies, so it can be dropped into a row unconditionally.
class TaskBadge extends StatelessWidget {
  const TaskBadge({super.key, required this.task});

  final TaskEntity task;

  @override
  Widget build(BuildContext context) {
    final badge = taskBadgeFor(task);
    if (badge == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badge.color.withAlpha(34),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badge.color.withAlpha(110)),
      ),
      child: Text(
        badge.label,
        style: AppTypography.caption.copyWith(
          color: badge.color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
