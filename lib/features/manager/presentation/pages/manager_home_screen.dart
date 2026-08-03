import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/responsive/breakpoints.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/utils/dashboard_mood.dart';
import 'package:drop/core/widgets/admin_section_header.dart';
import 'package:drop/core/widgets/animated_count.dart';
import 'package:drop/core/widgets/app_motion.dart';
import 'package:drop/core/widgets/attention_panel.dart';
import 'package:drop/core/widgets/command_hint.dart';
import 'package:drop/core/widgets/digest_panel.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/core/widgets/hero_mood.dart';
import 'package:drop/core/widgets/metric_tile.dart';
import 'package:drop/core/widgets/page_hero.dart';
import 'package:drop/core/widgets/primary_cta.dart';
import 'package:drop/core/widgets/sync_button.dart';
import 'package:drop/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:drop/features/branch/presentation/cubit/branch_state.dart';
import 'package:drop/features/cases/presentation/cubit/case_list_cubit.dart';
import 'package:drop/features/cases/presentation/cubit/case_list_state.dart';
import 'package:drop/features/chat/presentation/widgets/recent_messages_card.dart';
import 'package:drop/features/requests/presentation/cubit/requests_list_cubit.dart';
import 'package:drop/features/requests/presentation/cubit/requests_list_state.dart';
import 'package:drop/features/schedule/presentation/cubit/shift_swap_cubit.dart';
import 'package:drop/features/schedule/presentation/cubit/shift_swap_state.dart';
import 'package:drop/features/schedule/presentation/widgets/swap_alert_card.dart'
    show showSwapQueueSheet;
import 'package:drop/features/statistics/presentation/cubit/statistics_cubit.dart';
import 'package:drop/features/statistics/presentation/cubit/statistics_state.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/domain/task_feed.dart';
import 'package:drop/features/task/domain/task_metrics.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/task/presentation/cubit/task_state.dart';
import 'package:drop/features/task/presentation/pages/filtered_tasks_screen.dart';
import 'package:drop/features/task/presentation/widgets/recent_activity_feed.dart';
import 'package:drop/features/task/presentation/widgets/task_template_sheets.dart';

/// Manager Home — the **branch** command center. The same Design System V2
/// ladder the Admin dashboard was signed off on, scoped to the one branch a
/// manager runs:
///
/// **Hero** (date · branch · greeting · one live state sentence · one New Task
/// CTA) → **Needs attention** (the dominant layer: one grouped box of triage
/// rows — late · pending review · sent back · unassigned · swaps,
/// most-urgent-first, each a filtered drill) → **Today** (four `MetricTile`
/// doors) → **On shift today** (one card into the schedule) → **Recent
/// activity** → **Operations**. Desktop moves Operations and the recent-messages
/// card into a fixed 360px right rail beside the story.
///
/// This replaced a flat wall of ten equal-weight stat cards plus an embedded
/// task browser (2026-08-03). Two things drove the rewrite:
///
/// * **Nothing was ranked.** "Employees 8" and "Waiting reviews 0" were drawn
///   the same size, so the screen answered *how many rows exist* rather than
///   *what needs you first*. Ranking is now the whole layout.
/// * **The numbers disagreed with each other.** A `Active tasks 4` hero card sat
///   above a feed strip reading `Late 1 · Pending review 0 · Unassigned 0`, from
///   a different source. Every count here now derives from the same live
///   `TaskCubit` stream the drill-down renders (via `task_metrics.dart`), so a
///   cell's figure and its list cannot drift apart.
///
/// **Second pass, same day** (owner: *"why everything in 1 page on mobile? …
/// make On shift today and Today way more clear and clickable … is that really
/// nice to see too much text?"*):
///
/// * **Everything on this page is now a door.** The Today figures were a
///   `StatStrip` — number-and-label text on one flat surface, with nothing
///   saying it could be opened and one cell (`Due soon`) that genuinely
///   couldn't. They are `MetricTile`s, and the deadline cell is `Due today`,
///   counted by the same `applyFeed` call its drill-down renders. Coverage was
///   four unclickable cells; it is one card into the weekly schedule.
/// * **Less text.** The hero lost a whole line (branch moved into the eyebrow,
///   `Synced just now` dropped — the Sync control already says it), and the
///   section headers lost their subtitles.
/// * **Fewer sections.** **Quick actions is deleted** — Branch tasks and Weekly
///   schedule are bottom-nav destinations and Broadcast is the app-bar
///   megaphone, so it was three cards of duplicated navigation. Recent messages
///   is **desktop-only**: Chat is the fourth bottom-nav tab, and conversation
///   previews at the foot of an operations board were the page trying to be
///   every screen at once.
///
/// The full search/filter/sort task browser that used to be embedded here lives
/// where it belongs — Branch Operations (`/manager/tasks`) and its All-tasks
/// list — reachable from **Recent activity → See all** and the Tasks tab.
/// Nothing was removed from the manager's reach, only re-ranked.
///
/// The manager's `TaskCubit` stream is already branch-scoped, but every filter
/// pushed from here still passes `branchId` explicitly so a drill-down states
/// its own scope rather than inheriting it.
class ManagerHomeScreen extends StatefulWidget {
  const ManagerHomeScreen({super.key});

