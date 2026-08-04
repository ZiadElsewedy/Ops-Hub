import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/presentation/widgets/task_browser_groups.dart';
import 'package:drop/features/task/presentation/widgets/task_feed_row.dart';
import 'package:drop/features/task/presentation/widgets/task_preview_sheet.dart';

/// **The** way a list of tasks is drawn in DROP: date sections, then rows.
///
/// Extracted so the browser (branch list · employee drill-down) and every
/// metric drill-down (`FilteredTasksScreen`) cannot drift into two dialects of
/// the same list — one of them was still rendering stacked cards while the
/// other had moved to rows, which is exactly the "belongs to an older version"
/// feeling a consistency pass exists to remove.
class TaskSectionList extends StatelessWidget {
  const TaskSectionList({
    super.key,
    required this.tasks,
    required this.directory,
    required this.branchNames,
    this.showBranch = true,
    this.showAssignee = true,
    this.padding = const EdgeInsets.only(bottom: AppSpacing.xxxl),
    this.header,
  });

  final List<TaskEntity> tasks;
  final Map<String, UserEntity> directory;
  final Map<String, String> branchNames;
  final bool showBranch;
  final bool showAssignee;
  final EdgeInsetsGeometry padding;

  /// Optional content pinned above the first section, inside the same scroll.
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final groups = browserGroups(tasks, DateTime.now());
    return ListView(
      padding: padding,
      children: [
        ?header,
        for (final (i, group) in groups.indexed) ...[
          TaskSectionHeader(
            label: group.label,
            count: group.tasks.length,
            first: i == 0 && header == null,
          ),
          for (final (j, task) in group.tasks.indexed)
            TaskFeedRow(
              key: ValueKey('task-row:${task.id}'),
              task: task,
              directory: directory,
              branchName: branchNames[task.branchId],
              showBranch: showBranch,
              showAssignee: showAssignee,
              // The rule between rows belongs *between* rows. Drawing it under
              // the last one too put a hairline directly above the next
              // section's own rule — two lines, 8pt apart, meaning nothing.
              showDivider: j < group.tasks.length - 1,
              onTap: () => showTaskPreviewSheet(
                context,
                task: task,
                directory: directory,
              ),
            ),
        ],
      ],
    );
  }
}

/// A date section head: the label, a hairline carrying the eye across the gap,
/// then the count. The rule is what makes a header read as *structure* rather
/// than as another line of small grey text above the rows.
class TaskSectionHeader extends StatelessWidget {
  const TaskSectionHeader({
    super.key,
    required this.label,
    required this.count,
    this.first = false,
  });

  final String label;
  final int count;
  final bool first;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      top: first ? AppSpacing.sm : AppSpacing.xl,
      bottom: AppSpacing.sm,
    ),
    child: Row(
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        const Expanded(
          child: SizedBox(
            height: 1,
            child: ColoredBox(color: AppColors.darkBorder),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          '$count',
          style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
        ),
      ],
    ),
  );
}
