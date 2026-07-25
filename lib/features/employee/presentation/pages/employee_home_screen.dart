import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/app_glass_card.dart';
import 'package:drop/core/widgets/app_motion.dart';
import 'package:drop/core/widgets/premium_button.dart';
import 'package:drop/core/widgets/skeleton.dart';
import 'package:drop/core/widgets/user_avatar.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/schedule/domain/entities/shift_swap_entity.dart';
import 'package:drop/features/schedule/presentation/cubit/shift_swap_cubit.dart';
import 'package:drop/features/schedule/presentation/cubit/shift_swap_state.dart';
import 'package:drop/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:drop/features/chat/presentation/widgets/recent_messages_card.dart';
import 'package:drop/features/statistics/domain/entities/statistics_entity.dart';
import 'package:drop/features/statistics/presentation/cubit/statistics_cubit.dart';
import 'package:drop/features/statistics/presentation/cubit/statistics_state.dart';
import 'package:drop/features/task/domain/active_window.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/task/presentation/cubit/task_state.dart';
import 'package:drop/features/task/presentation/pages/task_details_screen.dart';
import 'package:drop/features/task/presentation/widgets/live_status_border.dart';
import 'package:drop/features/task/presentation/widgets/task_card.dart';

/// Redesigned employee home — a personal operations command center.
///
/// Time-aware greeting, an animated "Today" hero (a sweeping progress ring +
/// today's shift), a live count-up breakdown strip, and a live, **actionable**
/// task list right on the home page: an employee can start a task inline,
/// continue one in progress, or jump into a rejected one's feedback without
/// leaving Home. Everything fades/lifts in with a gentle stagger; the ring
/// sweeps and the numbers count up. Stays strictly monochrome — colour is used
/// only to signal status.
class EmployeeHomeScreen extends StatefulWidget {
  const EmployeeHomeScreen({super.key});

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  // Last good snapshot — keeps the dashboard visible through the transient
  // loading/error states a mutation emits (no flicker on inline actions).
  List<TaskEntity>? _cachedTasks;
  Map<String, UserEntity> _cachedDir = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load({bool force = false}) {
    final user = context.currentUser;
    if (user != null) {
      context.read<StatisticsCubit>().load(user, forceRefresh: force);
      context.read<TaskCubit>().load(user, forceRefresh: force);
      // Surface this employee's swap requests right here on Home — both the ones
      // a coworker is waiting on them to accept/reject, and their own in-flight
      // requests. (Previously only reachable inside Schedule → Swaps.)
      context.read<ShiftSwapCubit>().loadMine(user.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthCubit, UserEntity?>(
      (c) => c.state.maybeWhen(authenticated: (u) => u, orElse: () => null),
    );
    final now = DateTime.now();

    return MultiBlocListener(
      // Only surface errors while Home is the visible route — otherwise a pushed
      // screen (Task Details) already shows them.
      listeners: [
        BlocListener<TaskCubit, TaskState>(
          listener: (context, state) {
            if (ModalRoute.of(context)?.isCurrent != true) return;
            state.whenOrNull(error: (m) => context.showError(m));
          },
        ),
        BlocListener<ShiftSwapCubit, ShiftSwapState>(
          listener: (context, state) {
            if (ModalRoute.of(context)?.isCurrent != true) return;
            state.whenOrNull(error: (m) => context.showError(m));
          },
        ),
      ],
      child: RefreshIndicator(
        onRefresh: () async => _load(force: true),
        color: AppColors.primary,
        backgroundColor: AppColors.darkSurface,
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            EntranceFade(
              child: _GreetingSection(user: user, now: now),
            ),

            // Swap requests — surfaced prominently (only appears when there's one
            // needing this employee's action or one of their own in flight).
            if (user != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pagePadding,
                ),
                child: _SwapRequestsSection(uid: user.uid),
              ),

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pagePadding,
              ),
              child: BlocBuilder<TaskCubit, TaskState>(
                builder: (context, state) {
                  final snap = state.maybeWhen(
                    loaded: (tasks, busy, directory, _, _) {
                      _cachedTasks = tasks;
                      _cachedDir = directory;
                      return (tasks: tasks, busy: busy, directory: directory);
                    },
                    orElse: () => _cachedTasks == null
                        ? null
                        : (
                            tasks: _cachedTasks!,
                            busy: false,
                            directory: _cachedDir,
                          ),
                  );
                  if (snap == null) return const _HomeShimmer();
                  return _Dashboard(
                    tasks: snap.tasks,
                    busy: snap.busy,
                    directory: snap.directory,
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pagePadding,
                AppSpacing.xl,
                AppSpacing.pagePadding,
                0,
              ),
              child: EntranceFade(
                delay: staggerDelay(4),
                child: const RecentMessagesCard(),
              ),
            ),

            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}

// ─── Task counts (computed from the live list — the ground truth) ─────

class _Counts {
  final int pending, started, inReview, approved, completed, rejected;
  const _Counts({
    this.pending = 0,
    this.started = 0,
    this.inReview = 0,
    this.approved = 0,
    this.completed = 0,
    this.rejected = 0,
  });

  factory _Counts.from(List<TaskEntity> tasks) {
    var p = 0, s = 0, r = 0, a = 0, c = 0, rej = 0;
    for (final t in tasks) {
      switch (t.status) {
        case TaskStatus.pending:
          p++;
        case TaskStatus.started:
          s++;
        case TaskStatus.waitingReview:
          r++;
        case TaskStatus.approved:
          a++;
        case TaskStatus.completed:
          c++;
        case TaskStatus.rejected:
          rej++;
        case TaskStatus.missed:
          // A missed task is closed and must not affect today's active-work
          // progress, even when this count helper is called with a broad list.
          break;
      }
    }
    return _Counts(
      pending: p,
      started: s,
      inReview: r,
      approved: a,
      completed: c,
      rejected: rej,
    );
  }

  int get total =>
      pending + started + inReview + approved + completed + rejected;

  /// Work the employee has handled (done or handed off for review).
  int get finished => approved + completed + inReview;

  /// Work still needing the employee's hands.
  int get open => pending + started + rejected;

  double get progress => total == 0 ? 0 : finished / total;
}

// ─── Dashboard (ring hero + strip + sections) ────────────────────────

class _Dashboard extends StatelessWidget {
  const _Dashboard({
    required this.tasks,
    required this.busy,
    required this.directory,
  });

  final List<TaskEntity> tasks;
  final bool busy;
  final Map<String, UserEntity> directory;

  @override
  Widget build(BuildContext context) {
    // Counts reflect only the current operational window — outstanding work plus
    // work finished *today* — so historically-approved tasks don't inflate the
    // ring forever (the old "Done 4 / 4" that never reset). The task sections
    // below only render in-window statuses anyway, so they use the full list.
    final counts = _Counts.from(activeWindowTasks(tasks, DateTime.now()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EntranceFade(
          delay: staggerDelay(1),
          child: _HeroTodayCard(counts: counts),
        ),
        const SizedBox(height: AppSpacing.lg),
        EntranceFade(
          delay: staggerDelay(2),
          child: _StatStrip(counts: counts),
        ),
        const SizedBox(height: AppSpacing.xl),
        EntranceFade(
          delay: staggerDelay(3),
          child: _TaskSection(tasks: tasks, busy: busy, directory: directory),
        ),
      ],
    );
  }
}

// ─── Greeting ────────────────────────────────────────────────────────

class _GreetingSection extends StatelessWidget {
  const _GreetingSection({required this.user, required this.now});

  final UserEntity? user;
  final DateTime now;

  String get _greetingWord {
    final h = now.hour;
    if (h >= 5 && h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _firstName {
    final name = user?.displayName ?? '';
    if (name.isEmpty) return '';
    return name.split(' ').first;
  }

  String get _dateLabel {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[now.weekday - 1]}, ${AppDateFormatter.dayMonth(now)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDay = now.hour >= 6 && now.hour < 19;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.lg,
        AppSpacing.pagePadding,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isDay ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
                  size: 12,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  _dateLabel.toUpperCase(),
                  style: AppTypography.caption.copyWith(
                    letterSpacing: 1.3,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '$_greetingWord,',
            style: AppTypography.body.copyWith(
              color: AppColors.textSecondary,
              height: 1.1,
            ),
          ),
          if (_firstName.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              _firstName,
              style: AppTypography.display.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -1.8,
                height: 1.0,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── "Today" hero — progress ring + shift ────────────────────────────

class _HeroTodayCard extends StatelessWidget {
  const _HeroTodayCard({required this.counts});
  final _Counts counts;

  String get _summary {
    if (counts.open > 0) {
      final base = '${counts.open} to do';
      return counts.inReview > 0
          ? '$base · ${counts.inReview} in review'
          : base;
    }
    if (counts.inReview > 0) return '${counts.inReview} in review';
    if (counts.total > 0) return 'All caught up';
    return 'Nothing assigned yet';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: AppGlassCard(
        child: Row(
          children: [
            _ProgressRing(
              finished: counts.finished,
              total: counts.total,
              size: 92,
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _ShiftBlock(),
                  const SizedBox(height: AppSpacing.md),
                  _SummaryPill(text: _summary, active: counts.open > 0),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShiftBlock extends StatelessWidget {
  const _ShiftBlock();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StatisticsCubit, StatisticsState>(
      builder: (context, state) => state.maybeWhen(
        loaded: (s) => _content(s),
        orElse: () => const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(
              width: 72,
              height: 9,
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
            SizedBox(height: 8),
            Skeleton(
              width: 120,
              height: 18,
              borderRadius: BorderRadius.all(Radius.circular(6)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(StatisticsEntity s) {
    final off = s.currentShiftName == null || s.currentShiftName!.isEmpty;
    final isMorning = s.currentShiftName == 'morning';
    final label = off
        ? 'Off today'
        : isMorning
        ? 'Morning shift'
        : 'Night shift';
    final icon = off
        ? Icons.self_improvement_outlined
        : isMorning
        ? Icons.wb_sunny_outlined
        : Icons.nightlight_outlined;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "TODAY'S SHIFT",
          style: AppTypography.caption.copyWith(
            letterSpacing: 1.1,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textPrimary),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                style: AppTypography.h3,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (s.upcomingShiftName != null && s.upcomingShiftName!.isNotEmpty) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(
                Icons.arrow_forward_rounded,
                size: 11,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Next: ${s.upcomingShiftName}',
                  style: AppTypography.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.text, required this.active});
  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? AppColors.primarySurface : AppColors.darkSurface,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: active
              ? AppColors.primary.withAlpha(38)
              : AppColors.darkBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? AppColors.primary : AppColors.success,
            ),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              text,
              style: AppTypography.labelSmall.copyWith(
                color: active ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Animated progress ring ──────────────────────────────────────────

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({
    required this.finished,
    required this.total,
    required this.size,
  });

  final int finished;
  final int total;
  final double size;

  @override
  Widget build(BuildContext context) {
    final target = total == 0 ? 0.0 : finished / total;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: target),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          final shown = (value * total).round();
          return CustomPaint(
            painter: _RingPainter(
              progress: value,
              track: AppColors.darkBorder,
              arc: AppColors.primary,
              stroke: 7,
            ),
            child: Center(
              child: total == 0
                  ? const Icon(
                      Icons.check_rounded,
                      size: 22,
                      color: AppColors.textTertiary,
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$shown',
                          style: AppTypography.h2.copyWith(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            height: 1.0,
                          ),
                        ),
                        Text(
                          'of $total',
                          style: AppTypography.caption.copyWith(fontSize: 10),
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.track,
    required this.arc,
    required this.stroke,
  });

  final double progress;
  final Color track;
  final Color arc;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect =
        Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(rect, 0, 2 * math.pi, false, trackPaint);

    if (progress > 0) {
      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = arc;
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.arc != arc || old.track != track;
}

// ─── Stat strip ──────────────────────────────────────────────────────

class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.counts});
  final _Counts counts;

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatChipData(
        label: 'To do',
        value: counts.pending,
        icon: Icons.radio_button_unchecked_rounded,
        highlight: counts.pending > 0,
      ),
      _StatChipData(
        label: 'Active',
        value: counts.started,
        icon: Icons.timelapse_rounded,
        highlight: counts.started > 0,
      ),
      _StatChipData(
        label: 'In review',
        value: counts.inReview,
        icon: Icons.hourglass_top_rounded,
        highlight: false,
      ),
      _StatChipData(
        label: 'Done',
        value: counts.approved + counts.completed,
        icon: Icons.check_circle_outline_rounded,
        highlight: false,
      ),
    ];

    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(child: _StatChip(data: items[i])),
        ],
      ],
    );
  }
}

class _StatChipData {
  final String label;
  final int value;
  final IconData icon;
  final bool highlight;
  const _StatChipData({
    required this.label,
    required this.value,
    required this.icon,
    required this.highlight,
  });
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.data});
  final _StatChipData data;

  @override
  Widget build(BuildContext context) {
    final hl = data.highlight;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: hl ? AppColors.primarySurface : AppColors.darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hl ? AppColors.primary.withAlpha(40) : AppColors.darkBorder,
        ),
      ),
      child: Column(
        children: [
          Icon(
            data.icon,
            size: 15,
            color: hl ? AppColors.textPrimary : AppColors.textTertiary,
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: data.value.toDouble()),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Text(
              '${v.round()}',
              style: AppTypography.h2.copyWith(
                fontSize: 19,
                color: hl ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            data.label,
            style: AppTypography.caption.copyWith(
              fontSize: 10,
              color: hl ? AppColors.textSecondary : AppColors.textTertiary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Task section ────────────────────────────────────────────────────

class _TaskSection extends StatelessWidget {
  const _TaskSection({
    required this.tasks,
    required this.busy,
    required this.directory,
  });

  final List<TaskEntity> tasks;
  final bool busy;
  final Map<String, UserEntity> directory;

  static bool _isActive(TaskEntity t) =>
      t.status == TaskStatus.pending || t.status == TaskStatus.started;
  static bool _isRejected(TaskEntity t) => t.status == TaskStatus.rejected;
  static bool _isReview(TaskEntity t) => t.status == TaskStatus.waitingReview;
  static bool _isMissedToday(TaskEntity t, DateTime now) {
    if (t.status != TaskStatus.missed) return false;
    final at = t.missedAt ?? t.deadline ?? t.updatedAt ?? t.createdAt;
    return at == null || _isSameDay(at, now);
  }

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const _EmptyTaskState();

    final now = DateTime.now();
    final rejected = tasks.where(_isRejected).toList();
    final inReview = tasks.where(_isReview).toList();
    final missed = tasks.where((t) => _isMissedToday(t, now)).toList();
    final active = tasks.where(_isActive).toList()
      ..sort((a, b) {
        // Started first, then by soonest deadline.
        final byStatus = (b.status == TaskStatus.started ? 1 : 0).compareTo(
          a.status == TaskStatus.started ? 1 : 0,
        );
        if (byStatus != 0) return byStatus;
        final ad = a.deadline, bd = b.deadline;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      });

    final preview = active.take(3).toList();
    final remaining = (active.length - preview.length).clamp(0, 999);

    if (active.isEmpty &&
        rejected.isEmpty &&
        inReview.isEmpty &&
        missed.isEmpty) {
      return const _AllDoneCard();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (rejected.isNotEmpty) ...[
          _SectionRow(
            label: 'Needs attention',
            count: rejected.length,
            color: AppColors.error,
            icon: Icons.replay_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < rejected.length; i++)
            EntranceFade(
              delay: Duration(milliseconds: i * 50),
              child: _HomeTaskCard(
                task: rejected[i],
                directory: directory,
                busy: busy,
                onOpen: () => _openTask(context, rejected[i]),
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
        ],
        if (inReview.isNotEmpty) ...[
          _SectionRow(
            label: 'Submitted',
            count: inReview.length,
            icon: Icons.hourglass_top_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < inReview.length; i++)
            EntranceFade(
              delay: Duration(milliseconds: i * 50),
              child: _HomeTaskCard(
                task: inReview[i],
                directory: directory,
                busy: busy,
                onOpen: () => _openTask(context, inReview[i]),
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
        ],
        if (missed.isNotEmpty) ...[
          _SectionRow(
            label: 'Missed',
            count: missed.length,
            color: AppColors.error,
            icon: Icons.event_busy_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < missed.length; i++)
            EntranceFade(
              delay: Duration(milliseconds: i * 50),
              child: _HomeTaskCard(
                task: missed[i],
                directory: directory,
                busy: busy,
                onOpen: () => _openTask(context, missed[i]),
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
        ],
        if (active.isNotEmpty) ...[
          _SectionRow(
            label: 'Up next',
            count: active.length,
            icon: Icons.bolt_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < preview.length; i++)
            EntranceFade(
              delay: Duration(milliseconds: i * 60),
              child: _HomeTaskCard(
                task: preview[i],
                directory: directory,
                busy: busy,
                onOpen: () => _openTask(context, preview[i]),
                onStart: preview[i].status == TaskStatus.pending
                    ? () => context.read<TaskCubit>().startTask(preview[i])
                    : null,
              ),
            ),
          if (remaining > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            _ViewAllRow(
              label: 'View $remaining more task${remaining == 1 ? '' : 's'}',
            ),
          ],
        ],
        const SizedBox(height: AppSpacing.lg),
        const _ViewAllRow(label: 'Open all tasks', emphasized: true),
      ],
    );
  }

  void _openTask(BuildContext context, TaskEntity task) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (ctx, anim, _) =>
            TaskDetailsScreen(task: task, directory: directory),
        transitionsBuilder: (ctx, anim, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.03), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                ),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 280),
      ),
    );
  }
}

// ─── Section header row ──────────────────────────────────────────────

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.label,
    required this.count,
    required this.icon,
    this.color,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.textTertiary;
    return Row(
      children: [
        Icon(icon, size: 14, color: accent),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label.toUpperCase(),
          style: AppTypography.caption.copyWith(
            color: color ?? AppColors.textTertiary,
            letterSpacing: 0.9,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: AppColors.darkSurfaceElevated,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$count',
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Home task card (rich + actionable) ──────────────────────────────

class _HomeTaskCard extends StatelessWidget {
  const _HomeTaskCard({
    required this.task,
    required this.directory,
    required this.busy,
    required this.onOpen,
    this.onStart,
  });

  final TaskEntity task;
  final Map<String, UserEntity> directory;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final isStarted = task.status == TaskStatus.started;
    final isRejected = task.status == TaskStatus.rejected;
    final isReview = task.status == TaskStatus.waitingReview;
    final isMissed = task.status == TaskStatus.missed;

    final assignedBy = directory[task.createdBy]?.displayName;

    // Live-activity sweep (NOT status — the pill owns status). Only actionable
    // states animate; the margin sits outside the wrapper so the sweep tracks
    // the card border, not the inter-card gap.
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: LiveStatusBorder(
        color: liveActivityColor(task),
        speed: liveOrbitSpeed(task),
        pulse: taskOverdue(task),
        borderRadius: AppRadius.cardAll,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: AppRadius.cardAll,
            border: Border.all(
              color: isStarted
                  ? AppColors.primary.withAlpha(45)
                  : isRejected || isMissed
                  ? AppColors.error.withAlpha(45)
                  : AppColors.darkBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Pressable(
                onTap: onOpen,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              style: AppTypography.label.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _StatusPill(task.status),
                        ],
                      ),
                      if ((task.description ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          task.description!,
                          style: AppTypography.caption.copyWith(height: 1.4),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (task.hasChecklist) ...[
                        const SizedBox(height: AppSpacing.md),
                        _ChecklistProgressRow(task: task),
                      ],
                      if (task.deadline != null ||
                          assignedBy != null ||
                          (isRejected &&
                              (task.reviewNotes ?? '').isNotEmpty)) ...[
                        const SizedBox(height: AppSpacing.md),
                        _MetaRow(task: task, assignedBy: assignedBy),
                      ],
                    ],
                  ),
                ),
              ),
              _CardFooter(
                task: task,
                busy: busy,
                onOpen: onOpen,
                onStart: onStart,
                isStarted: isStarted,
                isRejected: isRejected,
                isReview: isReview,
                isMissed: isMissed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Card footer action ──────────────────────────────────────────────

class _CardFooter extends StatelessWidget {
  const _CardFooter({
    required this.task,
    required this.busy,
    required this.onOpen,
    required this.onStart,
    required this.isStarted,
    required this.isRejected,
    required this.isReview,
    required this.isMissed,
  });

  final TaskEntity task;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback? onStart;
  final bool isStarted;
  final bool isRejected;
  final bool isReview;
  final bool isMissed;

  @override
  Widget build(BuildContext context) {
    final Widget action;
    if (isMissed) {
      action = const _MutedFooter(
        icon: Icons.event_busy_rounded,
        label: 'Missed — task closed',
      );
    } else if (isReview) {
      action = const _MutedFooter(
        icon: Icons.hourglass_top_rounded,
        label: 'Awaiting review',
      );
    } else if (onStart != null) {
      action = _ActionButton(
        icon: Icons.play_arrow_rounded,
        label: 'Start task',
        primary: true,
        onTap: busy ? null : onStart!,
      );
    } else if (isStarted) {
      action = _ActionButton(
        icon: Icons.arrow_forward_rounded,
        label: 'Continue',
        onTap: onOpen,
      );
    } else if (isRejected) {
      action = _ActionButton(
        icon: Icons.feedback_outlined,
        label: 'View feedback',
        onTap: onOpen,
      );
    } else {
      action = _ActionButton(
        icon: Icons.arrow_forward_rounded,
        label: 'Open',
        onTap: onOpen,
      );
    }

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.darkBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: action,
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    // Right-aligned card action, now on the canonical PremiumButton (filled for
    // the primary "Start task" CTA, tonal otherwise).
    return Align(
      alignment: Alignment.centerRight,
      child: PremiumButton(
        label: label,
        icon: icon,
        onPressed: onTap,
        style: primary ? PremiumButtonStyle.filled : PremiumButtonStyle.tonal,
      ),
    );
  }
}

class _MutedFooter extends StatelessWidget {
  const _MutedFooter({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.warning),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Status pill ─────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);
  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      TaskStatus.pending => ('Pending', AppColors.textSecondary),
      TaskStatus.started => ('In progress', AppColors.textPrimary),
      TaskStatus.completed => ('Done', AppColors.success),
      TaskStatus.waitingReview => ('In review', AppColors.warning),
      TaskStatus.approved => ('Approved', AppColors.success),
      TaskStatus.rejected => ('Rejected', AppColors.error),
      TaskStatus.missed => ('Missed', AppColors.error),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withAlpha(45)),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}

// ─── Checklist progress ──────────────────────────────────────────────

class _ChecklistProgressRow extends StatelessWidget {
  const _ChecklistProgressRow({required this.task});
  final TaskEntity task;

  @override
  Widget build(BuildContext context) {
    final done = task.checklistDone;
    final total = task.checklistTotal;
    final progress = task.checklistProgress;
    final complete = done == total;

    return Row(
      children: [
        Icon(
          complete ? Icons.check_circle_rounded : Icons.checklist_rounded,
          size: 13,
          color: complete ? AppColors.success : AppColors.textTertiary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 4,
                backgroundColor: AppColors.darkSurfaceElevated,
                valueColor: AlwaysStoppedAnimation(
                  complete ? AppColors.success : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '$done/$total',
          style: AppTypography.caption.copyWith(
            color: complete ? AppColors.success : AppColors.textTertiary,
            fontWeight: FontWeight.w700,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

// ─── Meta row (due + assigned-by + reject note) ──────────────────────

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.task, required this.assignedBy});
  final TaskEntity task;
  final String? assignedBy;

  bool get _overdue {
    final d = task.deadline;
    if (d == null) return false;
    return !task.status.isTerminal &&
        task.status != TaskStatus.completed &&
        task.status != TaskStatus.waitingReview &&
        d.isBefore(DateTime.now());
  }

  String _relativeDue(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(d.year, d.month, d.day);
    final diff = due.difference(today).inDays;
    if (diff < 0) return 'Overdue';
    if (diff == 0) return 'Due today';
    if (diff == 1) return 'Due tomorrow';
    if (diff < 7) return 'Due in ${diff}d';
    return 'Due ${AppDateFormatter.dayMonth(d)}';
  }

  @override
  Widget build(BuildContext context) {
    final deadline = task.deadline;
    final rejected = task.status == TaskStatus.rejected;
    final reviewNote = task.reviewNotes;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (deadline != null)
          _MetaChip(
            icon: _overdue
                ? Icons.warning_amber_rounded
                : Icons.schedule_outlined,
            label: _relativeDue(deadline),
            color: _overdue ? AppColors.error : AppColors.textTertiary,
          ),
        if (assignedBy != null && assignedBy!.isNotEmpty)
          _MetaChip(
            icon: Icons.person_outline_rounded,
            label: 'From $assignedBy',
            color: AppColors.textTertiary,
            maxWidth: 150,
          ),
        if (rejected && reviewNote != null && reviewNote.isNotEmpty)
          _MetaChip(
            icon: Icons.feedback_outlined,
            label: reviewNote,
            color: AppColors.error,
            maxWidth: 200,
          ),
      ],
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
    this.maxWidth,
  });

  final IconData icon;
  final String label;
  final Color color;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
          child: Text(
            label,
            style: AppTypography.caption.copyWith(color: color, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─── "View all" row ──────────────────────────────────────────────────

class _ViewAllRow extends StatelessWidget {
  const _ViewAllRow({required this.label, this.emphasized = false});
  final String label;
  final bool emphasized;

  void _open(BuildContext context) {
    final role = context.currentRole;
    if (role != null) context.push(RouteNames.tasksForRole(role));
  }

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: () => _open(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: emphasized ? AppColors.darkSurface : AppColors.transparent,
          borderRadius: AppRadius.cardAll,
          border: Border.all(
            color: emphasized ? AppColors.darkBorder : AppColors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 5),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 14,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Press feedback ──────────────────────────────────────────────────

class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ─── Empty & all-done ────────────────────────────────────────────────

class _EmptyTaskState extends StatelessWidget {
  const _EmptyTaskState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.darkSurfaceElevated,
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: const Icon(
              Icons.inbox_outlined,
              size: 24,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('No tasks yet', style: AppTypography.h3),
          const SizedBox(height: 4),
          const Text(
            'When your manager assigns work, it shows up right here.',
            style: AppTypography.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AllDoneCard extends StatelessWidget {
  const _AllDoneCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.successSurface,
            borderRadius: AppRadius.cardAll,
            border: Border.all(color: AppColors.success.withAlpha(40)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                size: 26,
                color: AppColors.success,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'All caught up!',
                      style: AppTypography.label.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Nothing needs your attention right now.',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const _ViewAllRow(label: 'Open all tasks', emphasized: true),
      ],
    );
  }
}

// ─── Shift swap requests (surfaced on Home) ──────────────────────────

/// Shows the employee's relevant shift swaps right on Home: requests a coworker
/// is waiting on them to **Accept / Reject**, and their own in-flight requests
/// (status + Cancel). Renders nothing when there are none, so Home stays clean.
class _SwapRequestsSection extends StatelessWidget {
  const _SwapRequestsSection({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ShiftSwapCubit, ShiftSwapState>(
      builder: (context, state) {
        final swaps = state.maybeWhen(
          loaded: (s, _) => s,
          orElse: () => const <ShiftSwapEntity>[],
        );
        // Needs THIS user's action (a coworker asked them to trade).
        final incoming = swaps
            .where((s) => s.targetId == uid && s.status.isPending)
            .toList();
        // Their own requests still in flight (waiting on coworker or manager).
        final outgoing = swaps
            .where((s) => s.requesterId == uid && !s.status.isResolved)
            .toList();
        if (incoming.isEmpty && outgoing.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionRow(
                label: 'Shift swaps',
                count: incoming.length + outgoing.length,
                icon: Icons.swap_horiz_rounded,
                color: incoming.isNotEmpty ? AppColors.warning : null,
              ),
              const SizedBox(height: AppSpacing.md),
              for (var i = 0; i < incoming.length; i++)
                EntranceFade(
                  delay: Duration(milliseconds: i * 50),
                  child: _IncomingSwapCard(swap: incoming[i], uid: uid),
                ),
              for (var i = 0; i < outgoing.length; i++)
                EntranceFade(
                  delay: Duration(milliseconds: (incoming.length + i) * 50),
                  child: _OutgoingSwapCard(swap: outgoing[i]),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A swap a coworker is waiting on this employee to accept/reject.
class _IncomingSwapCard extends StatelessWidget {
  const _IncomingSwapCard({required this.swap, required this.uid});
  final ShiftSwapEntity swap;
  final String uid;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ShiftSwapCubit>();
    final requester = swap.requesterName ?? 'A coworker';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppGlassCard(
        glow: AppColors.warning,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UserAvatar(name: requester, size: 38),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        requester,
                        style: AppTypography.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${swap.day.label} · wants to swap shifts',
                        style: AppTypography.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const _MiniPill(label: 'Needs you', color: AppColors.warning),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // You give your current (opposite) shift, you get theirs.
            _HomeExchangeStrip(
              giveLabel: swap.shift.opposite.label,
              getLabel: swap.shift.label,
            ),
            if ((swap.note ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                swap.note!,
                style: AppTypography.caption.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                PremiumButton(
                  label: 'Accept',
                  icon: Icons.check_rounded,
                  style: PremiumButtonStyle.filled,
                  onPressed: () => cubit.coworkerApprove(swap),
                ),
                const SizedBox(width: AppSpacing.sm),
                PremiumButton(
                  label: 'Decline',
                  icon: Icons.close_rounded,
                  tone: AppColors.error,
                  onPressed: () => cubit.reject(swap, actorId: uid),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The employee's own in-flight swap request — shows its stage + Cancel.
class _OutgoingSwapCard extends StatelessWidget {
  const _OutgoingSwapCard({required this.swap});
  final ShiftSwapEntity swap;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ShiftSwapCubit>();
    final awaitingManager = swap.status.isEmployeeApproved;
    final accent = awaitingManager ? AppColors.success : AppColors.warning;
    final detail = awaitingManager
        ? 'Accepted — awaiting manager approval'
        : 'Waiting for ${swap.targetName ?? 'your coworker'} to accept';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppGlassCard(
        glow: awaitingManager ? AppColors.success : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.darkSurfaceElevated,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.swap_horiz_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your swap request',
                        style: AppTypography.label,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: AppTypography.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _MiniPill(label: swap.status.label, color: accent),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: PremiumButton(
                label: 'Cancel request',
                icon: Icons.undo_rounded,
                style: PremiumButtonStyle.ghost,
                tone: AppColors.textSecondary,
                onPressed: () => cubit.cancelSwap(swap),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "You give X  ⇄  You get Y" — makes the trade unmistakable on the home card.
class _HomeExchangeStrip extends StatelessWidget {
  const _HomeExchangeStrip({required this.giveLabel, required this.getLabel});
  final String giveLabel;
  final String getLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          Expanded(child: _slot('You give', giveLabel, false)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Icon(
              Icons.swap_horiz_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ),
          Expanded(child: _slot('You get', getLabel, true)),
        ],
      ),
    );
  }

  Widget _slot(String caption, String shift, bool alignEnd) => Column(
    crossAxisAlignment: alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start,
    children: [
      Text(
        caption.toUpperCase(),
        style: AppTypography.caption.copyWith(
          color: AppColors.textTertiary,
          fontSize: 9,
          letterSpacing: 0.5,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        shift,
        style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}

// ─── Loading shimmer ─────────────────────────────────────────────────

class _HomeShimmer extends StatelessWidget {
  const _HomeShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Skeleton(
          height: 124,
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Skeleton(
                  height: 72,
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        const Skeleton(
          width: 110,
          height: 12,
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
        const SizedBox(height: AppSpacing.md),
        for (var i = 0; i < 3; i++) ...[
          const Skeleton(
            height: 116,
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}
