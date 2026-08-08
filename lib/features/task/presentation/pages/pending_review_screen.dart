import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/animated_count.dart';
import 'package:drop/core/widgets/app_empty_state.dart';
import 'package:drop/core/widgets/app_motion.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/core/widgets/list_skeleton.dart';
import 'package:drop/core/widgets/live_list_item.dart';
import 'package:drop/core/widgets/responsive_card_grid.dart';
import 'package:drop/core/widgets/user_avatar.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/domain/work_types/task_work_x.dart';
import 'package:drop/features/task/domain/work_types/work_review.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/task/presentation/cubit/task_state.dart';
import 'package:drop/features/task/presentation/widgets/manager_task_card.dart';

/// The admin **Pending Review** flow (refactor §1).
///
/// An admin often spans multiple branches and employees, so jumping straight
/// into a single task review is wrong. Instead this is a guided drill-down:
///
/// ```
/// Pending Review Summary  →  Branch  →  Employee  →  Task review
/// ```
///
/// It reads the app-wide [TaskCubit] all-branches stream (already live for an
/// admin), filters to `waitingReview`, and groups by branch then assignee. The
/// leaf reuses [ManagerTaskCard] (its "Review" action opens the existing review
/// surface). Strictly monochrome — no new cubit, schema, or data layer.
///
/// **Single-choice levels collapse.** The drill-down earns its keep only when a
/// level offers a real choice. A level with exactly one option — one branch with
/// pending work, or one employee inside it — is skipped automatically, on the
/// way in *and* on the way back, so the common "one task, one branch, one
/// person" case lands straight on the task instead of costing three empty taps.
/// The full drill-down is unchanged the moment a level offers more than one row.
class PendingReviewScreen extends StatefulWidget {
  const PendingReviewScreen({super.key});

  @override
  State<PendingReviewScreen> createState() => _PendingReviewScreenState();
}

class _PendingReviewScreenState extends State<PendingReviewScreen> {
  String? _branchId; // selected branch (level 1+)
  String? _employeeId; // selected employee (level 2)

  // Whether the currently-shown level had only one option and was therefore
  // auto-descended past. Recomputed every build (below) and read by [_back] /
  // `canPop`, so an auto-skipped level is never a stop on the way back either.
  bool _singleBranch = false;
  bool _singleEmpInBranch = false;

  /// Review-task ids already seen this session — so a fresh arrival (an id not
  /// seen before, after the first load) can be highlighted, while existing rows
  /// stay calm. Populated during build (read-only effect; no setState).
  final Set<String> _knownTaskIds = {};

