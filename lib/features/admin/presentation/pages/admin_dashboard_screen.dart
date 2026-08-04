import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/responsive/breakpoints.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/widgets/action_card.dart';
import 'package:drop/core/widgets/admin_section_header.dart';
import 'package:drop/core/widgets/attention_panel.dart';
import 'package:drop/core/widgets/command_hint.dart';
import 'package:drop/core/widgets/digest_panel.dart';
import 'package:drop/core/widgets/hero_mood.dart';
import 'package:drop/core/widgets/primary_cta.dart';
import 'package:drop/core/widgets/responsive_card_grid.dart';
import 'package:drop/core/widgets/app_motion.dart';
import 'package:drop/core/widgets/page_hero.dart';
import 'package:drop/core/widgets/stat_strip.dart';
import 'package:drop/core/widgets/sync_button.dart';
import 'package:drop/core/utils/dashboard_mood.dart';
import 'package:drop/features/cases/presentation/cubit/case_list_cubit.dart';
import 'package:drop/features/cases/presentation/cubit/case_list_state.dart';
import 'package:drop/features/requests/presentation/cubit/requests_list_cubit.dart';
import 'package:drop/features/requests/presentation/cubit/requests_list_state.dart';
import 'package:drop/features/schedule/presentation/cubit/shift_swap_cubit.dart';
import 'package:drop/features/schedule/presentation/cubit/shift_swap_state.dart';
import 'package:drop/features/schedule/presentation/widgets/swap_alert_card.dart'
    show showSwapQueueSheet;
import 'package:drop/features/statistics/domain/entities/statistics_entity.dart';
import 'package:drop/features/statistics/presentation/cubit/statistics_cubit.dart';
import 'package:drop/features/statistics/presentation/cubit/statistics_state.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/domain/task_feed.dart';
import 'package:drop/features/task/domain/task_metrics.dart';
import 'package:drop/features/task/domain/task_schedule.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/task/presentation/cubit/task_state.dart';
import 'package:drop/features/task/presentation/pages/filtered_tasks_screen.dart';
import 'package:drop/features/task/presentation/widgets/recent_activity_feed.dart';
import 'package:drop/features/task/presentation/widgets/task_template_sheets.dart';

