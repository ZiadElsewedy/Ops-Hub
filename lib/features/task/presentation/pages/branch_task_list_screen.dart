import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/responsive/breakpoints.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/features/task/domain/task_feed.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/task/presentation/widgets/task_browser.dart';
import 'package:drop/features/task/presentation/widgets/task_template_sheets.dart';

/// The full task list for a single branch, with the manager/admin action set
/// (create / assign / edit / review / delete via [ManagerTaskCard]). Reads the
/// already-loaded [TaskCubit] stream and filters to [branchId] so it stays live
/// without a second query.
///
/// This is the **secondary** branch surface (reached via the Branch Operations
/// "All tasks" action and the admin branch overview drill) — the primary surface
/// is the operations cockpit. It also keeps **unassigned** tasks reachable, which
/// the employee-centric cockpit does not surface on its own.
class BranchTaskListScreen extends StatelessWidget {
  const BranchTaskListScreen({
    super.key,
    required this.branchId,
    required this.branchName,
    this.isAdmin = false,
  });

  final String branchId;
  final String branchName;
  final bool isAdmin;

  Future<void> _create(BuildContext context) => startNewTaskFlow(
    context: context,
    cubit: context.read<TaskCubit>(),
    // The branch is fixed in this context, so behave like a branch-scoped
    // form (no branch picker) regardless of role.
    isAdmin: false,
    defaultBranchId: branchId,
    templateBranchFilter: branchId,
  );

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: 'All tasks',
      subtitle: branchId.isEmpty
          ? 'Search every branch, task and assignee'
          : 'Every task in this branch, including unassigned',
      // A two-line lockup, because the mobile app bar shows the **title only**:
      // `"$branchName · All tasks"` truncated to "Drop The shop | Arkan · All
      // t…", losing the one word that says what the page is. The subject leads;
      // the scope sits under it, where it can ellipsize harmlessly.
      titleWidget: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'All tasks',
            style: context.isDesktop ? AppTypography.h1 : AppTypography.h3,
          ),
          Text(
            branchId.isEmpty ? 'Every branch' : branchName,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      // The list is what this page is for, so search leads it. The create
      // action moved out of the content column into the scaffold's own action
      // slot — as a full-width row above the field it read as the page's
      // subject, and it pushed the search bar off the first fold.
      floatingActionButton: branchId.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _create(context),
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.onAccent,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                'New Task',
                style: AppTypography.label.copyWith(color: AppColors.onAccent),
              ),
            ),
      // Vertical only: the browser owns the horizontal rhythm, so its rows can
      // extend past the page margin while their titles stay on it.
      body: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.lg),
        child: TaskBrowser(
          // Clears the extended FAB — 48pt of tail left it resting on the last
          // task in the list.
          bottomInset: AppSpacing.xxxl * 2,
          initialFilter: TaskFeedFilter(
            branchId: branchId.isEmpty ? null : branchId,
            activeWindowOnly: false,
          ),
          emptyTitle: branchId.isEmpty
              ? 'No tasks yet'
              : 'No tasks in this branch',
          emptyMessage: branchId.isEmpty
              ? 'Tasks created in any branch will be searchable here.'
              : 'This branch has no tasks matching this view.',
        ),
      ),
    );
  }
}
