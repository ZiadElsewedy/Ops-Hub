import 'dart:async';

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
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/action_card.dart';
import 'package:drop/core/widgets/admin_section_header.dart';
import 'package:drop/core/widgets/animated_count.dart';
import 'package:drop/core/widgets/app_shell.dart';
import 'package:drop/core/widgets/command_palette.dart';
import 'package:drop/core/widgets/responsive_card_grid.dart';
import 'package:drop/core/widgets/app_motion.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/core/widgets/live_list_item.dart';
import 'package:drop/core/widgets/page_hero.dart';
import 'package:drop/core/widgets/stat_strip.dart';
import 'package:drop/features/admin/presentation/dashboard_mood.dart';
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
import 'package:drop/features/task/presentation/widgets/live_status_border.dart';
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

  Widget _syncButton({bool compact = false}) => _SyncButton(
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
                  subtitleWidget: _HeroMood(
                    mood: mood,
                    scope: _scopeLine(s, running),
                  ),
                  primaryAction: _PrimaryCta(
                    icon: Icons.add_rounded,
                    label: 'Create Task',
                    onTap: _createTask,
                  ),
                  trailing: context.isDesktop
                      ? [_syncButton(compact: true), _CommandHint()]
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
            final total = overdue + reviews + unassigned + rejected + swaps;
            final reduceMotion = MediaQuery.of(context).disableAnimations;
            // ONE grouped box, always in the same place. When every queue is
            // empty it's a calm "all clear" summary; the moment anything needs a
            // decision it's the box of triage rows — a fresh signal slides in as
            // a row (never the whole grid re-appearing). A quiet crossfade carries
            // the rare clear ⇄ active flip.
            final Widget child = total == 0
                ? const KeyedSubtree(
                    key: ValueKey('attn-clear'),
                    child: _AllClearPanel(),
                  )
                : KeyedSubtree(
                    key: const ValueKey('attn-active'),
                    child: _needsAttentionBox(
                      reviews: reviews,
                      overdue: overdue,
                      unassigned: unassigned,
                      rejected: rejected,
                      swaps: swaps,
                    ),
                  );
            if (reduceMotion) return child;
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: child,
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

  /// The grouped Needs-attention box (active state — at least one signal has
  /// work). One `GlassContainer` of triage rows wrapped in a **single** living
  /// border; a fresh signal slides in as a row (`LiveListItem` keyed reuse), the
  /// cleared signals collapse to a quiet footer, and the box's orbit reads the
  /// most-urgent signal's tone (overdue → orange pulse, else the calm accent).
  Widget _needsAttentionBox({
    required int reviews,
    required int overdue,
    required int unassigned,
    required int rejected,
    required int swaps,
  }) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    // Fixed urgency ranking (lower = more urgent).
    final all = <_Signal>[
      _Signal(
        key: 'overdue',
        rank: 0,
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
      _Signal(
        key: 'reviews',
        rank: 1,
        count: reviews,
        accent: AppColors.warning,
        icon: Icons.rate_review_outlined,
        label: 'Pending review',
        sublabel: 'Approve or send back',
        onTap: () => context.push(RouteNames.adminReview),
      ),
      _Signal(
        key: 'rejected',
        rank: 2,
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
      _Signal(
        key: 'unassigned',
        rank: 3,
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
      _Signal(
        key: 'swaps',
        rank: 4,
        count: swaps,
        accent: AppColors.warning,
        icon: Icons.swap_horiz_rounded,
        label: 'Swap requests',
        sublabel: 'Review shift swaps',
        onTap: _openSwaps,
      ),
    ];

    final active = all.where((s) => s.count > 0).toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));
    final cleared = all.where((s) => s.count == 0).toList();
    // Caller only builds this box when something is active, but guard anyway.
    if (active.isEmpty) return const _AllClearPanel();
    final overdueLead = active.first.accent == AppColors.error;

    final rows = <Widget>[
      for (final (i, s) in active.indexed)
        if (reduceMotion)
          KeyedSubtree(
            key: ValueKey('attn-row-${s.key}'),
            child: _attnRow(s, first: i == 0),
          )
        else
          LiveListItem(
            key: ValueKey('attn-row-${s.key}'),
            entranceDelay: Duration(milliseconds: (i * 45).clamp(0, 180)),
            highlightRadius: 12,
            child: _attnRow(s, first: i == 0),
          ),
    ];

    final box = GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Only the row set resizes when a signal arrives/clears, so the box
          // grows/shrinks smoothly instead of snapping.
          AnimatedSize(
            duration:
                reduceMotion ? Duration.zero : const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: rows,
            ),
          ),
          if (cleared.isNotEmpty) _attnFooter(cleared),
        ],
      ),
    );

    if (reduceMotion) return box;
    // One unified orbit around the whole box (not five scattered borders),
    // reading the most-urgent signal's tone.
    return LiveStatusBorder(
      color: overdueLead ? const Color(0xFFFB923C) : kLivingBorderAccent,
      pulse: overdueLead,
      speed: 1.1,
      borderRadius: AppRadius.cardAll,
      child: box,
    );
  }

  /// One triage row inside the grouped box: tinted glyph · label + sublabel ·
  /// count (counts up) · chevron. Tapping drills to that signal's filtered view.
  Widget _attnRow(_Signal s, {required bool first}) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!first)
          const Divider(
            height: 1,
            thickness: 1,
            color: AppColors.darkBorder,
            indent: AppSpacing.md,
            endIndent: AppSpacing.md,
          ),
        Semantics(
          button: true,
          label: '${s.count} ${s.label}',
          child: InkWell(
            onTap: s.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: s.accent.withAlpha(34),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: s.accent.withAlpha(60)),
                    ),
                    child: Icon(s.icon, size: 20, color: s.accent),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Row title reads white (the "what"); its sublabel steps
                        // down to medium grey.
                        Text(
                          s.label,
                          style: AppTypography.label.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          s.sublabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  AnimatedCount(
                    value: s.count,
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 650),
                    style: AppTypography.h2.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: AppColors.textPrimary,
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
          ),
        ),
      ],
    );
  }

  /// The quiet footer naming the cleared signals ("sent back · unassigned ·
  /// swaps — all clear"), so a healthy queue is visible without five empty rows.
  Widget _attnFooter(List<_Signal> cleared) {
    final names = cleared.map((s) => s.label.toLowerCase()).join(' · ');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(
          height: 1,
          thickness: 1,
          color: AppColors.darkBorder,
          indent: AppSpacing.md,
          endIndent: AppSpacing.md,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 10, AppSpacing.md, 8),
          child: Row(
            children: [
              const Icon(
                Icons.check_rounded,
                size: 15,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$names — all clear',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
                return GlassContainer(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xs,
                  ),
                  child: Column(
                    children: [
                      _DigestRow(
                        icon: Icons.assignment_turned_in_outlined,
                        label: 'Pending requests',
                        value: '$pendingReq',
                        accent: pendingReq > 0
                            ? AppColors.warning
                            : AppColors.textTertiary,
                        onTap: () => context.push(RouteNames.requests),
                      ),
                      const Divider(color: AppColors.darkBorder, height: 1),
                      _DigestRow(
                        icon: Icons.forum_outlined,
                        label: 'Active cases',
                        value: '$activeCases',
                        accent: activeCases > 0
                            ? AppColors.warning
                            : AppColors.textTertiary,
                        onTap: () => context.push(RouteNames.cases),
                      ),
                      const Divider(color: AppColors.darkBorder, height: 1),
                      _DigestRow(
                        icon: Icons.calendar_view_week_outlined,
                        label: 'Schedule coverage',
                        value: '$scheduled/$totalBranches',
                        accent: AppColors.textSecondary,
                        onTap: () => context.push(RouteNames.adminSchedule),
                      ),
                    ],
                  ),
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

// ─── Primary CTA ────────────────────────────────────────────────────

/// The single, prominent primary action of the hero — a filled monochrome
/// button (white accent · dark label). The V2 "one primary action" rule: every
/// module hero has at most one of these. It carries a soft key-light shadow so
/// it reads as *the* action, and responds to hover (a whisper of lift) and press
/// (a subtle scale) — the tactile feedback of a premium control.
class _PrimaryCta extends StatefulWidget {
  const _PrimaryCta({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_PrimaryCta> createState() => _PrimaryCtaState();
}

class _PrimaryCtaState extends State<_PrimaryCta> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final lifted = _hovered && !reduceMotion;
    return Semantics(
      button: true,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(0, lifted ? -1 : 0, 0),
              transformAlignment: Alignment.center,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: lifted ? AppColors.accentHover : AppColors.accent,
                borderRadius: AppRadius.buttonAll,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withAlpha(lifted ? 90 : 55),
                    blurRadius: lifted ? 22 : 14,
                    offset: Offset(0, lifted ? 8 : 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: 18, color: AppColors.onAccent),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    widget.label,
                    style: AppTypography.label.copyWith(
                      color: AppColors.onAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Hero mood ──────────────────────────────────────────────────────

/// The hero's contextual subtitle: a breathing "system live" pulse dot, the
/// [DashboardMood] sentence (white + bold when it wants the eye, a relaxed light
/// grey when the board is calm), and the quiet operational scope beneath it.
class _HeroMood extends StatelessWidget {
  const _HeroMood({required this.mood, required this.scope});

  final DashboardMood mood;
  final String scope;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _LivePulseDot(color: mood.pulseColor),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                mood.headline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body.copyWith(
                  color: mood.emphasised
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight:
                      mood.emphasised ? FontWeight.w600 : FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          scope,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
        ),
      ],
    );
  }
}

/// A small "the system is alive" indicator — a solid dot with a soft halo and a
/// slow expanding ring that fades outward (like a live/heartbeat pin). The ring
/// is purely reassuring motion; under reduced motion it collapses to a static
/// glowing dot so it never distracts or spins forever for no reason.
class _LivePulseDot extends StatefulWidget {
  const _LivePulseDot({required this.color});

  final Color color;

  @override
  State<_LivePulseDot> createState() => _LivePulseDotState();
}

class _LivePulseDotState extends State<_LivePulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  bool _animating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.of(context).disableAnimations;
    if (!reduce && !_animating) {
      _animating = true;
      _c.repeat();
    } else if (reduce && _animating) {
      _animating = false;
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static const double _core = 8;

  Widget _dot() => Container(
        width: _core,
        height: _core,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
          boxShadow: [
            BoxShadow(color: widget.color.withAlpha(120), blurRadius: 6),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (!_animating) return _dot();
    // Isolate the forever-running ring in its own layer so each frame repaints
    // only this 18px box, never the hero around it.
    return RepaintBoundary(
      child: SizedBox(
        width: 18,
        height: 18,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = Curves.easeOut.transform(_c.value);
            final ringSize = _core * (1 + t * 1.1);
            final ringAlpha = ((1 - t) * 80).round();
            return Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: ringSize,
                  height: ringSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withAlpha(ringAlpha),
                  ),
                ),
                _dot(),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Operations digest row ──────────────────────────────────────────

class _DigestRow extends StatelessWidget {
  const _DigestRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$value $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withAlpha(28),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: AppSpacing.md),
              // Row label is a supporting label (light grey); the count is the
              // metric and reads white when there's work to do.
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.label.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                value,
                style: AppTypography.label.copyWith(
                  fontWeight: FontWeight.w700,
                  color: accent == AppColors.textTertiary
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Decorative affordance → medium grey (a step below the label).
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The desktop "Search or run a command ⌘K" pill — mirrors the shell shortcut
/// so the palette is discoverable, not just known.
class _CommandHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = context.currentUser;
    if (user == null) return const SizedBox.shrink();
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => showCommandPalette(
          context,
          user: user,
          sections: AppShell.sectionsForRole(user.role),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.search_rounded,
                size: 15,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Search or run a command',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.darkBorder),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '⌘K',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Sync control ───────────────────────────────────────────────────

/// Relative "last synced" label for the dashboard [_SyncButton]. Pure with an
/// injectable clock so it's unit-testable.
String syncLabel(DateTime? lastSynced, {DateTime? now}) {
  if (lastSynced == null) return 'Sync';
  final d = (now ?? DateTime.now()).difference(lastSynced);
  if (d.inSeconds < 45) return 'Synced just now';
  if (d.inMinutes < 60) return 'Synced ${d.inMinutes}m ago';
  if (d.inHours < 24) return 'Synced ${d.inHours}h ago';
  return 'Synced ${d.inDays}d ago';
}

/// A premium **Sync** control for the dashboard header. Rotates while a refresh
/// is in flight and otherwise shows how long ago the live data was last pulled;
/// tapping force-refreshes the live sources. Desktop shows a labelled pill;
/// mobile shows an icon-only tap target next to the greeting.
class _SyncButton extends StatefulWidget {
  const _SyncButton({
    required this.syncing,
    required this.lastSynced,
    required this.onSync,
    this.compact = false,
  });

  final bool syncing;
  final DateTime? lastSynced;
  final VoidCallback onSync;
  final bool compact;

  @override
  State<_SyncButton> createState() => _SyncButtonState();
}

class _SyncButtonState extends State<_SyncButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  Timer? _ticker;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    if (widget.syncing) _spin.repeat();
    // Keep the "3m ago" label honest without leaning on a parent rebuild.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant _SyncButton old) {
    super.didUpdateWidget(old);
    if (widget.syncing == old.syncing) return;
    if (widget.syncing) {
      _spin.repeat();
    } else {
      // Let the current turn finish for a smooth stop, then settle to rest.
      _spin
          .animateTo(1, duration: const Duration(milliseconds: 220))
          .whenComplete(() {
            if (mounted) _spin.reset();
          });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.syncing ? 'Syncing…' : syncLabel(widget.lastSynced);
    final onTap = widget.syncing ? null : widget.onSync;
    final icon = RotationTransition(
      turns: _spin,
      child: Icon(
        Icons.sync_rounded,
        size: 15,
        color: widget.syncing ? AppColors.textPrimary : AppColors.textSecondary,
      ),
    );

    if (widget.compact) {
      return Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Center(child: icon),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: label,
      child: MouseRegion(
        cursor: onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _hovered ? AppColors.textTertiary : AppColors.darkBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                const SizedBox(width: 8),
                Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Needs-attention signal ─────────────────────────────────────────

/// One triage signal in the grouped Needs-attention box — its urgency [rank],
/// live [count], semantic [accent], glyph, copy, and the drill it opens.
class _Signal {
  const _Signal({
    required this.key,
    required this.rank,
    required this.count,
    required this.accent,
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.onTap,
  });

  final String key;
  final int rank;
  final int count;
  final Color accent;
  final IconData icon;
  final String label;
  final String sublabel;
  final VoidCallback onTap;
}

// ─── All clear (needs-attention cleared) ────────────────────────────

/// The Needs-attention layer when **every** queue is empty — one reassuring
/// summary instead of a grid of switched-off tiles. A large success check, a
/// positive sentence, and a muted inline row of the zeroed facts, so a healthy
/// board reads *under control* rather than merely blank.
class _AllClearPanel extends StatelessWidget {
  const _AllClearPanel();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'All clear. Nothing needs your attention right now.',
      child: GlassContainer(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A large, calm success check — the board's own state is "healthy",
            // the one place a status colour earns its place on this screen.
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha(28),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: AppColors.success.withAlpha(60)),
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 28,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('All clear', style: AppTypography.h3),
                  const SizedBox(height: 3),
                  // Reassuring sentence → light grey, a clear step under the title.
                  Text(
                    'Nothing needs you right now — every queue is empty.',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // The zeroed facts, quiet and inline (medium grey) — proof the
                  // calm state is real, not a failed load.
                  Text(
                    '0 pending review · 0 late · 0 unassigned · '
                    '0 sent back · 0 swaps',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
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
}