  @override
  State<ManagerHomeScreen> createState() => _ManagerHomeScreenState();
}

class _ManagerHomeScreenState extends State<ManagerHomeScreen> {
  /// A refresh is in flight — drives the header Sync control's spinner.
  bool _syncing = false;

  /// When the live sources were last (re)pulled — drives "Synced 3m ago".
  DateTime? _lastSynced;

  String get _branchId => context.currentUser?.branchId ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// Refresh the live sources behind the board. The surface stays reactive
  /// without this — Sync is a manual escape hatch, not the update mechanism.
  Future<void> _load({bool force = false}) async {
    final user = context.currentUser;
    if (user == null) return;
    if (mounted) setState(() => _syncing = true);
    final startedAt = DateTime.now();
    try {
      await Future.wait([
        context.read<StatisticsCubit>().load(user, forceRefresh: force),
        // The branch-scoped task stream powers Needs attention, Today and the
        // activity feed. `load` is self-guarding, so a revisit doesn't
        // re-subscribe.
        context.read<TaskCubit>().load(user, forceRefresh: force),
        // Branch scope only — a manager runs exactly one branch, so the
        // all-branches swap queue the admin loads would be both wrong and
        // wasteful here.
        if (_branchId.isNotEmpty)
          context.read<ShiftSwapCubit>().loadBranch(_branchId, force: force),
        context.read<RequestsListCubit>().load(user, forceRefresh: force),
        context.read<CaseListCubit>().load(user, forceRefresh: force),
        // The branch directory, for the hero's identity line. Cheap + cached.
        context.read<BranchCubit>().loadIfNeeded(),
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

  // ── Navigation helpers ───────────────────────────────────────────
  /// Push a filtered task list on the caller's navigator, so Back returns to
  /// the dashboard exactly where it was. Always branch-pinned.
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

  void _createTask() => startNewTaskFlow(
    context: context,
    cubit: context.read<TaskCubit>(),
    // A manager creates into their own branch, never picks one.
    isAdmin: false,
    defaultBranchId: _branchId,
    templateBranchFilter: _branchId,
  );

  void _openSwaps() => showSwapQueueSheet(
    context: context,
    currentUid: context.currentUser?.uid ?? '',
    // One branch — naming it on every row would be noise.
    showBranch: false,
  );

  Widget _syncButton() => SyncButton(
    syncing: _syncing,
    lastSynced: _lastSynced,
    onSync: () => _load(force: true),
    compact: true,
  );

  // ── Hero ─────────────────────────────────────────────────────────
  String get _salutation {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// The eyebrow kicker: the short date and **which branch this board covers**.
  ///
  /// The branch used to sit on a fourth text line under the mood sentence,
  /// alongside the employee count and a "0 running" that the Today row already
  /// answers. Scope is context, so it belongs in the kicker — that removes a
  /// whole line from the hero and leaves the greeting with exactly one
  /// supporting sentence beneath it. Freshness (`Synced 3m ago`) is deliberately
  /// **not** here: the Sync control beside the hero already carries it as its
  /// accessible label, and it is the single least useful string on the screen.
  String _eyebrow() {
    final date = AppDateFormatter.weekdayDayMonth(DateTime.now());
    final branch = context.read<BranchCubit>().branchById(_branchId)?.name;
    if (branch == null || branch.trim().isEmpty) return date;
    return '$date · ${branch.trim()}';
  }

  Widget _hero() {
    final name = context.currentUser?.displayName;
    final first = (name != null && name.trim().isNotEmpty)
        ? name.trim().split(' ').first
        : 'Manager';
    // Rebuilds on a branch load so the hero picks up the branch name.
    return BlocBuilder<BranchCubit, BranchState>(
      builder: (context, _) {
        return BlocSelector<ShiftSwapCubit, ShiftSwapState, int>(
          selector: _openSwapCount,
          builder: (context, swaps) {
            return BlocSelector<TaskCubit, TaskState, (int, int, int, int, int)>(
              selector: _attentionCounts,
              builder: (context, c) {
                final (_, reviews, overdue, unassigned, rejected) = c;
                // The hero sentence and the Needs-attention panel below it
                // switch off the SAME total, so they can never disagree.
                final mood = dashboardMood(
                  needsAttention:
                      reviews + overdue + unassigned + rejected + swaps,
                );
                return PageHero(
                  eyebrow: _eyebrow(),
                  title: '$_salutation, $first',
                  // One supporting line, not two: `HeroMood`'s scope slot is
                  // empty here because the eyebrow carries the branch.
                  subtitleWidget: HeroMood(mood: mood, scope: ''),
                  primaryAction: PrimaryCta(
                    icon: Icons.add_rounded,
                    label: 'New Task',
                    onTap: _createTask,
                  ),
                  trailing: context.isDesktop
                      ? [_syncButton(), const CommandHint()]
                      : [_syncButton()],
                );
              },
            );
          },
        );
      },
    );
  }

  // ── Live selectors (one place, so hero and panel read the same numbers) ──
  static int _openSwapCount(ShiftSwapState state) => state.maybeWhen(
    loaded: (swaps, _) => swaps.where((s) => !s.status.isResolved).length,
    orElse: () => 0,
  );

  /// `(running, reviews, overdue, unassigned, rejected)` off the live stream.
  static (int, int, int, int, int) _attentionCounts(TaskState state) {
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
  }

  // ── Needs attention (the dominant layer) ─────────────────────────
  Widget _needsAttention() {
    return BlocSelector<ShiftSwapCubit, ShiftSwapState, int>(
      selector: _openSwapCount,
      builder: (context, swaps) {
        return BlocSelector<TaskCubit, TaskState, (int, int, int, int, int)>(
          selector: _attentionCounts,
          builder: (context, c) {
            final (_, reviews, overdue, unassigned, rejected) = c;
            return AttentionPanel(
              signals: _signals(
                reviews: reviews,
                overdue: overdue,
                unassigned: unassigned,
                rejected: rejected,
                swaps: swaps,
              ),
              clearMessage:
                  'Nothing needs you right now — your branch is on top of it.',
            );
          },
        );
      },
    );
  }

  /// The triage signals this branch board watches, in **fixed urgency order**.
  /// Every entry drills into its own branch-pinned list.
  List<AttentionSignal> _signals({
    required int reviews,
    required int overdue,
    required int unassigned,
    required int rejected,
    required int swaps,
  }) {
    final branchId = _branchId;
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
          TaskFeedFilter(branchId: branchId, preset: FeedPreset.overdue),
          description:
              'Active work past its deadline — counted every day until it is '
              "closed. Work that finished late shows on the task itself, not "
              'here.',
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
        onTap: () => _openFiltered(
          'Pending review',
          TaskFeedFilter(branchId: branchId, status: TaskStatus.waitingReview),
          description: 'Submitted by your team and waiting on your decision.',
          empty: 'Nothing is waiting on your review.',
        ),
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
          TaskFeedFilter(branchId: branchId, status: TaskStatus.rejected),
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
          TaskFeedFilter(branchId: branchId, preset: FeedPreset.unassigned),
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

  // ── Today (four doors, not four printed numbers) ─────────────────
  /// Four `MetricTile`s — 2×2 on a phone, one row on desktop. They were a
  /// `StatStrip`, which on a phone is number-and-label text on a single flat
  /// surface: nothing said any of it could be opened, and one cell (`Due soon`)
  /// genuinely couldn't be. **Every tile here opens a list**, and the deadline
  /// cell is now `Due today`, counted with the very `applyFeed` call its
  /// drill-down renders — so the figure and the list are the same computation,
  /// not two that have to be kept in step.
  ///
  /// **`Late` is deliberately absent** — it is the lead row of Needs attention
  /// above, and printing the same number twice on one screen was exactly the
  /// noise this redesign set out to remove.
  Widget _today() {
    final branchId = _branchId;
    final dueTodayFilter = TaskFeedFilter(
      branchId: branchId,
      preset: FeedPreset.dueToday,
    );
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
            MetricTile(
              value: open,
              label: 'Open',
              icon: Icons.inbox_rounded,
              onTap: () => _openFiltered(
                'Open',
                TaskFeedFilter(
                  branchId: branchId,
                  statuses: const {
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
                    'No open work — everything is either done or waiting on '
                    'review.',
              ),
            ),
            MetricTile(
              value: running,
              label: 'Running now',
              icon: Icons.bolt_rounded,
              onTap: () => _openFiltered(
                'Running now',
                TaskFeedFilter(branchId: branchId, status: TaskStatus.started),
                description: 'Someone is executing this right now.',
                empty: 'Nothing is running right now.',
              ),
            ),
            MetricTile(
              value: dueToday,
              label: 'Due today',
              icon: Icons.today_rounded,
              onTap: () => _openFiltered(
                'Due today',
                dueTodayFilter,
                description: 'Active work whose deadline lands today.',
                empty: 'Nothing else falls due today.',
              ),
            ),
            MetricTile(
              value: completedToday,
              label: 'Done today',
              icon: Icons.check_circle_outline_rounded,
              onTap: () => _openFiltered(
                'Done today',
                TaskFeedFilter(branchId: branchId, status: TaskStatus.approved),
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

  // ── On shift today (the manager's other half of the job) ─────────
  /// One tappable coverage card into the weekly schedule.
  ///
  /// This was four `Team · On today · Morning · Night` cells — eight strings to
  /// say one thing, and **not one of them was clickable**, on the half of the
  /// job that is entirely about the roster. It is now a single card: the number
  /// on shift, how that reads against the team, the morning/night split as two
  /// quiet pills, and a chevron into the schedule.
  Widget _coverage() {
    return BlocBuilder<StatisticsCubit, StatisticsState>(
      builder: (context, state) {
        final s = state.maybeWhen(loaded: (s) => s, orElse: () => null);
        return _CoverageCard(
          onShift: s?.scheduledToday ?? 0,
          team: s?.employeesInBranch ?? 0,
          morning: s?.morningShiftEmployees ?? 0,
          night: s?.nightShiftEmployees ?? 0,
          onTap: () => context.push(RouteNames.managerSchedule),
        );
      },
    );
  }

  // ── Operations digest ────────────────────────────────────────────
  Widget _digest() {
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
                // A door, not a figure — the branch ledger is a longitudinal
                // record, so there is no honest single number to print here.
                // Kept on Home because a mobile manager has no sidebar.
                DigestEntry(
                  icon: Icons.fingerprint_rounded,
                  label: 'Branch attendance',
                  onTap: () => context.push(RouteNames.attendanceReports),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Layout ───────────────────────────────────────────────────────
  //
  // There is **no Quick actions section**. It held Branch tasks · Weekly
  // schedule · Broadcast — and every one of those is already one tap away:
  // the first two are bottom-nav destinations (sidebar + ⌘K on desktop), and
  // Broadcast is the megaphone in the app bar. It was three cards of
  // duplicated navigation at the bottom of an already-long page.
  Widget _activityHeader() => AdminSectionHeader(
    title: 'Recent activity',
    actionLabel: 'See all',
    onAction: () => context.push(RouteNames.managerTasks),
  );

  // Stable keys + a fixed per-section stagger so the entrance plays once and
  // never replays when a conditional section appears. Honours reduced motion.
  Widget _sec(String id, int index, Widget child) {
    if (MediaQuery.of(context).disableAnimations) {
      return KeyedSubtree(key: ValueKey('mgr-sec-$id'), child: child);
    }
    return EntranceFade(
      key: ValueKey('mgr-sec-$id'),
      delay: Duration(milliseconds: (index * 70).clamp(0, 420)),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    // No top-level cubit subscription: each section subscribes to only what it
    // needs via a scoped selector, so a stream emit rebuilds one section.
    return RefreshIndicator(
      onRefresh: () => _load(force: true),
      child: context.isDesktop ? _desktop(context) : _mobile(context),
    );
  }

  Widget _mobile(BuildContext context) {
    var i = 0;
    Widget sec(String id, Widget child) => _sec(id, i++, child);
    return ListView(
      key: const PageStorageKey('manager-home-mobile'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.sm,
        AppSpacing.pagePadding,
        AppSpacing.xxxl,
      ),
      children: [
        sec('hero', _hero()),
        const SizedBox(height: AppSpacing.xl),
        sec('attn-h', const AdminSectionHeader(title: 'Needs attention')),
        sec('attn', _needsAttention()),
        const SizedBox(height: AppSpacing.xl),
        sec('today-h', const AdminSectionHeader(title: 'Today')),
        sec('today', _today()),
        const SizedBox(height: AppSpacing.lg),
        // No header: the card names itself ("on shift today"), so a section
        // label above it would be the same words twice.
        sec('cover', _coverage()),
        const SizedBox(height: AppSpacing.xl),
        sec('activity-h', _activityHeader()),
        sec(
          'activity',
          RecentActivityFeed(branchLocked: true, branchId: _branchId),
        ),
        const SizedBox(height: AppSpacing.xl),
        sec('digest-h', const AdminSectionHeader(title: 'Operations')),
        sec('digest', _digest()),
        // No Recent messages on a phone. Chat is the fourth bottom-nav
        // destination with a full inbox behind it — five conversation previews
        // at the foot of an operations board is the clearest case of the page
        // trying to be every screen at once. It stays on desktop, where the
        // right rail has the room and there is no bottom nav.
      ],
    );
  }

  /// Desktop: the operational story (needs attention → today → coverage →
  /// activity) reads down the wide main column; the launch surfaces sit in a
  /// fixed right rail, always in view. Centred so it reads like a desktop
  /// document rather than a stretched phone screen.
  Widget _desktop(BuildContext context) {
    var i = 0;
    Widget sec(String id, Widget child) => _sec(id, i++, child);
    final hPad = context.isUltrawide ? 48.0 : 40.0;
    return ListView(
      key: const PageStorageKey('manager-home-desktop'),
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
                            const AdminSectionHeader(title: 'Needs attention'),
                          ),
                          sec('attn', _needsAttention()),
                          const SizedBox(height: AppSpacing.xl),
                          sec(
                            'today-h',
                            const AdminSectionHeader(title: 'Today'),
                          ),
                          sec('today', _today()),
                          const SizedBox(height: AppSpacing.lg),
                          sec('cover', _coverage()),
                          const SizedBox(height: AppSpacing.xl),
                          sec('activity-h', _activityHeader()),
                          sec(
                            'activity',
                            RecentActivityFeed(
                              branchLocked: true,
                              branchId: _branchId,
                            ),
                          ),
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
                          // Desktop only — see the mobile layout's note.
                          sec('messages', const RecentMessagesCard()),
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

/// **On shift today** — one card, one tap, into the weekly schedule.
///
/// Replaced four `Team · On today · Morning · Night` stat cells (2026-08-03,
/// owner: *"make the on shift today and today's tasks way more clear and
/// clickable"*). Those printed eight strings to say one thing and **none of
/// them opened anything**, on the half of a manager's job that is entirely
/// about the roster. Here the count on shift is the metric, the team size is
/// its denominator rather than its own cell, and the shift split rides two
/// quiet pills instead of two more label/value pairs.
class _CoverageCard extends StatelessWidget {
  const _CoverageCard({
    required this.onShift,
    required this.team,
    required this.morning,
    required this.night,
    required this.onTap,
  });

  final int onShift;
  final int team;
  final int morning;
  final int night;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    // Nobody rostered is a real operational state, not a blank — say it in
    // words rather than showing a "0 of 8" that reads like a failed load.
    final covered = onShift > 0;
    return Semantics(
      button: true,
      label: '$onShift of $team on shift today',
      child: GlassContainer(
        onTap: onTap,
        borderRadius: AppRadius.lgAll,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withAlpha(22),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.groups_2_outlined,
                size: 19,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      AnimatedCount(
                        value: onShift,
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 650),
                        style: AppTypography.h1.copyWith(
                          fontSize: 26,
                          height: 1.1,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Flexible + ellipsis: the label sits beside a variable
                      // -width count inside a card that also carries a glyph and
                      // a chevron, so on a narrow phone it must be allowed to
                      // give way rather than overflow the row.
                      Flexible(
                        child: Text(
                          covered ? 'of $team on shift today' : 'on shift today',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.label.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (covered)
                    // Wrap, not Row — under large text the two pills drop to a
                    // second line instead of clipping.
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        _ShiftPill(
                          icon: Icons.wb_sunny_outlined,
                          label: '$morning morning',
                        ),
                        _ShiftPill(
                          icon: Icons.nightlight_outlined,
                          label: '$night night',
                        ),
                      ],
                    )
                  else
                    Text(
                      'Nobody is rostered — open the schedule',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// A shift's share of today's cover — glyph + count, hairline only. Never a
/// fill: this is context, and a filled chip would compete with the triage layer.
class _ShiftPill extends StatelessWidget {
  const _ShiftPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textTertiary),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
