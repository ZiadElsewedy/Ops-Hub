import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/responsive_card_grid.dart';
import 'package:drop/core/widgets/app_motion.dart';
import 'package:drop/core/widgets/app_snackbar.dart';
import 'package:drop/core/widgets/branch_avatar.dart';
import 'package:drop/core/widgets/list_skeleton.dart';
import 'package:drop/core/widgets/stat_strip.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/operations/presentation/pages/branch_operations_screen.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/domain/task_feed.dart';
import 'package:drop/features/task/domain/task_outcomes.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/task/presentation/cubit/task_state.dart';
import 'package:drop/features/task/presentation/pages/filtered_tasks_screen.dart';
import 'package:drop/features/task/presentation/widgets/task_empty_state.dart';
import 'package:drop/features/task/presentation/widgets/task_template_sheets.dart';

/// Admin task home — a **branch-based overview** instead of a single flat list
/// of every task across the company (which doesn't scale past a few branches).
///
/// One scroll: a tappable stat row (tap any figure to see exactly those tasks),
/// then the branch grid with the operational vitals the admin needs to triage
/// at a glance — Active, Pending Review, Late, Completion — sorted so the
/// branches that need attention surface first. Tapping a branch drills into
/// that branch's task list (full create / assign / edit / review / delete).
class AdminTaskOverviewScreen extends StatefulWidget {
  const AdminTaskOverviewScreen({super.key});

  @override
  State<AdminTaskOverviewScreen> createState() =>
      _AdminTaskOverviewScreenState();
}

