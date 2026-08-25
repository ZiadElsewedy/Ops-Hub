import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/core/extensions/context_extensions.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/adaptive_scaffold.dart';
import 'package:opshub/core/widgets/responsive_card_grid.dart';
import 'package:opshub/core/widgets/app_motion.dart';
import 'package:opshub/core/widgets/app_snackbar.dart';
import 'package:opshub/core/widgets/admin_section_header.dart';
import 'package:opshub/core/widgets/branch_avatar.dart';
import 'package:opshub/core/widgets/glass_container.dart';
import 'package:opshub/core/widgets/list_skeleton.dart';
import 'package:opshub/core/widgets/metric_tile.dart';
import 'package:opshub/features/branch/domain/entities/branch_entity.dart';
import 'package:opshub/features/operations/presentation/pages/branch_operations_screen.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/domain/task_feed.dart';
import 'package:opshub/features/task/domain/task_outcomes.dart';
import 'package:opshub/features/task/presentation/cubit/task_cubit.dart';
import 'package:opshub/features/task/presentation/cubit/task_state.dart';
import 'package:opshub/features/task/presentation/pages/filtered_tasks_screen.dart';
import 'package:opshub/features/task/presentation/pages/branch_task_list_screen.dart';
import 'package:opshub/features/task/presentation/widgets/task_empty_state.dart';
import 'package:opshub/features/task/presentation/widgets/task_template_sheets.dart';

/// Admin task home — a **branch-based overview** instead of a single flat list
/// of every task across the company (which doesn't scale past a few branches).
///
/// One scroll, ranked for the phone: three actionable `MetricTile` doors lead;
/// quiet record figures follow without competing; then a named branch grid,
/// sorted attention-first. This replaced an eight-cell `StatStrip` that filled
/// the first iPhone fold, treated inert context like urgent work, and made
/// tappable and inert cells look identical.
///
/// Branch cards keep their operational triple (Active · Pending review · Late)
/// and the app's single reliability figure — Approved ÷ (Approved + Missed).
/// Their cover is now a compact, strongly-scrimmed identity band rather than a
/// banner, so a real photo supports the branch name instead of overwhelming it.
/// Missed and Cancelled remain hidden at zero; Cancelled is neutral and never
/// joins Missed in a count or completion calculation.
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

  void _openTaskBrowser() => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => const BranchTaskListScreen(
        branchId: '',
        branchName: 'Company tasks',
        isAdmin: true,
      ),
    ),
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
            Icons.search_rounded,
            color: AppColors.textSecondary,
          ),
          tooltip: 'Search tasks',
          onPressed: _openTaskBrowser,
        ),
        IconButton(
          // "Saved checklist", not "customize dashboard" — the same glyph
          // (`kTemplatesIcon`) everywhere Templates appears (2026-08-01).
          icon: const Icon(kTemplatesIcon, color: AppColors.textSecondary),
          tooltip: 'Templates',
          onPressed: _manageTemplates,
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
                        message:
                            'No branches yet.\nCreate a branch, then add tasks.',
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
                            onOpen: _openFiltered,
                          ),
                          // `xl` between major sections — the same rhythm the
                          // branch cockpit uses.
                          const SizedBox(height: AppSpacing.xl),
                          // The company-wide list gets a **labelled** door
                          // here, not only the app bar's magnifier — an
                          // unlabelled glyph is a destination you have to
                          // already know about.
                          AdminSectionHeader(
                            title: 'Branches',
                            subtitle: 'Needs attention first',
                            actionLabel: 'All tasks',
                            onAction: _openTaskBrowser,
                          ),
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

/// The company header has two explicit tiers: the work to act on is a row of
/// doors, then the **record panel** — the reliability figure at headline scale
/// with its basis spelled out, over the Done · Missed · Cancelled record cells.
/// The record used to be an 11px caption strip, which printed the company's only
/// failure figure smaller than three zeros above it.
class _TaskStatRow extends StatelessWidget {
  const _TaskStatRow({required this.metrics, required this.onOpen});

