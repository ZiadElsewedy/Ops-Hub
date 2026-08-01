import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/drop_empty_state.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/domain/task_feed.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/task/presentation/cubit/task_state.dart';
import 'package:drop/features/task/presentation/widgets/task_activity_card.dart';

/// A reusable **filtered task list** the dashboard's Needs-Attention tiles push
/// into (Overdue · Unassigned · Rejected · …). It renders the live task stream
/// through a [TaskFeedFilter] as clean [TaskActivityCard]s — the same preview →
/// full-details flow as the dashboard — pushed on the caller's navigator so
/// **Back returns to the dashboard exactly where it was** (scroll + state kept).
///
/// One small screen instead of a bespoke page per signal: pass a [title] and the
/// [filter] (a preset, or a status/branch/assignee narrowing) and it derives the
/// list from `applyFeed` (so its ordering + membership match the feed engine).
class FilteredTasksScreen extends StatelessWidget {
  const FilteredTasksScreen({
    super.key,
    required this.title,
    required this.filter,
    this.emptyMessage = 'Nothing needs attention here right now.',
    this.emptyTitle = 'All clear',
    this.showDeadline = false,
    this.description,
  });

  final String title;
  final TaskFeedFilter filter;
  final String emptyMessage;

  /// A one-line explanation of what this list counts and why, in the same
  /// spot `OperationsMetricScreen.description` puts it — the fix for "how
  /// does Late count?" being a question anyone had to ask at all. Null
  /// (unset, the default) renders nothing, so every existing caller that
  /// doesn't pass one is unchanged.
  final String? description;

  /// Defaults to the generic "All clear" — honest for a triage queue that has
  /// genuinely nothing outstanding. A caller drilling into a **closed** record
  /// set (Missed, Cancelled, Done) should override this: an empty Missed page
  /// titled "All clear" reads as if nothing was ever missed, which is a
  /// different (and false) claim.
  final String emptyTitle;

  /// Surfaces each task's deadline in the meta line — see
  /// [TaskActivityCard.showDeadline].
  final bool showDeadline;

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: title,
      body: BlocBuilder<TaskCubit, TaskState>(
        builder: (context, state) {
          return state.maybeWhen(
            loaded: (tasks, busy, directory, isSubmitting, progress) {
              final branchNames = context.read<TaskCubit>().branchNames;
              final now = DateTime.now();
              final List<TaskEntity> list = applyFeed(
                tasks,
                filter,
                now,
                directory: directory,
                branchNames: branchNames,
              );
              final descriptionLine = description == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pagePadding,
                        AppSpacing.md,
                        AppSpacing.pagePadding,
                        0,
                      ),
                      child: Text(description!, style: AppTypography.body),
                    );

              if (list.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ?descriptionLine,
                    Expanded(
                      child: DropEmptyState(
                        title: emptyTitle,
                        message: emptyMessage,
                      ),
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ?descriptionLine,
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pagePadding,
                      AppSpacing.md,
                      AppSpacing.pagePadding,
                      0,
                    ),
                    child: Text(
                      '${list.length} ${list.length == 1 ? 'task' : 'tasks'}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pagePadding,
                        AppSpacing.sm,
                        AppSpacing.pagePadding,
                        AppSpacing.xxxl,
                      ),
                      itemCount: list.length,
                      itemBuilder: (context, i) => Padding(
                        key: ValueKey('filtered:${list[i].id}'),
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: TaskActivityCard(
                          task: list[i],
                          directory: directory,
                          branchName: branchNames[list[i].branchId],
                          showDeadline: showDeadline,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
            orElse: () =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        },
      ),
    );
  }
}
