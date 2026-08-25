import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opshub/core/routes/app_page_route.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/widgets/app_dialog.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/presentation/cubit/task_cubit.dart';
import 'package:opshub/features/task/presentation/pages/task_details_screen.dart';
import 'package:opshub/features/task/presentation/widgets/task_action_sheets.dart';
import 'package:opshub/features/task/presentation/widgets/task_card.dart';

/// A [TaskCard] with the manager/admin action set (Review when awaiting review,
/// Assign, Edit, Delete) wired to the [TaskCubit] in context; tapping the card
/// opens the full task details.
///
/// Shared by the manager's flat branch list and the admin's per-branch
/// drill-down so both render identical cards from one source of truth.
class ManagerTaskCard extends StatelessWidget {
  const ManagerTaskCard({
    super.key,
    required this.task,
    required this.directory,
    required this.isAdmin,
    required this.defaultBranchId,
  });

  final TaskEntity task;
  final Map<String, UserEntity> directory;
  final bool isAdmin;
  final String defaultBranchId;

  Future<void> _confirmDelete(BuildContext context) async {
    final cubit = context.read<TaskCubit>();
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete task?',
      message: '"${task.title}" will be permanently removed.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (confirmed && context.mounted) cubit.deleteTask(task.id);
  }

  Future<void> _confirmReopen(BuildContext context) async {
    final cubit = context.read<TaskCubit>();
    final confirmed = await showConfirmDialog(
      context,
      title: 'Reopen task?',
      message:
          '"${task.title}" will move back into the workflow so it can be edited. The approval will be cleared.',
      confirmLabel: 'Reopen',
    );
    if (confirmed && context.mounted) cubit.reopenTask(task);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TaskCubit>();
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        appPageRoute<void>(
          builder: (_) => TaskDetailsScreen(task: task, directory: directory),
        ),
      ),
      child: Builder(
        builder: (context) {
          // A terminal task is a locked record: no Assign / Edit / Delete. Only
          // an approved task has the Reopen transition, available to any
          // manager/admin (this card is never shown to employees); a missed task
          // stays closed.
          final locked = task.status.isTerminal;
          final canReopen = task.status == TaskStatus.approved;
          return TaskCard(
            task: task,
            directory: directory,
            branchName: cubit.branchNames[task.branchId ?? ''],
            // Branch identity (logo) from the app-wide branch directory (§8b) so
            // the card chip shows the real branch logo when one is uploaded.
            branchLogoUrl: context
                .watch<BranchCubit>()
                .branchById(task.branchId)
                ?.logoUrl,
            onAssigneesTap: locked
                ? null
                : () => showAssignSheet(
                    context: context,
                    cubit: cubit,
                    task: task,
                  ),
            actions: [
              if (task.status == TaskStatus.waitingReview)
                TaskActionButton(
                  label: 'Review',
                  icon: Icons.rate_review_outlined,
                  onPressed: () => showReviewSheet(
                    context: context,
                    cubit: cubit,
                    task: task,
                  ),
                ),
              if (locked) ...[
                if (canReopen)
                  TaskActionButton(
                    label: 'Reopen',
                    icon: Icons.lock_open_rounded,
                    onPressed: () => _confirmReopen(context),
                  ),
              ] else ...[
                TaskActionButton(
                  label: 'Assign',
                  icon: Icons.person_add_alt_1_outlined,
                  onPressed: () => showAssignSheet(
                    context: context,
                    cubit: cubit,
                    task: task,
                  ),
                ),
                TaskActionButton(
                  label: 'Edit',
                  icon: Icons.edit_outlined,
                  onPressed: () => showTaskFormSheet(
                    context: context,
                    cubit: cubit,
                    existing: task,
                    isAdmin: isAdmin,
                    defaultBranchId: defaultBranchId,
                  ),
                ),
                TaskActionButton(
                  label: 'Delete',
                  icon: Icons.delete_outline_rounded,
                  color: AppColors.error,
                  onPressed: () => _confirmDelete(context),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
