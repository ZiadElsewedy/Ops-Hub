import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/responsive/breakpoints.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/core/widgets/user_avatar.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/domain/task_feed.dart';
import 'package:drop/features/task/domain/task_outcomes.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/task/presentation/cubit/task_state.dart';
import 'package:drop/features/task/presentation/widgets/task_browser.dart';

/// Employee operations drill-down: records stay compact and searchable rather
/// than repeating manager-sized action cards for closed work.
class EmployeeDetailScreen extends StatelessWidget {
  const EmployeeDetailScreen({
    super.key,
    required this.employee,
    required this.isAdmin,
    required this.defaultBranchId,
  });
  final UserEntity employee;
  final bool isAdmin;
  final String defaultBranchId;

  @override
  Widget build(BuildContext context) {
    final name = employee.displayName?.isNotEmpty == true
        ? employee.displayName!
        : employee.email;
    return AdaptiveScaffold(
      title: name,
      titleWidget: Row(
        children: [
          UserAvatar.fromUser(employee, size: context.isDesktop ? 46 : 34),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: context.isDesktop
                      ? AppTypography.h1
                      : AppTypography.h3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _capitalize(employee.role.value),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // Vertical only: the browser owns the horizontal rhythm below, so only the
      // summary card carries the page margin itself.
      body: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.lg),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pagePadding,
              ),
              child: BlocBuilder<TaskCubit, TaskState>(
                builder: (context, state) => state.maybeWhen(
                  loaded: (tasks, _, _, _, _) => _Summary(
                    tasks
                        .where((t) => t.assigneeIds.contains(employee.uid))
                        .toList(),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: TaskBrowser(
                initialFilter: TaskFeedFilter(
                  assigneeUid: employee.uid,
                  activeWindowOnly: false,
                ),
                emptyTitle: 'No tasks for $name',
                emptyMessage: 'This employee has no tasks matching this view.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

class _Summary extends StatelessWidget {
  const _Summary(this.tasks);
  final List<TaskEntity> tasks;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final outcomes = taskOutcomes(tasks);
    final active = tasks.where((t) => t.status.isActive).length;
    final review = tasks
        .where((t) => t.status == TaskStatus.waitingReview)
        .length;
    final late = tasks.where((t) => isTaskOverdue(t, now)).length;
    final done = outcomes.approved;
    final rate = outcomes.completionRatePct;
    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Four cells, not five: a fifth `Expanded` cell on a 390pt phone left
          // ~70pt per column, which ellipsised the reliability basis into
          // nonsense. The rate gets its own full-width line where its basis can
          // actually be read — the figure is meaningless without it.
          Row(
            children: [
              _fact('$active', 'Active'),
              _fact('$late', 'Late', alert: late > 0),
              _fact('$review', 'In review'),
              _fact('$done', 'Done'),
            ],
          ),
          if (rate != null) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1, thickness: 1, color: AppColors.darkBorder),
            const SizedBox(height: AppSpacing.md),
            // The figure leads and the basis supports it, on one baseline —
            // a bare percentage is not interpretable, and the basis printed at
            // the same weight as the number made neither readable.
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$rate%',
                  style: AppTypography.h3.copyWith(fontSize: 20),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'reliability · approved ÷ (approved + missed)',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// One figure cell. The number is the thing being read, so it carries the
  /// weight; the word under it is support, not a peer.
  Widget _fact(String value, String label, {bool alert = false}) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AppTypography.h3.copyWith(
            fontSize: 24,
            height: 1.1,
            color: alert ? AppColors.error : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: AppTypography.caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}
