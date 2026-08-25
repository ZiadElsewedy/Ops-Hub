import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/core/extensions/context_extensions.dart';
import 'package:opshub/core/responsive/breakpoints.dart';
import 'package:opshub/core/routes/route_names.dart';
import 'package:opshub/features/sales/presentation/widgets/admin_branch_sales_summary.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/widgets/admin_section_header.dart';
import 'package:opshub/core/widgets/attention_panel.dart';
import 'package:opshub/core/widgets/command_hint.dart';
import 'package:opshub/core/widgets/digest_panel.dart';
import 'package:opshub/core/widgets/hero_mood.dart';
import 'package:opshub/core/widgets/primary_cta.dart';
import 'package:opshub/core/widgets/app_motion.dart';
import 'package:opshub/core/widgets/metric_tile.dart';
import 'package:opshub/core/widgets/page_hero.dart';
import 'package:opshub/core/widgets/sync_button.dart';
import 'package:opshub/core/utils/dashboard_mood.dart';
import 'package:opshub/features/cases/presentation/cubit/case_list_cubit.dart';
import 'package:opshub/features/cases/presentation/cubit/case_list_state.dart';
import 'package:opshub/features/requests/presentation/cubit/requests_list_cubit.dart';
import 'package:opshub/features/requests/presentation/cubit/requests_list_state.dart';
import 'package:opshub/features/schedule/presentation/cubit/shift_swap_cubit.dart';
import 'package:opshub/features/schedule/presentation/cubit/shift_swap_state.dart';
import 'package:opshub/features/schedule/presentation/widgets/swap_alert_card.dart'
    show showSwapQueueSheet;
import 'package:opshub/features/statistics/presentation/cubit/statistics_cubit.dart';
import 'package:opshub/features/statistics/presentation/cubit/statistics_state.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/domain/task_feed.dart';
import 'package:opshub/features/task/domain/task_metrics.dart';
import 'package:opshub/features/task/presentation/cubit/task_cubit.dart';
import 'package:opshub/features/task/presentation/cubit/task_state.dart';
import 'package:opshub/features/task/presentation/pages/filtered_tasks_screen.dart';
import 'package:opshub/features/task/presentation/widgets/recent_activity_feed.dart';
import 'package:opshub/features/task/presentation/widgets/task_template_sheets.dart';

