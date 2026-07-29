import 'package:flutter/material.dart';
import 'package:drop/core/enums/task_assignment_type.dart';
import 'package:drop/core/enums/task_priority.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/widgets/status_badge.dart';
import 'package:drop/core/widgets/user_avatar.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/domain/task_feed.dart';

/// The dense, scannable feed row (Home Dashboard redesign, P2) — a task rendered
/// as a **single line** for monitoring, not a card for reading:
///
///   ● In progress   Open the shop        [Arkan] ⚑ ZE Ziad   Due 28 Jun ›
///   status dot+label   title (flex)        branch  hi  assignee  due   chevron
///
/// A 2px checklist track underlines the row when the task has a checklist.
/// Colour comes from the canonical [taskStatusColor] (no third status→colour
/// map). Priority shows **only when High**. Tapping expands/opens the task.
class TaskFeedRow extends StatelessWidget {
  const TaskFeedRow({
    super.key,
    required this.task,
    this.directory = const {},
    this.branchName,
    this.onTap,
    this.selected = false,
  });

  final TaskEntity task;
  final Map<String, UserEntity> directory;
  final String? branchName;
  final VoidCallback? onTap;

  /// When true the row is the currently-expanded one (subtle highlight).
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = taskStatusColor(task.status);
    final overdue = isTaskOverdue(task, DateTime.now());
    final hasChecklist = task.hasChecklist;

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? AppColors.darkSurfaceElevated : null,
          border: const Border(
            bottom: BorderSide(color: AppColors.darkBorder, width: 0.6),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(6, 11, 6, 11),
        child: Column(
          children: [
            Row(
              children: [
                // ── status dot + short label ──
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 78,
                  child: Text(
                    _statusLabel(task.status),
                    style: AppTypography.caption.copyWith(color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),

                // ── title ──
                // Flexible (not Expanded) so it shares the row's free space with
                // the branch chip and both ellipsize under pressure — a fixed
                // Expanded title starved by fixed-width meta was overflowing the
                // row on a phone.
                Flexible(
                  flex: 3,
                  child: Text(
                    task.title,
                    style: AppTypography.label.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),

                // ── trailing meta (branch · High · assignee · due) ──
                if ((branchName ?? '').isNotEmpty) ...[
                  Flexible(
                    flex: 2,
                    child: _Chip(
                      icon: Icons.store_mall_directory_outlined,
                      label: branchName!,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (task.priority == TaskPriority.high) ...[
                  const Icon(
                    Icons.flag_rounded,
                    size: 14,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 8),
                ],
                _AssigneeMini(task: task, directory: directory),
                const SizedBox(width: 10),
                _DueLabel(task: task, overdue: overdue),
                const SizedBox(width: 4),
                Icon(
                  selected
                      ? Icons.expand_less_rounded
                      : Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ],
            ),

            // ── checklist underline (progress without a fat bar) ──
            if (hasChecklist) ...[
              const SizedBox(height: 9),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: task.checklistProgress,
                  minHeight: 2,
                  backgroundColor: AppColors.darkSurfaceElevated,
                  valueColor: AlwaysStoppedAnimation(
                    task.checklistDone == task.checklistTotal
                        ? AppColors.success
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The card's friendly label, kept local (like `TaskCard`) so the row doesn't
/// fork a third status→colour map — only the label/short form is row-local.
String _statusLabel(TaskStatus s) => switch (s) {
  TaskStatus.pending => 'To do',
  TaskStatus.started => 'In progress',
  TaskStatus.completed => 'Completed',
  TaskStatus.waitingReview => 'In review',
  TaskStatus.approved => 'Approved',
  TaskStatus.rejected => 'Rejected',
  TaskStatus.missed => 'Missed',
  TaskStatus.cancelled => 'Cancelled',
};

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          // Flexible so a long branch name ellipsizes to whatever width the
          // parent Flexible grants, instead of forcing the row wider.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One avatar for a single assignee (with name), a stack for many, a schedule
/// glyph for a shift task, or a dashed placeholder when unassigned.
class _AssigneeMini extends StatelessWidget {
  const _AssigneeMini({required this.task, required this.directory});
  final TaskEntity task;
  final Map<String, UserEntity> directory;

  @override
  Widget build(BuildContext context) {
    if (task.assignmentType == TaskAssignmentType.shift) {
      return _glyph(Icons.schedule_rounded);
    }
    final resolved = [
      for (final uid in task.assigneeIds)
        if (directory[uid] != null) directory[uid]!,
    ];
    if (task.assigneeIds.isEmpty) {
      return _glyph(Icons.person_add_alt_1_outlined);
    }
    if (resolved.length == 1) {
      // Avatar only — the name text was a fixed-width space hog that starved
      // the title/branch on a phone and caused the row to overflow. The avatar
      // identifies the assignee here; the full name shows in the task detail.
      return UserAvatar.fromUser(resolved.first, size: 22);
    }
    if (resolved.isNotEmpty) return AvatarStack(users: resolved, size: 22);
    return _glyph(Icons.groups_outlined);
  }

  Widget _glyph(IconData icon) => Container(
    width: 22,
    height: 22,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.darkSurfaceElevated,
      border: Border.all(color: AppColors.darkBorder),
    ),
    child: Icon(icon, size: 12, color: AppColors.textTertiary),
  );
}

class _DueLabel extends StatelessWidget {
  const _DueLabel({required this.task, required this.overdue});
  final TaskEntity task;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final d = task.deadline;
    if (d == null) {
      return Text(
        '—',
        style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
      );
    }
    final label = AppDateFormatter.dayMonth(d);
    return Text(
      overdue ? '$label · late' : label,
      textAlign: TextAlign.right,
      style: AppTypography.caption.copyWith(
        color: overdue ? AppColors.error : AppColors.textSecondary,
      ),
    );
  }
}