/// Admin Home — an operations **command center** (DROP Design System V2). Ranked
/// as a progressive-disclosure ladder so the admin instantly sees *what needs
/// attention right now*, then today's health, then recent activity — never "here
/// is every row in the database".
///
/// Hierarchy: **Hero** (greeting · one live state sentence · scope · one Create
/// Task CTA) → **Needs attention** (the dominant layer: ONE grouped box — a calm
/// "all clear" summary when every queue is empty, otherwise the triage rows
/// overdue · pending review · sent back · unassigned · swaps, most-urgent-first,
/// each a filtered drill, wrapped in a single living border) → **Today** (light
/// count-up metrics) → **Recent activity** (clean vertical feed, no filters) →
/// right rail: **Operations** (requests · cases · schedule) · Quick actions ·
/// Manage.
///
/// Every visual is a reusable V2 primitive (`PageHero`, `GlassContainer`,
/// `StatStrip`, `ActivityCard`, `LiveStatusBorder`) — this screen only arranges
/// them and derives the data, so the same language carries to every future
/// module. It stays **live**: each section is a scoped `BlocSelector` over the
/// streams, so counters update without a manual refresh, and a task emit rebuilds
/// only the section it moves.
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

  String _scopeLine(StatisticsEntity? s, int running) {
    if (s == null) {
      return running > 0 ? '$running running now' : 'Operations overview';
    }
    final b =
        '${s.totalBranches} ${s.totalBranches == 1 ? 'branch' : 'branches'}';
    final e =
        '${s.totalEmployees} ${s.totalEmployees == 1 ? 'employee' : 'employees'}';
    return '$b · $e · $running running';
  }

  void _createTask() => startNewTaskFlow(
    context: context,
    cubit: context.read<TaskCubit>(),
    isAdmin: true,
    defaultBranchId: '',
  );

  /// The eyebrow kicker: today's date, and — once we've pulled at least once —
  /// how fresh the numbers are, per the spec ("date · Synced 3m ago").
  String _eyebrow() {
    final date = AppDateFormatter.weekdayDayMonth(DateTime.now());
    final synced = _syncing
        ? 'Syncing…'
        : (_lastSynced == null ? null : syncLabel(_lastSynced));
    return synced == null ? date : '$date · $synced';
  }

  Widget _hero() {
    final name = context.currentUser?.displayName;
    final first = (name != null && name.trim().isNotEmpty)
        ? name.trim().split(' ').first
        : 'Admin';
    final eyebrow = _eyebrow();
    return BlocBuilder<StatisticsCubit, StatisticsState>(
      builder: (context, statsState) {
        final s = statsState.maybeWhen(loaded: (s) => s, orElse: () => null);
        // The subtitle is ONE live state sentence with a breathing pulse dot —
        // the dashboard reads its own operational state ("all caught up" vs
        // "3 tasks need your attention") off the same needs-attention total the
        // section below uses, so the two can never disagree.
        return BlocSelector<ShiftSwapCubit, ShiftSwapState, int>(
          selector: (state) => state.maybeWhen(
            loaded: (swaps, _) =>
                swaps.where((s) => !s.status.isResolved).length,
            orElse: () => 0,
          ),
          builder: (context, swaps) {
            return BlocSelector<TaskCubit, TaskState, (int, int, int, int, int)>(
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
                final (running, reviews, overdue, unassigned, rejected) = c;
                final needsAttention =
                    reviews + overdue + unassigned + rejected + swaps;
                final mood = dashboardMood(needsAttention: needsAttention);
                return PageHero(
                  eyebrow: eyebrow,
                  title: '$_salutation, $first',
                  subtitleWidget: HeroMood(
                    mood: mood,
                    scope: _scopeLine(s, running),
                  ),
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
      },
    );
  }

  // ── Needs attention (the dominant layer) ─────────────────────────
  /// Driven entirely by live counts, rendered as ONE grouped box that stays in
  /// place. Every queue empty → a calm "all clear" summary; anything outstanding →
  /// the box of triage rows (most-urgent-first), a fresh signal sliding in as a
  /// row rather than the whole surface re-appearing.
  Widget _needsAttention() {
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
            return AttentionPanel(
              signals: _signals(
                reviews: reviews,
                overdue: overdue,
                unassigned: unassigned,
                rejected: rejected,
                swaps: swaps,
              ),
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

  // ── Today (light metrics) ────────────────────────────────────────
  /// **No `StatisticsCubit` dependency** (removed 2026-08-01 with `Approval
  /// rate`, whose `Approved ÷ (Approved + Rejected)` was a second, disagreeing
  /// completion formula next to Task Management's §10.1 figure — deleting it
  /// leaves that one figure as the app's single completion rate). Every stat
  /// here now derives from the same task stream `applyFeed` reads for the
  /// matching drill-down, so a cell's count and its list can never disagree.
  Widget _today() {
    return BlocSelector<TaskCubit, TaskState, (int, int, int, int, int)>(
      selector: (state) {
        final tasks = state.maybeWhen(
          loaded: (t, _, _, _, _) => t,
          orElse: () => const <TaskEntity>[],
        );
        final now = DateTime.now();
        return (
          openCount(tasks),
          runningNowCount(tasks),
          dueSoonCount(tasks, now),
          overdueCount(tasks, now),
          completedTodayCount(tasks, now),
        );
      },
      builder: (context, c) {
        final (open, running, dueSoon, late, completedToday) = c;
        return StatStrip(
          stats: [
            // "How much is on the table" — the number the owner was reading
            // Running now as (Running now = started only; a fresh, un-started
            // task is still Open, not Running).
            Stat(
              label: 'Open',
              count: open,
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
                empty: 'No open work — everything is either done or waiting '
                    'on review.',
              ),
            ),
            Stat(
              label: 'Running now',
              count: running,
              onTap: () => _openFiltered(
                'Running now',
                const TaskFeedFilter(status: TaskStatus.started),
                description: 'An employee is executing this right now.',
                empty: 'Nothing is running right now.',
              ),
            ),
            // Not tappable — see the delta-2 report. No `TaskFeedFilter` can
            // reproduce `schedulePhase`'s dueSoon precedence (it excludes
            // completed/waitingReview even though the active window includes
            // them) without either an over-counting filter or a reverse
            // dependency from `task_feed.dart` into `task_schedule.dart`. A
            // cell that doesn't open beats one whose count and list disagree.
            Stat(
              label: 'Due soon',
              count: dueSoon,
              tone: dueSoon > 0 ? AppColors.warning : null,
            ),
            Stat(
              label: 'Late',
              count: late,
              tone: late > 0 ? AppColors.error : null,
              onTap: () => _openFiltered(
                'Late',
                const TaskFeedFilter(preset: FeedPreset.overdue),
                description:
                    'Active work past its deadline — counted every day '
                    "until it's closed, however old. Work that finished "
                    'late shows on the task itself, not here.',
                empty: 'Nothing is running past its deadline.',
              ),
            ),
            Stat(
              label: 'Completed today',
              count: completedToday,
              onTap: () => _openFiltered(
                'Completed today',
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
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  // ── Quick actions ────────────────────────────────────────────────
  Widget _quickActions({bool compact = false}) {
    return _grid(maxItemWidth: compact ? 180 : 300, [
      ActionCard(
        icon: Icons.assignment_add,
        title: 'New Task',
        onTap: _createTask,
      ),
      ActionCard(
        icon: Icons.add_business_outlined,
        title: 'Add Branch',
        onTap: () => context.push(RouteNames.adminBranches),
      ),
      ActionCard(
        icon: Icons.person_add_alt_1_outlined,
        title: 'New Account',
        onTap: () => context.push(RouteNames.adminCreateAccount),
      ),
      ActionCard(
        icon: Icons.supervisor_account_outlined,
        title: 'Add Manager',
        onTap: () => context.push(RouteNames.adminManagers),
      ),
    ]);
  }

  // ── Manage (module directory) ────────────────────────────────────
  /// A short, quiet directory to the two full-list surfaces. Everything else
  /// (Employees, Analytics, Branches, Managers) lives in the persistent sidebar,
  /// so this stays a two-row shortcut rather than a second nav.
  Widget _manage({bool compact = false}) {
    return _grid(maxItemWidth: compact ? 400 : 300, [
      ActionCard(
        icon: Icons.fact_check_outlined,
        title: 'Tasks',
        subtitle: 'All branches',
        secondary: true,
        onTap: () => context.push(RouteNames.adminTasks),
      ),
      ActionCard(
        icon: Icons.calendar_view_week_outlined,
        title: 'Schedules',
        subtitle: 'Any branch',
        secondary: true,
        onTap: () => context.push(RouteNames.adminSchedule),
      ),
    ]);
  }

  Widget _grid(List<Widget> cards, {double maxItemWidth = 300}) {
    return ResponsiveCardGrid(maxItemWidth: maxItemWidth, children: cards);
  }

  // ── Layouts ──────────────────────────────────────────────────────
  Widget _activityHeader() => AdminSectionHeader(
    title: 'Recent activity',
    subtitle: 'Every branch, live',
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
        sec(
          'attn-h',
          const AdminSectionHeader(
            title: 'Needs attention',
            subtitle: 'Act on these first',
          ),
        ),
        sec('attn', _needsAttention()),
        const SizedBox(height: AppSpacing.xl),
        sec('today-h', const AdminSectionHeader(title: 'Today')),
        sec('today', _today()),
        const SizedBox(height: AppSpacing.xl),
        sec('activity-h', _activityHeader()),
        sec('activity', const RecentActivityFeed()),
        const SizedBox(height: AppSpacing.xl),
        sec('digest-h', const AdminSectionHeader(title: 'Operations')),
        sec('digest', _digest()),
        const SizedBox(height: AppSpacing.xl),
        sec('qa-h', const AdminSectionHeader(title: 'Quick actions')),
        sec('qa', _quickActions()),
        const SizedBox(height: AppSpacing.xl),
        sec('manage-h', const AdminSectionHeader(title: 'Manage')),
        sec('manage', _manage()),
      ],
    );
  }

  /// Executive desktop arrangement: the operational story (Needs attention →
  /// today → recent activity) reads down the wide main column; the launch
  /// surfaces (operations digest · quick actions · manage) sit in a fixed right
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
                          sec(
                            'attn-h',
                            const AdminSectionHeader(
                              title: 'Needs attention',
                              subtitle: 'Act on these first',
                            ),
                          ),
                          sec('attn', _needsAttention()),
                          const SizedBox(height: AppSpacing.xl),
                          sec('today-h', const AdminSectionHeader(title: 'Today')),
                          sec('today', _today()),
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
                          const SizedBox(height: AppSpacing.xl),
                          sec(
                            'qa-h',
                            const AdminSectionHeader(title: 'Quick actions'),
                          ),
                          sec('qa', _quickActions(compact: true)),
                          const SizedBox(height: AppSpacing.xl),
                          sec(
                            'manage-h',
                            const AdminSectionHeader(title: 'Manage'),
                          ),
                          sec('manage', _manage(compact: true)),
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