/// Admin Home — an operations **command center** (OpsHub Design System V2). Ranked
/// as a progressive-disclosure ladder so the admin instantly sees *what needs
/// attention right now*, then today's health, then recent activity — never "here
/// is every row in the database".
///
/// Hierarchy: **Hero** (greeting · one live state sentence · one Create Task
/// CTA) → **Needs attention** (the dominant layer:
/// self-gating — hidden entirely when every queue is empty, otherwise the triage
/// rows overdue · pending review · sent back · unassigned · swaps,
/// most-urgent-first, each a filtered drill, wrapped in a single living border)
/// → **Today** (light
/// four `MetricTile` doors) → **Recent activity** (clean vertical feed, no
/// filters) → **Operations**. On a phone, a final compact **Manage** directory
/// keeps the destinations absent from bottom navigation reachable; desktop has
/// them in its persistent sidebar, so its right rail stays Operations only.
///
/// This is the Admin counterpart of the signed-off Manager Home redesign
/// (2026-08-04). The prior mobile page placed two chunky navigation grids and a
/// five-cell `StatStrip` after its operational story: too much equal-weight
/// content, and one Due soon cell could not honestly open a matching list. Each
/// Today number is now a real door, derived from the same live task computation
/// as its drill. `Late` appears only in Needs attention directly above, rather
/// than being repeated as noise. It stays **live**: each section is a scoped
/// `BlocSelector` over the streams, so counters update without a manual refresh,
/// and a task emit rebuilds only the section it moves.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  /// A refresh is in flight — drives the header Sync control's spinner.
  bool _syncing = false;

  /// When the live sources were last (re)pulled — drives "Synced 3m ago".
  DateTime? _lastSynced;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// Refresh the live sources that feed the dashboard, tracking a single
  /// [_syncing]/[_lastSynced] pair so the header **Sync** button can show a
  /// spinner and how fresh the numbers are. The surface stays reactive without
  /// this — Sync is a manual escape hatch, not the update mechanism.
  Future<void> _load({bool force = false}) async {
    final user = context.currentUser;
    if (user == null) return;
    if (mounted) setState(() => _syncing = true);
    final startedAt = DateTime.now();
    try {
      await Future.wait([
        context.read<StatisticsCubit>().load(user, forceRefresh: force),
        // The all-branches task stream powers Needs Attention + the activity
        // feed. TaskCubit.load is self-guarding (no-op if already streaming this
        // user unless forced), so a revisit doesn't re-subscribe.
        context.read<TaskCubit>().load(user, forceRefresh: force),
        // Live scopes for the swap tile + the operations digest.
        context.read<ShiftSwapCubit>().loadAll(force: force),
        context.read<RequestsListCubit>().load(user, forceRefresh: force),
        context.read<CaseListCubit>().load(user, forceRefresh: force),
      ]);
      // On an explicit sync, keep the spin perceptible even when every source
      // answered from cache in a few milliseconds — otherwise the tap feels dead.
      if (force) {
        final rest =
            const Duration(milliseconds: 650) -
            DateTime.now().difference(startedAt);
        if (rest > Duration.zero) await Future<void>.delayed(rest);
      }
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
          _lastSynced = DateTime.now();
        });
      }
    }
  }

  Widget _syncButton({bool compact = false}) => SyncButton(
    syncing: _syncing,
    lastSynced: _lastSynced,
    onSync: () => _load(force: true),
    compact: compact,
  );

  @override
  Widget build(BuildContext context) {
    // No top-level cubit subscription: the scroll scaffold + static sections
    // build once. Each data-driven section subscribes to only what it needs via
    // a scoped selector, so a stream emit no longer rebuilds the whole screen.
    return RefreshIndicator(
      onRefresh: () => _load(force: true),
      child: context.isDesktop ? _desktop(context) : _mobile(context),
    );
  }

  // Stable keys + a fixed per-section stagger so the entrance plays once and
  // never replays when a conditional section appears. ~70ms steps (capped) give
  // the calm, sectioned cascade the command center wants. Honours reduced motion.
  Widget _sec(String id, int index, Widget child) {
    if (MediaQuery.of(context).disableAnimations) {
      return KeyedSubtree(key: ValueKey('admin-sec-$id'), child: child);
    }
    return EntranceFade(
      key: ValueKey('admin-sec-$id'),
      delay: Duration(milliseconds: (index * 70).clamp(0, 420)),
      child: child,
    );
  }

  // ── Hero ─────────────────────────────────────────────────────────
  String get _salutation {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _createTask() => startNewTaskFlow(
    context: context,
    cubit: context.read<TaskCubit>(),
    isAdmin: true,
    defaultBranchId: '',
  );

  Widget _hero() {
    final name = context.currentUser?.displayName;
    final first = (name != null && name.trim().isNotEmpty)
        ? name.trim().split(' ').first
        : 'Admin';
    // The subtitle is ONE live state sentence with a breathing pulse dot — the
    // dashboard reads its own operational state ("all caught up" vs "3 tasks
    // need your attention") off the same needs-attention total the section
    // below uses, so the two can never disagree.
    return BlocSelector<ShiftSwapCubit, ShiftSwapState, int>(
      selector: (state) => state.maybeWhen(
        loaded: (swaps, _) =>
            swaps.where((s) => !s.status.isResolved).length,
        orElse: () => 0,
      ),
      builder: (context, swaps) {
        return BlocSelector<
          TaskCubit,
          TaskState,
          (int, int, int, int, int)
        >(
          selector: (state) {
            final tasks = state.maybeWhen(
              loaded: (t, _, _, _, _) => t,
              orElse: () => const <TaskEntity>[],
            );
            final now = DateTime.now();
            return (
              runningNowCount(tasks),
              reviewCount(tasks),
              overdueCount(tasks, now),
              unassignedCount(tasks, now),
              rejectedCount(tasks),
            );
          },
          builder: (context, c) {
            final (_, reviews, overdue, unassigned, rejected) = c;
            final needsAttention =
                reviews + overdue + unassigned + rejected + swaps;
            final mood = dashboardMood(needsAttention: needsAttention);
            return PageHero(
              title: '$_salutation, $first',
              subtitleWidget: HeroMood(mood: mood, scope: ''),
              primaryAction: PrimaryCta(
                icon: Icons.add_rounded,
                label: 'Create Task',
                onTap: _createTask,
              ),
              trailing: context.isDesktop
                  ? [_syncButton(compact: true), const CommandHint()]
                  : [_syncButton(compact: true)],
            );
          },
        );
      },
    );
  }

  // ── Needs attention (the dominant layer) ─────────────────────────
  /// Driven entirely by live counts. **Self-gating** (like the sales summary):
  /// when every queue is empty the whole section — heading, box, and its
  /// trailing gap — disappears, so a clear board spends no vertical space on an
  /// "all clear" card. Anything outstanding → the heading returns above a box of
  /// triage rows (most-urgent-first).
  Widget _needsAttentionSection() {
    return BlocSelector<ShiftSwapCubit, ShiftSwapState, int>(
      selector: (state) => state.maybeWhen(
        loaded: (swaps, _) => swaps.where((s) => !s.status.isResolved).length,
        orElse: () => 0,
      ),
      builder: (context, swaps) {
        return BlocSelector<TaskCubit, TaskState, (int, int, int, int)>(
          selector: (state) {
            final tasks = state.maybeWhen(
              loaded: (t, _, _, _, _) => t,
              orElse: () => const <TaskEntity>[],
            );
            final now = DateTime.now();
            return (
              overdueCount(tasks, now),
              reviewCount(tasks),
              unassignedCount(tasks, now),
              rejectedCount(tasks),
            );
          },
          builder: (context, c) {
            final (overdue, reviews, unassigned, rejected) = c;
            // Nothing outstanding → render nothing at all (no "All clear" card,
            // no heading, no gap). The dashboard leads straight into Today.
            if (overdue + reviews + unassigned + rejected + swaps == 0) {
              return const SizedBox.shrink();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AdminSectionHeader(title: 'Needs attention'),
                AttentionPanel(
                  signals: _signals(
                    reviews: reviews,
                    overdue: overdue,
                    unassigned: unassigned,
                    rejected: rejected,
                    swaps: swaps,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            );
          },
        );
      },
    );
  }

  /// Push a reusable filtered task list (title + predicate) on the caller's
  /// navigator, so Back returns to the dashboard exactly where it was.
  /// [description] is the optional one-line "how does this count" line (same
  /// slot as `OperationsMetricScreen.description`) — null for callers that
  /// don't need it, so the Needs-attention box's existing calls are unchanged.
  void _openFiltered(
    String title,
    TaskFeedFilter filter, {
    String? empty,
    String? description,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FilteredTasksScreen(
          title: title,
          filter: filter,
          emptyMessage: empty ?? 'Nothing needs attention here right now.',
          description: description,
        ),
      ),
    );
  }

  void _openSwaps() => showSwapQueueSheet(
    context: context,
    currentUid: context.currentUser?.uid ?? '',
    showBranch: true,
  );

  /// The triage signals this board watches, in **fixed urgency order** — the
  /// order [AttentionPanel] renders them in and the order the cleared footer
  /// names them. Every entry drills into its own filtered list.
  List<AttentionSignal> _signals({
    required int reviews,
    required int overdue,
    required int unassigned,
    required int rejected,
    required int swaps,
  }) {
    return <AttentionSignal>[
      AttentionSignal(
        id: 'overdue',
        count: overdue,
        accent: AppColors.error,
        icon: Icons.event_busy_outlined,
        label: 'Late',
        sublabel: 'Past the deadline',
        onTap: () => _openFiltered(
          'Late',
          const TaskFeedFilter(preset: FeedPreset.overdue),
          empty: 'No late work. Nicely done.',
        ),
      ),
      AttentionSignal(
        id: 'reviews',
        count: reviews,
        accent: AppColors.warning,
        icon: Icons.rate_review_outlined,
        label: 'Pending review',
        sublabel: 'Approve or send back',
        onTap: () => context.push(RouteNames.adminReview),
      ),
      AttentionSignal(
        id: 'rejected',
        count: rejected,
        accent: AppColors.error,
        icon: Icons.replay_rounded,
        label: 'Sent back',
        sublabel: 'Rejected / rework',
        onTap: () => _openFiltered(
          'Sent back',
          const TaskFeedFilter(status: TaskStatus.rejected),
          empty: 'Nothing has been sent back.',
        ),
      ),
      AttentionSignal(
        id: 'unassigned',
        count: unassigned,
        accent: AppColors.warning,
        icon: Icons.person_off_outlined,
        label: 'Unassigned',
        sublabel: 'Needs an owner',
        onTap: () => _openFiltered(
          'Unassigned',
          const TaskFeedFilter(preset: FeedPreset.unassigned),
          empty: 'Every task has an owner.',
        ),
      ),
      AttentionSignal(
        id: 'swaps',
        count: swaps,
        accent: AppColors.warning,
        icon: Icons.swap_horiz_rounded,
        label: 'Swap requests',
        sublabel: 'Review shift swaps',
        onTap: _openSwaps,
      ),
    ];
  }

  // ── Today (four doors, not printed numbers) ──────────────────────
  /// **No `StatisticsCubit` dependency** (removed 2026-08-01 with `Approval
  /// rate`, whose `Approved ÷ (Approved + Rejected)` was a second, disagreeing
  /// completion formula next to Task Management's §10.1 figure — deleting it
  /// leaves that one figure as the app's single completion rate). Every stat
  /// here now derives from the same task stream `applyFeed` reads for the
  /// matching drill-down, so a cell's count and its list can never disagree.
  Widget _today() {
    final dueTodayFilter = const TaskFeedFilter(preset: FeedPreset.dueToday);
    return BlocSelector<TaskCubit, TaskState, (int, int, int, int)>(
      selector: (state) {
        final tasks = state.maybeWhen(
          loaded: (t, _, _, _, _) => t,
          orElse: () => const <TaskEntity>[],
        );
        final now = DateTime.now();
        return (
          openCount(tasks),
          runningNowCount(tasks),
          applyFeed(tasks, dueTodayFilter, now).length,
          completedTodayCount(tasks, now),
        );
      },
      builder: (context, c) {
        final (open, running, dueToday, completedToday) = c;
        return MetricTileRow(
          tiles: [
            // "How much is on the table" — the number the owner was reading
            // Running now as (Running now = started only; a fresh, un-started
            // task is still Open, not Running).
            MetricTile(
              label: 'Open',
              value: open,
              icon: Icons.inbox_rounded,
              onTap: () => _openFiltered(
                'Open',
                const TaskFeedFilter(
                  statuses: {
                    TaskStatus.pending,
                    TaskStatus.started,
                    TaskStatus.completed,
                    TaskStatus.rejected,
                  },
                ),
                description:
                    'Open work — not started, in progress, marked done, or '
                    'sent back for rework.',
                empty:
                    'No open work — everything is either done or waiting '
                    'on review.',
              ),
            ),
            MetricTile(
              label: 'Running now',
              value: running,
              icon: Icons.bolt_rounded,
              onTap: () => _openFiltered(
                'Running now',
                const TaskFeedFilter(status: TaskStatus.started),
                description: 'An employee is executing this right now.',
                empty: 'Nothing is running right now.',
              ),
            ),
            MetricTile(
              label: 'Due today',
              value: dueToday,
              icon: Icons.today_rounded,
              onTap: () => _openFiltered(
                'Due today',
                dueTodayFilter,
                description: 'Active work whose deadline lands today.',
                empty: 'Nothing else falls due today.',
              ),
            ),
            MetricTile(
              label: 'Done today',
              value: completedToday,
              icon: Icons.check_circle_outline_rounded,
              onTap: () => _openFiltered(
                'Done today',
                const TaskFeedFilter(status: TaskStatus.approved),
                description:
                    'Approved today only — not the running lifetime total.',
                empty: 'Nothing approved yet today.',
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Operations digest (requests · cases · schedule) ──────────────
  Widget _digest() {
    return BlocBuilder<StatisticsCubit, StatisticsState>(
      builder: (context, statsState) {
        final s = statsState.maybeWhen(loaded: (s) => s, orElse: () => null);
        return BlocSelector<RequestsListCubit, RequestsListState, int>(
          selector: (state) => state.maybeMap(
            loaded: (l) => l.requests.where((r) => r.status.isPending).length,
            orElse: () => 0,
          ),
          builder: (context, pendingReq) {
            return BlocSelector<CaseListCubit, CaseListState, int>(
              selector: (state) => state.maybeMap(
                loaded: (l) => l.cases.where((c) => c.status.isActive).length,
                orElse: () => 0,
              ),
              builder: (context, activeCases) {
                final scheduled = s?.branchesWithSchedule ?? 0;
                final totalBranches = s?.totalBranches ?? 0;
                return DigestPanel(
                  entries: [
                    DigestEntry(
                      icon: Icons.assignment_turned_in_outlined,
                      label: 'Pending requests',
                      value: '$pendingReq',
                      accent: pendingReq > 0 ? AppColors.warning : null,
                      onTap: () => context.push(RouteNames.requests),
                    ),
                    DigestEntry(
                      icon: Icons.forum_outlined,
                      label: 'Active cases',
                      value: '$activeCases',
                      accent: activeCases > 0 ? AppColors.warning : null,
                      onTap: () => context.push(RouteNames.cases),
                    ),
                    DigestEntry(
                      icon: Icons.calendar_view_week_outlined,
                      label: 'Schedule coverage',
                      value: '$scheduled/$totalBranches',
                      accent: AppColors.textSecondary,
                      onTap: () => context.push(RouteNames.adminSchedule),
                    ),
                    // A door, not a figure — attendance is a longitudinal
                    // record across every branch, so there is no honest single
                    // number to print beside it (same reasoning as the
                    // manager's entry).
                    //
                    // This is the ONLY way into attendance on a phone. The
                    // whole module — the workspace, the review ledger, the
                    // weekly/monthly reports — hangs off `/attendance/reports`,
                    // and that route was otherwise reachable for an admin only
                    // from the DESKTOP sidebar. The manager has had this entry
                    // since their home was rebuilt; the admin never did.
                    DigestEntry(
                      icon: Icons.fingerprint_rounded,
                      label: 'Attendance & reports',
                      onTap: () => context.push(RouteNames.attendanceReports),
                    ),
                    DigestEntry(
                      icon: Icons.payments_outlined,
                      label: 'Branch sales',
                      onTap: () => context.push(RouteNames.salesAdminOverview),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  /// Mobile-only doors for destinations absent from the bottom navigation.
  Widget _manage() => DigestPanel(
    entries: [
      DigestEntry(
        icon: Icons.storefront_outlined,
        label: 'Branches',
        onTap: () => context.push(RouteNames.adminBranches),
      ),
      DigestEntry(
        icon: Icons.supervisor_account_outlined,
        label: 'Managers',
        onTap: () => context.push(RouteNames.adminManagers),
      ),
      DigestEntry(
        icon: Icons.groups_outlined,
        label: 'Employees',
        onTap: () => context.push(RouteNames.adminEmployees),
      ),
      DigestEntry(
        icon: Icons.analytics_outlined,
        label: 'Analytics',
        onTap: () => context.push(RouteNames.adminAnalytics),
      ),
      DigestEntry(
        icon: Icons.person_add_alt_1_outlined,
        label: 'New account',
        onTap: () => context.push(RouteNames.adminCreateAccount),
      ),
    ],
  );

  // ── Layouts ──────────────────────────────────────────────────────
  Widget _activityHeader() => AdminSectionHeader(
    title: 'Recent activity',
    actionLabel: 'See all',
    onAction: () => context.push(RouteNames.adminTasks),
  );

  Widget _mobile(BuildContext context) {
    var i = 0;
    Widget sec(String id, Widget child) => _sec(id, i++, child);
    return ListView(
      key: const PageStorageKey('admin-dashboard-mobile'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.sm,
        AppSpacing.pagePadding,
        AppSpacing.xxxl,
      ),
      children: [
        sec('hero', _hero()),
        const SizedBox(height: AppSpacing.xl),
        // Self-gating: heading + box + trailing gap, or nothing when all clear.
        sec('attn', _needsAttentionSection()),
        sec('today-h', const AdminSectionHeader(title: 'Today')),
        sec('today', _today()),
        // Gates itself entirely: no opted-in branch ⇒ no heading, no box, no gap.
        sec('sales', const AdminBranchSalesSummary()),
        const SizedBox(height: AppSpacing.xl),
        sec('activity-h', _activityHeader()),
        sec('activity', const RecentActivityFeed()),
        const SizedBox(height: AppSpacing.xl),
        sec('digest-h', const AdminSectionHeader(title: 'Operations')),
        sec('digest', _digest()),
        const SizedBox(height: AppSpacing.xl),
        sec('manage-h', const AdminSectionHeader(title: 'Manage')),
        sec('manage', _manage()),
      ],
    );
  }

  /// Executive desktop arrangement: the operational story (Needs attention →
  /// today → recent activity) reads down the wide main column; the launch
  /// surface (operations digest) sits in a fixed right
  /// rail, always in view. Centred in a ~1260 max-width column so it reads like a
  /// desktop document rather than a stretched phone screen.
  Widget _desktop(BuildContext context) {
    var i = 0;
    Widget sec(String id, Widget child) => _sec(id, i++, child);
    final hPad = context.isUltrawide ? 48.0 : 40.0;
    return ListView(
      key: const PageStorageKey('admin-dashboard-desktop'),
      padding: EdgeInsets.fromLTRB(hPad, AppSpacing.lg, hPad, AppSpacing.xxxl),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1260),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                sec('hero', _hero()),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main column — minmax(0, 1fr): flexes and may shrink to 0.
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Self-gating: heading + box + trailing gap, or
                          // nothing when all clear.
                          sec('attn', _needsAttentionSection()),
                          sec(
                            'today-h',
                            const AdminSectionHeader(title: 'Today'),
                          ),
                          sec('today', _today()),
                          // Gates itself entirely: no opted-in branch ⇒ no
                          // heading, no box, and no gap where it would be.
                          sec('sales', const AdminBranchSalesSummary()),
                          const SizedBox(height: AppSpacing.xl),
                          sec('activity-h', _activityHeader()),
                          sec('activity', const RecentActivityFeed()),
                        ],
                      ),
                    ),
                    const SizedBox(width: 40),
                    // Right rail — fixed 360.
                    SizedBox(
                      width: 360,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          sec(
                            'digest-h',
                            const AdminSectionHeader(title: 'Operations'),
                          ),
                          sec('digest', _digest()),
                        ],
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
  }
}