  @override
  void initState() {
    super.initState();
    // The cubit is app-wide and already streaming for an admin; load() is
    // idempotent, so this is a safe no-op that also covers a cold entry.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.currentUser;
      if (user != null) context.read<TaskCubit>().load(user);
    });
  }

  /// Drill up one **navigable** level; pop the route otherwise. A level that was
  /// auto-descended (its only option) is not a stop — clearing an explicit
  /// selection above an auto level, or having none, pops the route.
  void _back() {
    if (_employeeId != null && !_singleEmpInBranch) {
      setState(() => _employeeId = null);
    } else if (_branchId != null && !_singleBranch) {
      setState(() => _branchId = null);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  /// True only while an explicit, non-auto selection can be stepped back to.
  bool get _canGoBackInternally =>
      (_employeeId != null && !_singleEmpInBranch) ||
      (_branchId != null && !_singleBranch);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TaskCubit, TaskState>(
      builder: (context, state) {
        final cubit = context.read<TaskCubit>();
        final tasks = state.maybeWhen(
          loaded: (t, _, _, _, _) => t,
          orElse: () => const <TaskEntity>[],
        );
        final isLoading = state.maybeWhen(loading: () => true, orElse: () => false);

        final reviewTasks = [
          for (final t in tasks)
            if (t.status == TaskStatus.waitingReview) t,
        ];
        final byBranch = <String, List<TaskEntity>>{};
        for (final t in reviewTasks) {
          byBranch.putIfAbsent(t.branchId ?? '', () => []).add(t);
        }

        // Flag genuinely-new arrivals (an unseen id, but never on the first load
        // — otherwise every row would highlight at once). Update the seen-set
        // after, as a read-only build effect (the next emit sees them as known).
        final isFirstLoad = _knownTaskIds.isEmpty;
        final freshIds = <String>{
          for (final t in reviewTasks)
            if (!isFirstLoad && !_knownTaskIds.contains(t.id)) t.id,
        };
        _knownTaskIds.addAll(reviewTasks.map((t) => t.id));

        // ── Collapse single-choice levels ────────────────────────────
        // A branch level with one branch, or an employee level with one
        // employee, is not a choice — descend past it automatically. The
        // effective ids drive the view; the explicit `_branchId`/`_employeeId`
        // are honoured first so a real selection in a multi-row estate wins.
        _singleBranch = byBranch.length == 1;
        final effBranchId =
            _branchId ?? (_singleBranch ? byBranch.keys.first : null);

        final branchTasks =
            effBranchId == null ? const <TaskEntity>[] : byBranch[effBranchId]!;
        // Employees within the effective branch — only to detect a lone one.
        final empIds = <String>{
          for (final t in branchTasks)
            ...(t.assigneeIds.isEmpty ? const [''] : t.assigneeIds),
        };
        _singleEmpInBranch = effBranchId != null && empIds.length == 1;
        final effEmployeeId =
            _employeeId ?? (_singleEmpInBranch ? empIds.first : null);

        final atLeaf = effBranchId != null && effEmployeeId != null;
        final atEmployeePicker = effBranchId != null && effEmployeeId == null;

        final String levelTitle;
        final String levelSubtitle;
        if (atLeaf) {
          levelTitle = _empName(cubit, effEmployeeId);
          levelSubtitle = 'Tasks awaiting your review';
        } else if (atEmployeePicker) {
          levelTitle = cubit.branchNames[effBranchId] ?? 'Branch';
          levelSubtitle = 'Choose an employee to review';
        } else {
          levelTitle = 'Pending review';
          levelSubtitle = 'Review queue, grouped by branch then employee';
        }

        final Widget body;
        if (isLoading && reviewTasks.isEmpty) {
          body = const Padding(
            padding: EdgeInsets.all(AppSpacing.pagePadding),
            child: ListSkeleton(),
          );
        } else if (atLeaf) {
          body = _employeeLevel(cubit, branchTasks, effEmployeeId, freshIds);
        } else if (atEmployeePicker) {
          body = _branchLevel(cubit, branchTasks);
        } else {
          body = _summaryLevel(cubit, reviewTasks, byBranch);
        }

        return PopScope(
          canPop: !_canGoBackInternally,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _back();
          },
          child: AdaptiveScaffold(
            title: levelTitle,
            subtitle: levelSubtitle,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: AppColors.textPrimary),
              onPressed: _back,
            ),
            body: body,
          ),
        );
      },
    );
  }

  // ── Level 0: summary + branch breakdown ───────────────────────────
  Widget _summaryLevel(
    TaskCubit cubit,
    List<TaskEntity> reviewTasks,
    Map<String, List<TaskEntity>> byBranch,
  ) {
    if (reviewTasks.isEmpty) {
      return const Center(
        child: AppEmptyState(
          icon: Icons.check_circle_outline_rounded,
          title: 'All caught up',
          message: 'No tasks are waiting for review right now.',
        ),
      );
    }

    final branches = byBranch.keys.toList()
      ..sort((a, b) {
        final byCount = byBranch[b]!.length.compareTo(byBranch[a]!.length);
        if (byCount != 0) return byCount;
        return (cubit.branchNames[a] ?? a).compareTo(cubit.branchNames[b] ?? b);
      });

    return ListView(
      key: const PageStorageKey('pr-summary'),
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      children: [
        EntranceFade(child: _SummaryHeader(total: reviewTasks.length, branches: branches.length)),
        const SizedBox(height: AppSpacing.xl),
        Text('BY BRANCH',
            style: AppTypography.caption.copyWith(
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
              color: AppColors.textTertiary,
            )),
        const SizedBox(height: AppSpacing.md),
        for (var i = 0; i < branches.length; i++)
          // Keyed so a stream emit (counts changing) never replays the entrance;
          // only a newly-appearing branch row animates in.
          LiveListItem(
            key: ValueKey('b:${branches[i]}'),
            entranceDelay: Duration(milliseconds: i * 40),
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _DrillRow(
                icon: Icons.storefront_outlined,
                title: cubit.branchNames[branches[i]] ?? 'Unknown branch',
                count: byBranch[branches[i]]!.length,
                onTap: () => setState(() => _branchId = branches[i]),
              ),
            ),
          ),
      ],
    );
  }

  // ── Level 1: employees within a branch ────────────────────────────
  Widget _branchLevel(TaskCubit cubit, List<TaskEntity> branchTasks) {
    if (branchTasks.isEmpty) {
      return const Center(
        child: AppEmptyState(
          icon: Icons.check_circle_outline_rounded,
          title: 'All caught up',
          message: 'Nothing left to review in this branch.',
        ),
      );
    }

    final byEmp = <String, List<TaskEntity>>{};
    for (final t in branchTasks) {
      final ids = t.assigneeIds.isEmpty ? const [''] : t.assigneeIds;
      for (final id in ids) {
        byEmp.putIfAbsent(id, () => []).add(t);
      }
    }
    final emps = byEmp.keys.toList()
      ..sort((a, b) {
        final byCount = byEmp[b]!.length.compareTo(byEmp[a]!.length);
        if (byCount != 0) return byCount;
        return _empName(cubit, a).compareTo(_empName(cubit, b));
      });

    return ListView(
      key: const PageStorageKey('pr-branch'),
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      children: [
        Text('${branchTasks.length} waiting · select an employee',
            style: AppTypography.bodySmall),
        const SizedBox(height: AppSpacing.md),
        for (var i = 0; i < emps.length; i++)
          LiveListItem(
            key: ValueKey('e:${emps[i]}'),
            entranceDelay: Duration(milliseconds: i * 40),
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _DrillRow(
                avatarName: _empName(cubit, emps[i]),
                title: _empName(cubit, emps[i]),
                count: byEmp[emps[i]]!.length,
                onTap: () => setState(() => _employeeId = emps[i]),
              ),
            ),
          ),
      ],
    );
  }

  // ── Level 2: that employee's tasks → review ───────────────────────
  // This is the actual live task list: cards are keyed by task id so a stream
  // emit never re-animates the rows on screen (scroll position is preserved),
  // and a genuinely-new submission ([freshIds]) slides in with a brief highlight.
  Widget _employeeLevel(
    TaskCubit cubit,
    List<TaskEntity> branchTasks,
    String employeeId,
    Set<String> freshIds,
  ) {
    final mine = [
      for (final t in branchTasks)
        if (employeeId.isEmpty
            ? t.assigneeIds.isEmpty
            : t.assigneeIds.contains(employeeId)) t,
    ];
    if (mine.isEmpty) {
      return const Center(
        child: AppEmptyState(
          icon: Icons.check_circle_outline_rounded,
          title: 'All caught up',
          message: 'No more tasks waiting from this employee.',
        ),
      );
    }
    // The "manager fast-path": work the type says already checks out (a
    // reconciled count, an inspection with no failures, a within-budget errand)
    // floats to the top for one-tap approval. A stable partition preserves the
    // existing stream order within each group.
    bool isFast(TaskEntity t) =>
        t.workDefinition.reviewDisposition(t.workContext) ==
        ReviewDisposition.fastTrack;
    final ordered = [
      for (final t in mine) if (isFast(t)) t,
      for (final t in mine) if (!isFast(t)) t,
    ];
    final fastCount = mine.where(isFast).length;
    return ListView(
      key: const PageStorageKey('pr-leaf'),
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      children: [
        if (fastCount > 0) ...[
          _FastTrackNote(count: fastCount),
          const SizedBox(height: AppSpacing.md),
        ],
        ResponsiveCardGrid(
          runSpacing: 0, // ManagerTaskCard (via TaskCard) carries its own margin
          maxItemWidth: 480,
          children: [
            for (var i = 0; i < ordered.length; i++)
              LiveListItem(
                key: ValueKey('t:${ordered[i].id}'),
                isNew: freshIds.contains(ordered[i].id),
                entranceDelay: Duration(milliseconds: i * 40),
                child: ManagerTaskCard(
                  task: ordered[i],
                  directory: cubit.directory,
                  isAdmin: true,
                  defaultBranchId: ordered[i].branchId ?? '',
                ),
              ),
          ],
        ),
      ],
    );
  }

  String _empName(TaskCubit cubit, String id) {
    if (id.isEmpty) return 'Unassigned';
    return cubit.directory[id]?.displayName ?? 'Unknown member';
  }
}