class _AdminTaskOverviewScreenState extends State<AdminTaskOverviewScreen> {
  late Future<List<BranchEntity>> _branchesFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _branchesFuture = Future.value(const []);
  }

  void _load() {
    final user = context.currentUser;
    if (user != null) {
      context.read<TaskCubit>().load(user);
      final future = context.read<TaskCubit>().branches();
      setState(() {
        _branchesFuture = future;
      });
    }
  }

  Future<void> _create() => startNewTaskFlow(
    context: context,
    cubit: context.read<TaskCubit>(),
    isAdmin: true,
    defaultBranchId: '',
  );

  void _manageTemplates() => showManageTemplatesSheet(
    context: context,
    cubit: context.read<TaskCubit>(),
    isAdmin: true,
    defaultBranchId: '',
  );

  /// Push the reusable filtered task list on the caller's navigator, so Back
  /// returns to the overview with its scroll position intact. [description]
  /// is the one-line "how does this count" explanation — the fix for the
  /// owner's "the late tasks — how does it count?" question (§C).
  void _openFiltered({
    required String title,
    required TaskFeedFilter filter,
    required String emptyMessage,
    required String description,
    String? emptyTitle,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FilteredTasksScreen(
          title: title,
          filter: filter,
          emptyTitle: emptyTitle ?? 'All clear',
          emptyMessage: emptyMessage,
          description: description,
          showDeadline: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: 'Task Management',
      actions: [
        IconButton(
          icon: const Icon(
            Icons.dashboard_customize_outlined,
            color: AppColors.textSecondary,
          ),
          tooltip: 'Templates',
          onPressed: _manageTemplates,
        ),
        IconButton(
          icon: const Icon(
            Icons.refresh_rounded,
            color: AppColors.textSecondary,
          ),
          tooltip: 'Refresh',
          onPressed: _load,
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'New Task',
          style: AppTypography.label.copyWith(color: AppColors.onAccent),
        ),
      ),
      body: BlocConsumer<TaskCubit, TaskState>(
        listener: (context, state) =>
            state.whenOrNull(error: (m) => AppSnackbar.error(context, m)),
        builder: (context, state) => state.maybeWhen(
          loading: () => const ListSkeleton(),
          loaded: (tasks, busy, directory, _, _) => _overview(tasks, busy),
          orElse: () => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _overview(List<TaskEntity> tasks, bool busy) {
    return FutureBuilder<List<BranchEntity>>(
      future: _branchesFuture,
      builder: (context, snap) {
        final branches = snap.data ?? const <BranchEntity>[];
        final rows = _sortBranches(_buildRows(branches, tasks));
        final company = _BranchMetrics.from(tasks);

        return Column(
          children: [
            if (busy) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _load(),
                child: rows.isEmpty
                    ? const TaskEmptyState(
                        message: 'No branches yet.\nCreate a branch, then add tasks.',
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.pagePadding,
                          AppSpacing.lg,
                          AppSpacing.pagePadding,
                          AppSpacing.xxxl * 2,
                        ),
                        children: [
                          _TaskStatRow(
                            metrics: company,
                            branches: rows.length,
                            onOpen: _openFiltered,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          ResponsiveCardGrid(
                            maxItemWidth: 520,
                            children: [
                              for (var i = 0; i < rows.length; i++)
                                EntranceFade(
                                  delay: staggerDelay(i),
                                  child: _BranchOverviewCard(
                                    row: rows[i],
                                    onTap: () => _openBranch(rows[i]),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openBranch(_BranchRow row) {
    // Drill into the operations cockpit (task→operations redesign) — the full
    // per-branch task list is reachable from there via "All tasks".
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BranchOperationsScreen(
          branchId: row.branchId,
          branchName: row.name,
        ),
      ),
    );
  }

  /// Groups tasks by branch and joins them to the branch directory. Branches with
  /// no tasks are still listed (the admin should see every branch); task rows
  /// whose branch is missing from the directory are bucketed as "Unknown branch"
  /// so legacy/orphaned tasks remain visible and actionable. Unsorted — see
  /// [_sortBranches].
  List<_BranchRow> _buildRows(
    List<BranchEntity> branches,
    List<TaskEntity> tasks,
  ) {
    final byBranch = <String, List<TaskEntity>>{};
    for (final t in tasks) {
      byBranch.putIfAbsent(t.branchId ?? '', () => []).add(t);
    }

    final rows = <_BranchRow>[
      for (final b in branches)
        _BranchRow(
          branchId: b.id,
          name: b.name,
          location: b.location,
          metrics: _BranchMetrics.from(byBranch[b.id] ?? const []),
          coverUrl: b.coverUrl,
          logoUrl: b.logoUrl,
        ),
    ];

    // Surface any branch ids that have tasks but no matching branch doc.
    final known = branches.map((b) => b.id).toSet();
    for (final entry in byBranch.entries) {
      if (entry.key.isEmpty || known.contains(entry.key)) continue;
      rows.add(
        _BranchRow(
          branchId: entry.key,
          name: 'Unknown branch',
          location: null,
          metrics: _BranchMetrics.from(entry.value),
        ),
      );
    }
    return rows;
  }
}

/// Orders branches so the ones that need attention (overdue, then pending
/// review) surface first; falls back to name so the order is stable.
List<_BranchRow> _sortBranches(List<_BranchRow> rows) {
  final sorted = [...rows];
  sorted.sort((a, b) {
    final attn = (b.metrics.needsAttention ? 1 : 0).compareTo(
      a.metrics.needsAttention ? 1 : 0,
    );
    if (attn != 0) return attn;
    final byOverdue = b.metrics.overdue.compareTo(a.metrics.overdue);
    if (byOverdue != 0) return byOverdue;
    final byReview = b.metrics.pendingReview.compareTo(a.metrics.pendingReview);
    if (byReview != 0) return byReview;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return sorted;
}

/// One branch's row in the overview: identity + computed [metrics].
class _BranchRow {
  const _BranchRow({
    required this.branchId,
    required this.name,
    required this.location,
    required this.metrics,
    this.coverUrl,
    this.logoUrl,
  });
  final String branchId;
  final String name;
  final String? location;
  final _BranchMetrics metrics;

  /// Branch identity media (§8b) — when [coverUrl] is set the card leads with the
  /// branch's cover photo. Null on synthetic "Unknown branch" rows.
  final String? coverUrl;
  final String? logoUrl;
}

/// Operational vitals for a set of tasks (one branch, or the whole company).
class _BranchMetrics {
  const _BranchMetrics({
    required this.total,
    required this.active,
    required this.pendingReview,
    required this.overdue,
    required this.approved,
    required this.outcomes,
  });

  /// Open work in progress (pending / started / completed / rejected — i.e. not
  /// yet approved and not currently awaiting review).
  final int active;

  /// Submitted and waiting for a manager/admin decision.
  final int pendingReview;

  /// Past their deadline and not yet done.
  final int overdue;

  /// Approved (closed) tasks.
  final int approved;

  /// Every task that counts toward this branch's record. **Cancelled work is
  /// not in here at all** — by decision it never happened, so it may not sit on
  /// either side of the completion rate (Automated Tasks spec §8).
  final int total;

  /// The four-way classification (§8) — the single source for the headline KPI,
  /// the Missed failure signal, cancellation-by-reason, and timeliness.
  final TaskOutcomes outcomes;

  /// **The headline KPI: Approved ÷ (Approved + Missed)** (§10.1), as a 0–1
  /// fraction, or null until something has actually closed. Cancelled is
  /// excluded from both sides, which is what makes the figure ungameable — a
  /// manager cannot improve it by cancelling work they expect to fail.
  ///
  /// This is a *reliability* measure over decided work, **not** progress
  /// through the backlog; `approved` / [total] is the progress framing and the
  /// two must not be conflated in copy.
  double? get completionRate {
    final pct = outcomes.completionRatePct;
    return pct == null ? null : pct / 100;
  }

  bool get needsAttention => overdue > 0 || pendingReview > 0;

  factory _BranchMetrics.from(Iterable<TaskEntity> tasks) {
    var total = 0, active = 0, pendingReview = 0, overdue = 0, approved = 0;
    for (final t in tasks) {
      // A cancelled task is excluded from the numerator, the denominator, and
      // the overdue count — cancellation must never be able to flatter (or
      // damage) a branch's numbers. Counted nowhere is the whole point.
      if (t.status == TaskStatus.cancelled) continue;
      total++;
      switch (t.status) {
        case TaskStatus.waitingReview:
          pendingReview++;
        case TaskStatus.approved:
          approved++;
        case TaskStatus.pending ||
            TaskStatus.started ||
            TaskStatus.completed ||
            TaskStatus.rejected:
          active++;
        case TaskStatus.missed:
          // Closed by the recurring-task deadline sweep. It is retained in the
          // total, but is neither active work nor an overdue task.
          break;
        case TaskStatus.cancelled:
          break; // unreachable — skipped above.
      }
      if (_overdue(t)) overdue++;
    }
    return _BranchMetrics(
      total: total,
      active: active,
      pendingReview: pendingReview,
      overdue: overdue,
      approved: approved,
      // Derived over the FULL list (cancelled included), because the by-reason
      // breakdown needs the cancellations the loop above deliberately skips.
      outcomes: taskOutcomes(tasks),
    );
  }

  static bool _overdue(TaskEntity t) {
    final d = t.deadline;
    if (d == null) return false;
    final done =
        t.status.isTerminal ||
        t.status == TaskStatus.completed ||
        t.status == TaskStatus.waitingReview;
    return !done && d.isBefore(DateTime.now());
  }
}

/// The company-wide stat row at the top of the overview. One calm surface —
/// every task-typed figure is a real tap target that drills into exactly those
/// tasks (Active, In review, Late, Missed, Cancelled, Done); Branches and
/// Complete are context, not lists, so they stay inert.
class _TaskStatRow extends StatelessWidget {
  const _TaskStatRow({
    required this.metrics,
    required this.branches,
    required this.onOpen,
  });

  final _BranchMetrics metrics;
  final int branches;
  final void Function({
    required String title,
    required TaskFeedFilter filter,
    required String emptyMessage,
    required String description,
    String? emptyTitle,
  })
  onOpen;

  @override
  Widget build(BuildContext context) {
    final pct = metrics.completionRate;
    final outcomes = metrics.outcomes;
    return StatStrip(
      stats: [
        Stat(label: 'Branches', value: '$branches'),
        Stat(
          label: 'Active',
          count: metrics.active,
          onTap: () => onOpen(
            title: 'Active',
            filter: const TaskFeedFilter(
              statuses: {
                TaskStatus.pending,
                TaskStatus.started,
                TaskStatus.completed,
                TaskStatus.rejected,
              },
            ),
            description:
                'Open work — not started, in progress, marked done, or sent '
                'back for rework.',
            emptyMessage:
                'No active tasks — everything is either done or waiting on review.',
          ),
        ),
        Stat(
          label: 'In review',
          count: metrics.pendingReview,
          onTap: () => onOpen(
            title: 'In review',
            filter: const TaskFeedFilter(status: TaskStatus.waitingReview),
            description:
                'Submitted by an employee, waiting for a manager or admin to '
                'approve or reject it.',
            emptyMessage: 'Nothing is waiting on a decision right now.',
          ),
        ),
        Stat(
          label: 'Late',
          count: metrics.overdue,
          tone: metrics.overdue > 0 ? AppColors.error : null,
          onTap: () => onOpen(
            title: 'Late',
            filter: const TaskFeedFilter(preset: FeedPreset.overdue),
            // The question the owner actually asked ("how does it count —
            // today's tasks? the last days?"). Verified against the code, not
            // assumed: active work only (pending/started/rejected), no time
            // window at all — a task 3 weeks overdue still counts, every day,
            // until it's closed. Once finished it drops out of Late and
            // becomes "finished late" on the task itself (see the task card).
            description:
                'Active work past its deadline — counted every day until '
                "it's closed, however old. Work that finished late shows on "
                'the task itself, not here.',
            emptyMessage: 'Nothing is running past its deadline.',
          ),
        ),
        // Hidden at zero so a clean estate stays calm — same rule the old
        // outcome-breakdown panel followed for Missed, now honoured here.
        if (outcomes.missed > 0)
          Stat(
            label: 'Missed',
            count: outcomes.missed,
            tone: AppColors.error,
            onTap: () => onOpen(
              title: 'Missed',
              filter: const TaskFeedFilter(
                status: TaskStatus.missed,
                activeWindowOnly: false,
              ),
              description:
                  "Closed automatically when a shift's deadline passed with "
                  "the work unfinished. Nobody decided this — it's a record "
                  "of work that didn't happen.",
              emptyTitle: 'No missed tasks',
              emptyMessage: 'Nothing has run past its deadline unclosed.',
            ),
          ),
        if (outcomes.cancelled > 0)
          Stat(
            label: 'Cancelled',
            count: outcomes.cancelled,
            // No `tone` — stays the default monochrome white. Cancelled must
            // never wear Missed's error-red and the two must never be summed
            // anywhere (Automated Tasks spec §8, owner-signed hard invariant).
            onTap: () => onOpen(
              title: 'Cancelled',
              filter: const TaskFeedFilter(
                status: TaskStatus.cancelled,
                activeWindowOnly: false,
              ),
              description:
                  'Work a manager or admin decided would not be done — a '
                  'decision, not a failure. Never counted as Missed.',
              emptyMessage: 'Nothing has been cancelled.',
            ),
          ),
        Stat(
          label: 'Done',
          count: metrics.approved,
          onTap: () => onOpen(
            title: 'Done',
            filter: const TaskFeedFilter(
              status: TaskStatus.approved,
              activeWindowOnly: false,
            ),
            description:
                'Approved and closed. Includes work that finished after its '
                'deadline — see each task for lateness.',
            emptyMessage: 'Nothing approved yet.',
          ),
        ),
        Stat(
          label: 'Complete',
          value: pct == null ? '—' : '${(pct * 100).round()}%',
        ),
      ],
    );
  }
}

/// A single branch card in the admin overview — the metric row + caption carry
/// open/overdue work and the headline completion rate.
class _BranchOverviewCard extends StatelessWidget {
  const _BranchOverviewCard({required this.row, required this.onTap});
  final _BranchRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = row.metrics;
    final pct = m.completionRate;
    final hasCover = (row.coverUrl ?? '').isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: AppRadius.cardAll,
          border: Border.all(
            color: m.needsAttention
                ? AppColors.textTertiary
                : AppColors.darkBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Identity: the branch cover photo when one is uploaded (§8b),
            // otherwise the plain text header. Metrics always sit below, on the
            // dark surface, so they stay legible regardless of the photo.
            if (hasCover)
              _CoverHeader(row: row)
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                child: _plainHeader(m),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, AppSpacing.lg, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _Metric(value: '${m.active}', label: 'Active'),
                      _Metric(
                        value: '${m.pendingReview}',
                        label: 'Pending review',
                      ),
                      _Metric(
                        value: '${m.overdue}',
                        label: 'Late',
                        alert: m.overdue > 0,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    _caption(m, pct),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (pct != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 5,
                        backgroundColor: AppColors.darkSurfaceElevated,
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Supporting line under the metrics — the headline **completion rate**:
  /// `Approved ÷ (Approved + Missed)` over **closed** work only (how reliably
  /// the branch delivers what it takes on). A branch with everything still open
  /// has no rate yet, which is why that case reads "Nothing closed yet" rather
  /// than a misleading percentage.
  String _caption(_BranchMetrics m, double? pct) {
    if (m.total == 0 && m.outcomes.cancelled == 0) return 'No tasks yet';
    if (pct == null) return 'Nothing closed yet';
    return 'Completion ${(pct * 100).round()}% of ${m.outcomes.scored} closed';
  }

  /// The text-only identity header used when a branch has no cover photo.
  Widget _plainHeader(_BranchMetrics m) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.name,
                style: AppTypography.label.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if ((row.location ?? '').isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(row.location!, style: AppTypography.caption),
              ],
            ],
          ),
        ),
        if (m.needsAttention)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _AttentionPill(
              overdue: m.overdue,
              pendingReview: m.pendingReview,
            ),
          ),
        const Icon(
          Icons.chevron_right_rounded,
          size: 20,
          color: AppColors.textTertiary,
        ),
      ],
    );
  }
}

/// The branch **cover** photo as a card header — the branch's uploaded cover
/// (dark scrim for legibility) with its logo + name + location overlaid, the
/// attention pill in the corner, and a chevron affordance. Mirrors the task
/// details branch banner so a branch reads consistently across surfaces.
class _CoverHeader extends StatelessWidget {
  const _CoverHeader({required this.row});
  final _BranchRow row;

  @override
  Widget build(BuildContext context) {
    final m = row.metrics;
    return AspectRatio(
      aspectRatio: 16 / 7,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            row.coverUrl!,
            fit: BoxFit.cover,
            cacheWidth: 1000,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: AppColors.darkSurfaceElevated),
          ),
          // Dark scrim, stronger at the bottom where the label sits.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x33000000), Color(0xE6000000)],
              ),
            ),
          ),
          if (m.needsAttention)
            Positioned(
              top: AppSpacing.sm,
              right: AppSpacing.sm,
              child: _AttentionPill(
                overdue: m.overdue,
                pendingReview: m.pendingReview,
              ),
            ),
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                BranchAvatar(
                  logoUrl: row.logoUrl,
                  name: row.name,
                  size: 36,
                  radius: 10,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.name,
                        style: AppTypography.label.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if ((row.location ?? '').isNotEmpty)
                        Text(
                          row.location!,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textPrimary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A small "needs attention" pill summarising why (overdue beats review).
class _AttentionPill extends StatelessWidget {
  const _AttentionPill({required this.overdue, required this.pendingReview});
  final int overdue;
  final int pendingReview;

  @override
  Widget build(BuildContext context) {
    final isOverdue = overdue > 0;
    final label = isOverdue ? '$overdue late' : '$pendingReview to review';
    final color = isOverdue ? AppColors.error : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOverdue
                ? Icons.error_outline_rounded
                : Icons.hourglass_empty_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label, this.alert = false});
  final String value;
  final String label;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppTypography.h3.copyWith(
              fontSize: 22,
              color: alert ? AppColors.error : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.caption),
        ],
      ),
    );
  }
}