  final _BranchMetrics metrics;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MetricTileRow(
          tiles: [
            MetricTile(
              label: 'Active',
              value: metrics.active,
              icon: Icons.inbox_rounded,
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
            MetricTile(
              label: 'In review',
              value: metrics.pendingReview,
              icon: Icons.rate_review_outlined,
              onTap: () => onOpen(
                title: 'In review',
                filter: const TaskFeedFilter(status: TaskStatus.waitingReview),
                description:
                    'Submitted by an employee, waiting for a manager or admin to '
                    'approve or reject it.',
                emptyMessage: 'Nothing is waiting on a decision right now.',
              ),
            ),
            MetricTile(
              label: 'Late',
              value: metrics.overdue,
              icon: Icons.event_busy_outlined,
              alert: metrics.overdue > 0,
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
            // **Missed is a door, not a footnote.** It was an 11px record line
            // under the panel, which is the wrong weight for the company's only
            // failure figure — and it sat two tiers below `Late`, which it is
            // routinely confused with. It stays hidden at zero (there is no
            // failure to report), never sums with Cancelled, and is the only
            // tile here allowed to wear the error tone.
            if (outcomes.missed > 0)
              MetricTile(
                label: 'Missed',
                value: outcomes.missed,
                // "Time ran out", distinct from Late's "deadline passed" —
                // the two are routinely confused, so they must not share a
                // glyph.
                icon: Icons.timer_off_outlined,
                alert: true,
                onTap: () => onOpen(
                  title: 'Missed',
                  filter: const TaskFeedFilter(
                    status: TaskStatus.missed,
                    activeWindowOnly: false,
                  ),
                  description:
                      "Closed automatically when a shift's deadline passed "
                      "with the work unfinished. Nobody decided this — it's a "
                      "record of work that didn't happen.",
                  emptyTitle: 'No missed tasks',
                  emptyMessage: 'Nothing has run past its deadline unclosed.',
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _TaskRecordPanel(
          completion: pct,
          cancelled: outcomes.cancelled,
          done: metrics.approved,
          onOpen: onOpen,
        ),
      ],
    );
  }
}

class _TaskRecordPanel extends StatelessWidget {
  const _TaskRecordPanel({
    required this.completion,
    required this.cancelled,
    required this.done,
    required this.onOpen,
  });

  final double? completion;
  final int cancelled;
  final int done;
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
    return GlassContainer(
      borderRadius: AppRadius.lgAll,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label:
                'Reliability ${completion == null ? 'not available' : '${(completion! * 100).round()} percent'}',
            child: InkWell(
              onTap: () => onOpen(
                title: 'Decided work',
                filter: const TaskFeedFilter(
                  statuses: {TaskStatus.approved, TaskStatus.missed},
                  activeWindowOnly: false,
                ),
                emptyMessage: 'No approved or missed tasks yet.',
                description:
                    'Reliability is Approved ÷ (Approved + Missed). Cancelled work is excluded.',
                emptyTitle: 'No decided work',
              ),
              // The figure dominates; its basis sits directly under it as
              // support, at a brightness step below.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    completion == null
                        ? '—'
                        : '${(completion! * 100).round()}%',
                    style: AppTypography.h1.copyWith(
                      fontSize: 32,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Reliability · approved ÷ (approved + missed)',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(
            height: AppSpacing.lg,
            thickness: 1,
            color: AppColors.darkBorder,
          ),
          // A Wrap, not a Row of `Expanded`s: Missed and Cancelled are hidden at
          // zero, so an `Expanded` layout gave a lone "Done" door a third of the
          // panel one day and the whole width the next.
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              _RecordDoor(
                count: done,
                label: 'Done',
                onTap: () => onOpen(
                  title: 'Done',
                  filter: const TaskFeedFilter(
                    status: TaskStatus.approved,
                    activeWindowOnly: false,
                  ),
                  description:
                      'Approved and closed. Includes work that finished '
                      'after its deadline — see each task for lateness.',
                  emptyMessage: 'Nothing approved yet.',
                  emptyTitle: 'No approved tasks',
                ),
              ),
              if (cancelled > 0)
                _RecordDoor(
                  count: cancelled,
                  label: 'Cancelled',
                  onTap: () => onOpen(
                    title: 'Cancelled',
                    filter: const TaskFeedFilter(
                      status: TaskStatus.cancelled,
                      activeWindowOnly: false,
                    ),
                    description:
                        'Work a manager or admin decided would not be done — a decision, not a failure. Never counted as Missed.',
                    emptyMessage: 'Nothing has been cancelled.',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A quiet figure you can open. The **number** carries the weight and the word
/// supports it — printed as one uniform grey string, the count and its label
/// were equally loud and neither was legible at a glance.
class _RecordDoor extends StatelessWidget {
  const _RecordDoor({
    required this.count,
    required this.label,
    required this.onTap,
  });
  final int count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$count $label',
    child: InkWell(
      onTap: onTap,
      borderRadius: AppRadius.smAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$count',
              style: AppTypography.labelSmall.copyWith(
                fontSize: 15,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_outward_rounded,
              size: 12,
              color: AppColors.textQuaternary,
            ),
          ],
        ),
      ),
    ),
  );
}

/// A branch card: compact identity, operational triple, and one reliability
/// statement. It intentionally does not repeat completion as a progress bar.
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
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  0,
                ),
                child: _plainHeader(m),
              ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // A caught-up branch shows a sentence, not three zeros. The
                  // same ruling the employee workload row already follows: a
                  // zero is context, and a component built of nothing but zeros
                  // looks like a component that failed.
                  if (m.active == 0 && m.pendingReview == 0 && m.overdue == 0)
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 15,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Nothing open',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    )
                  else
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
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _caption(m, pct),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
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
    return SizedBox(
      height: 116,
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
          // Strong scrim keeps the compact identity band legible over any photo
          // — heavier than the old banner's, because the band is now half the
          // height and the name sits closer to the artwork. It must stay
          // **translucent**: an opaque gradient here would cover the cover
          // photo completely and quietly delete the branch identity the card
          // exists to carry (§8b).
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x59000000), Color(0xF2000000)],
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
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        // Pill-shaped, from the radius scale — not a one-off `circular(8)`.
        borderRadius: AppRadius.fullAll,
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
    // One figure-cell spec across the task surfaces: 24/1.1 over an 11px
    // caption with a 3pt gap (see the employee drill-down's summary).
    return Expanded(
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
}