// ── Premium monochrome summary header (animated count) ──────────────
class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.total, required this.branches});
  final int total;
  final int branches;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      highlight: true,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.darkSurfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: const Icon(Icons.rate_review_rounded,
                size: 26, color: AppColors.textPrimary),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedCount(
                  value: total,
                  duration: const Duration(milliseconds: 700),
                  style: AppTypography.display.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                    letterSpacing: -1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  total == 1 ? 'task waiting review' : 'tasks waiting review',
                  style: AppTypography.body
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  'Across ${branches == 1 ? '1 branch' : '$branches branches'}',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── A tappable drill row (branch or employee) ───────────────────────
class _DrillRow extends StatelessWidget {
  const _DrillRow({
    required this.title,
    required this.count,
    required this.onTap,
    this.icon,
    this.avatarName,
  });

  final String title;
  final int count;
  final VoidCallback onTap;
  final IconData? icon;
  final String? avatarName;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          if (avatarName != null)
            UserAvatar(name: avatarName, size: 38)
          else
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.darkSurfaceElevated,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Icon(icon, size: 19, color: AppColors.textSecondary),
            ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              title,
              style: AppTypography.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.darkSurfaceElevated,
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: AnimatedCount(
              value: count,
              duration: const Duration(milliseconds: 450),
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(Icons.chevron_right_rounded,
              size: 20, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}

// ── Fast-path note: reconciled / passed / within-budget work sorts first ──
class _FastTrackNote extends StatelessWidget {
  const _FastTrackNote({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded,
              size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              count == 1
                  ? '1 task is ready to fast-track — it already checks out.'
                  : '$count tasks are ready to fast-track — they already check out.',
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
