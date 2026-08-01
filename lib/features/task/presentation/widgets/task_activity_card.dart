import 'package:flutter/material.dart';
import 'package:drop/core/enums/task_assignment_type.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/widgets/activity_card.dart';
import 'package:drop/core/widgets/status_badge.dart';
import 'package:drop/core/widgets/user_avatar.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/domain/task_outcomes.dart';
import 'package:drop/features/task/presentation/activity_format.dart';
import 'package:drop/features/task/presentation/widgets/task_preview_sheet.dart';

/// Maps a [TaskEntity] onto the generic V2 [ActivityCard] — the clean,
/// vertical replacement for the dense feed row on the dashboard's Recent
/// activity + filtered task views. Reads top-to-bottom:
///
///   [assignee]  Open the shop            Waiting Review
///               Ahmed · Arkan branch     5 min ago
///
/// Tapping opens the shared preview sheet (triage without leaving the screen).
class TaskActivityCard extends StatelessWidget {
  const TaskActivityCard({
    super.key,
    required this.task,
    required this.directory,
    this.branchName,
    this.showDeadline = false,
  });

  final TaskEntity task;
  final Map<String, UserEntity> directory;
  final String? branchName;

  /// Prefixes the meta line with the task's deadline (e.g. `Due 2 Aug, 18:00 ·
  /// 5 min ago`). Opt-in: this card is shared with the dashboard's Recent
  /// Activity feed, which already has the status badge for "what's happening"
  /// and doesn't need the deadline repeated — only [FilteredTasksScreen]'s
  /// full-list drill-downs turn it on.
  final bool showDeadline;

  UserEntity? get _firstAssignee {
    for (final uid in task.assigneeIds) {
      final u = directory[uid];
      if (u != null) return u;
    }
    return null;
  }

  String _assigneeLabel() {
    if (task.assignmentType == TaskAssignmentType.shift) {
      final s = task.shift;
      return s == null ? 'Shift task' : '${s.label} shift';
    }
    if (task.assigneeIds.isEmpty) return 'Unassigned';
    final u = _firstAssignee;
    final name = u == null
        ? 'Someone'
        : ((u.displayName?.isNotEmpty ?? false) ? u.displayName! : u.email);
    final extra = task.assigneeIds.length - 1;
    return extra > 0 ? '$name +$extra' : name;
  }

  Widget _leading() {
    if (task.assignmentType == TaskAssignmentType.shift) {
      return _glyph(Icons.schedule_rounded);
    }
    final u = _firstAssignee;
    if (u != null) return UserAvatar.fromUser(u, size: 34);
    return _glyph(Icons.person_add_alt_1_outlined);
  }

  Widget _glyph(IconData icon) => Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.darkSurfaceElevated,
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Icon(icon, size: 16, color: AppColors.textTertiary),
      );

  @override
  Widget build(BuildContext context) {
    final assignee = _assigneeLabel();
    final branch = (branchName ?? '').trim();
    final subtitle = branch.isEmpty ? assignee : '$assignee · $branch';
    final when = task.updatedAt ?? task.createdAt;
    final lateness = taskLateness(task);
    // A finished-late task adds a quiet second meta line rather than replacing
    // the timestamp — the card still answers "when", lateness is additional.
    final activity = when == null
        ? (lateness == null ? null : formatLateness(lateness))
        : (lateness == null
              ? AppDateFormatter.relative(when)
              : '${AppDateFormatter.relative(when)} · ${formatLateness(lateness)}');
    final deadline = task.deadline;
    final due = showDeadline && deadline != null
        ? 'Due ${AppDateFormatter.dayMonth(deadline)}, ${AppDateFormatter.time24(deadline)}'
        : null;
    final meta = due == null
        ? activity
        : (activity == null ? due : '$due · $activity');
    final status = StatusBadge.task(task.status);

    return ActivityCard(
      leading: _leading(),
      title: task.title,
      subtitle: subtitle,
      trailing: status,
      meta: meta,
      semanticLabel: '${task.title}, $assignee, ${status.label}',
      onTap: () =>
          showTaskPreviewSheet(context, task: task, directory: directory),
    );
  }
}
