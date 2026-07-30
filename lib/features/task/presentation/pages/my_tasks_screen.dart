import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/app_snackbar.dart';
import 'package:drop/core/widgets/list_skeleton.dart';
import 'package:drop/core/widgets/responsive_card_grid.dart';
import 'package:drop/core/widgets/segmented_tab_bar.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/task/presentation/cubit/task_state.dart';
import 'package:drop/features/task/presentation/pages/task_details_screen.dart';
import 'package:drop/features/task/presentation/widgets/live_status_border.dart';
import 'package:drop/features/task/presentation/widgets/task_card.dart';
import 'package:drop/features/task/presentation/widgets/task_empty_state.dart';

/// Employee task screen — sectioned, animated, and optimised for speed.
/// The workflow is: open app → see today's tasks → open task → complete
/// checklist → upload proof → submit. Each section collapses when empty.
///
/// Premium, in-language polish (2026-07-29) that stays strictly monochrome
/// (ADR-004) and preserves the task-card attention model (ADR-014 — the
/// per-state hairline + the [LiveStatusBorder] orbit): a two-line header with
/// today's date, a compact completion overview, a slimmer sliding segmented
/// control, richer cards, date-grouped closed tasks, and a calmer all-clear
/// state.
class MyTasksScreen extends StatefulWidget {
  const MyTasksScreen({super.key});

  @override
  State<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends State<MyTasksScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _load() {
    final user = context.currentUser;
    if (user != null) context.read<TaskCubit>().load(user);
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: 'My Tasks',
      // Two-line lockup — the title anchored by today's date. Quiet context
      // that orients the employee the moment the screen opens.
      titleWidget: const _HeaderLockup(),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.refresh_rounded,
            color: AppColors.textSecondary,
          ),
          tooltip: 'Refresh',
          onPressed: () => context.read<TaskCubit>().refresh(),
        ),
      ],
      body: BlocConsumer<TaskCubit, TaskState>(
        listener: (context, state) =>
            state.whenOrNull(error: (m) => AppSnackbar.error(context, m)),
        builder: (context, state) => state.maybeWhen(
          loading: () => const ListSkeleton(),
          loaded: (tasks, busy, directory, _, _) =>
              _body(tasks, busy, directory),
          orElse: () => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _body(
    List<TaskEntity> tasks,
    bool busy,
    Map<String, UserEntity> directory,
  ) {
    final active = tasks.where((t) => !t.status.isTerminal).length;
    final approved =
        tasks.where((t) => t.status == TaskStatus.approved).length;

    return Column(
      children: [
        // Refresh is a quiet 2px hairline so a background reload never shifts
        // the layout beneath it.
        SizedBox(
          height: 2,
          child: busy
              ? const LinearProgressIndicator(
                  minHeight: 2,
                  color: AppColors.primary,
                  backgroundColor: AppColors.transparent,
                )
              : null,
        ),
        // Completion overview — the "how am I doing" glance, pinned above the
        // list. Hidden entirely when there is nothing to summarise.
        if (active + approved > 0)
          _TaskOverview(active: active, approved: approved),
        // Slimmer sliding segmented control (local overrides — the shared
        // primitive keeps its defaults for other screens).
        SegmentedTabBar(
          controller: _tabs,
          tabs: const ['Active', 'Done'],
          height: 38,
          margin: const EdgeInsets.fromLTRB(
            AppSpacing.pagePadding,
            AppSpacing.sm,
            AppSpacing.pagePadding,
            AppSpacing.md,
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _ActiveTasksTab(tasks: tasks, directory: directory),
              _DoneTasksTab(tasks: tasks, directory: directory),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Header lockup ──────────────────────────────────────────────────

/// "My Tasks" over today's date — a two-line app-bar title.
class _HeaderLockup extends StatelessWidget {
  const _HeaderLockup();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('My Tasks', style: AppTypography.h3),
        const SizedBox(height: 1),
        Text(
          AppDateFormatter.weekdayDayMonth(DateTime.now()),
          style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
        ),
      ],
    );
  }
}

// ─── Completion overview ────────────────────────────────────────────

/// A compact, elegant progress card: a monochrome completion ring beside the
/// day's headline and a done / remaining split. Present only when the employee
/// has tasks — it never nags an empty queue.
class _TaskOverview extends StatelessWidget {
  const _TaskOverview({required this.active, required this.approved});

  final int active;
  final int approved;

  @override
  Widget build(BuildContext context) {
    final total = active + approved;
    final progress = total == 0 ? 0.0 : approved / total;
    final headline = active == 0
        ? "You're all caught up"
        : '$active Active Task${active == 1 ? '' : 's'}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.md,
        AppSpacing.pagePadding,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Row(
          children: [
            _ProgressRing(value: progress),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headline,
                    style: AppTypography.h3.copyWith(fontSize: 17),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _MiniStat(label: 'Done', value: approved),
                      Container(
                        width: 1,
                        height: 22,
                        margin: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        color: AppColors.darkBorder,
                      ),
                      _MiniStat(label: 'Remaining', value: active),
                    ],
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

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final complete = value >= 1;
    return SizedBox(
      width: 52,
      height: 52,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: v,
                strokeWidth: 4,
                strokeCap: StrokeCap.round,
                backgroundColor: AppColors.darkSurfaceElevated,
                valueColor: const AlwaysStoppedAnimation(
                  AppColors.textPrimary,
                ),
              ),
            ),
            complete
                ? const Icon(
                    Icons.check_rounded,
                    size: 22,
                    color: AppColors.textPrimary,
                  )
                : Text(
                    '${(v * 100).round()}%',
                    style: AppTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '$value',
          style: AppTypography.label.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

// ─── Active tab (pending + in progress + in review) ─────────────────

class _ActiveTasksTab extends StatelessWidget {
  const _ActiveTasksTab({required this.tasks, required this.directory});
  final List<TaskEntity> tasks;
  final Map<String, UserEntity> directory;

  @override
  Widget build(BuildContext context) {
    final today = _todayTasks(tasks);
    final inProgress = _inProgressTasks(tasks);
    final pending = _pendingTasks(tasks);
    final inReview = _reviewTasks(tasks);
    final rejected = _rejectedTasks(tasks);

    final empty =
        today.isEmpty &&
        inProgress.isEmpty &&
        pending.isEmpty &&
        inReview.isEmpty &&
        rejected.isEmpty;

    if (empty) {
      return RefreshIndicator(
        onRefresh: () => context.read<TaskCubit>().refresh(),
        child: const _AllClearState(),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<TaskCubit>().refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          0,
          AppSpacing.pagePadding,
          AppSpacing.xxxl,
        ),
        children: [
          if (rejected.isNotEmpty) ...[
            _SectionHeader(
              label: 'Needs attention',
              count: rejected.length,
              icon: Icons.replay_rounded,
              color: AppColors.error,
            ),
            _buildCards(context, rejected, directory),
          ],
          if (inProgress.isNotEmpty) ...[
            _SectionHeader(
              label: 'In progress',
              count: inProgress.length,
              icon: Icons.timelapse_rounded,
            ),
            _buildCards(context, inProgress, directory),
          ],
          if (today.isNotEmpty) ...[
            _SectionHeader(
              label: "Today's tasks",
              count: today.length,
              icon: Icons.today_outlined,
            ),
            _buildCards(context, today, directory),
          ],
          if (pending.isNotEmpty) ...[
            _SectionHeader(
              label: 'Upcoming',
              count: pending.length,
              icon: Icons.schedule_outlined,
            ),
            _buildCards(context, pending, directory),
          ],
          if (inReview.isNotEmpty) ...[
            _SectionHeader(
              label: 'In review',
              count: inReview.length,
              icon: Icons.hourglass_empty_rounded,
            ),
            _buildCards(context, inReview, directory),
          ],
        ],
      ),
    );
  }

  Widget _buildCards(
    BuildContext context,
    List<TaskEntity> list,
    Map<String, UserEntity> dir,
  ) {
    // EmployeeTaskCard carries its own bottom margin, so the grid adds no extra
    // vertical spacing (runSpacing: 0) — only lays cards side-by-side on desktop.
    return ResponsiveCardGrid(
      runSpacing: 0,
      maxItemWidth: 480,
      children: [
        for (var i = 0; i < list.length; i++)
          _AnimatedCard(
            key: ValueKey(list[i].id),
            index: i,
            child: EmployeeTaskCard(task: list[i], directory: dir),
          ),
      ],
    );
  }

  List<TaskEntity> _todayTasks(List<TaskEntity> all) {
    final today = DateTime.now();
    return all.where((t) {
      if (t.status != TaskStatus.pending) return false;
      final d = t.deadline;
      if (d == null) return true; // no deadline = always "today"
      return d.year == today.year &&
          d.month == today.month &&
          d.day == today.day;
    }).toList();
  }

  List<TaskEntity> _inProgressTasks(List<TaskEntity> all) =>
      all.where((t) => t.status == TaskStatus.started).toList();

  List<TaskEntity> _pendingTasks(List<TaskEntity> all) {
    final today = DateTime.now();
    return all.where((t) {
      if (t.status != TaskStatus.pending) return false;
      final d = t.deadline;
      if (d == null) return false; // no deadline already shown in "today"
      return d.isAfter(DateTime(today.year, today.month, today.day));
    }).toList();
  }

  List<TaskEntity> _reviewTasks(List<TaskEntity> all) => all
      .where(
        (t) =>
            t.status == TaskStatus.waitingReview ||
            t.status == TaskStatus.completed,
      )
      .toList();

  List<TaskEntity> _rejectedTasks(List<TaskEntity> all) =>
      all.where((t) => t.status == TaskStatus.rejected).toList();
}

// ─── Done tab ───────────────────────────────────────────────────────

class _DoneTasksTab extends StatelessWidget {
  const _DoneTasksTab({required this.tasks, required this.directory});
  final List<TaskEntity> tasks;
  final Map<String, UserEntity> directory;

  @override
  Widget build(BuildContext context) {
    // Every closed outcome belongs here — approved, missed, and cancelled. A
    // cancelled task disappearing entirely would leave the employee wondering
    // where their work went (they are told about it — spec §9.2).
    final done = tasks.where((t) => t.status.isTerminal).toList();

    if (done.isEmpty) {
      return const TaskEmptyState(
        message:
            "No closed tasks yet.\nApproved, missed and cancelled tasks appear here.",
      );
    }

    // Group closed tasks by recency so the timeline reads as a history rather
    // than one long, dateless list. Buckets keep their natural order.
    final groups = _groupByRecency(done);

    return RefreshIndicator(
      onRefresh: () => context.read<TaskCubit>().refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          0,
          AppSpacing.pagePadding,
          AppSpacing.xxxl,
        ),
        children: [
          for (final entry in groups) ...[
            _DateGroupHeader(label: entry.key),
            ResponsiveCardGrid(
              runSpacing: 0, // EmployeeTaskCard carries its own bottom margin
              maxItemWidth: 480,
              children: [
                for (var i = 0; i < entry.value.length; i++)
                  _AnimatedCard(
                    key: ValueKey(entry.value[i].id),
                    index: i,
                    child: EmployeeTaskCard(
                      task: entry.value[i],
                      directory: directory,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Bucket terminal tasks into Today · Yesterday · This week · Earlier by their
  /// deadline (the closest date we hold). Undated tasks fall to "Earlier".
  List<MapEntry<String, List<TaskEntity>>> _groupByRecency(
    List<TaskEntity> done,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final buckets = <String, List<TaskEntity>>{
      'Today': [],
      'Yesterday': [],
      'This week': [],
      'Earlier': [],
    };

    for (final t in done) {
      final d = t.deadline;
      if (d == null) {
        buckets['Earlier']!.add(t);
        continue;
      }
      final day = DateTime(d.year, d.month, d.day);
      final diff = today.difference(day).inDays;
      if (diff <= 0) {
        buckets['Today']!.add(t);
      } else if (diff == 1) {
        buckets['Yesterday']!.add(t);
      } else if (diff < 7) {
        buckets['This week']!.add(t);
      } else {
        buckets['Earlier']!.add(t);
      }
    }

    return buckets.entries.where((e) => e.value.isNotEmpty).toList();
  }
}

// ─── Section header ─────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
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
    final c = color ?? AppColors.textTertiary;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label.toUpperCase(),
            style: AppTypography.caption.copyWith(
              color: c,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.darkSurfaceElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A quieter header for the closed-task timeline — just the recency label, no
/// count chip, so the history reads calmly.
class _DateGroupHeader extends StatelessWidget {
  const _DateGroupHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.md),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.caption.copyWith(
          color: AppColors.textTertiary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ─── Animated card wrapper ──────────────────────────────────────────

class _AnimatedCard extends StatefulWidget {
  const _AnimatedCard({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<_AnimatedCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOut,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.08),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 60 + widget.index * 50), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// A minimal task card for the employee view — tap opens [TaskDetailsScreen].
/// Presses give a subtle spring-back scale (iOS-style) before the push.
class EmployeeTaskCard extends StatefulWidget {
  const EmployeeTaskCard({
    super.key,
    required this.task,
    required this.directory,
  });

  final TaskEntity task;
  final Map<String, UserEntity> directory;

  @override
  State<EmployeeTaskCard> createState() => _EmployeeTaskCardState();
}

class _EmployeeTaskCardState extends State<EmployeeTaskCard> {
  bool _pressed = false;

  void _open() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (ctx, animation, secAnim) => TaskDetailsScreen(
          task: widget.task,
          directory: widget.directory,
        ),
        transitionsBuilder: (ctx, animation, secAnim, child) {
          return SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: const Interval(0, 0.6),
              ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _open,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: _MinimalCard(task: widget.task, directory: widget.directory),
      ),
    );
  }
}

class _MinimalCard extends StatelessWidget {
  const _MinimalCard({required this.task, required this.directory});
  final TaskEntity task;
  final Map<String, UserEntity> directory;

  @override
  Widget build(BuildContext context) {
    final isOverdue = _isOverdue(task);
    final isTerminal = task.status.isTerminal;
    final isApproved = task.status == TaskStatus.approved;
    final meta = _metaLine(task, isOverdue);

    // Live-activity sweep (NOT status — decoupled from the status dot). Only
    // actionable states animate; the margin sits outside so the sweep tracks
    // the border, not the gap between cards.
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Opacity(
        // Closed work reads lighter without losing legibility (§6).
        opacity: isTerminal ? 0.72 : 1,
        child: LiveStatusBorder(
          color: liveActivityColor(task),
          speed: liveOrbitSpeed(task),
          pulse: taskOverdue(task),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isOverdue
                    ? AppColors.error.withAlpha(80)
                    : AppColors.darkBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusDot(task.status),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: AppTypography.labelLarge.copyWith(
                              height: 1.25,
                              color: isApproved
                                  ? AppColors.textTertiary
                                  : AppColors.textPrimary,
                              decoration: isApproved
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (meta != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              meta,
                              style: AppTypography.caption.copyWith(
                                color: isOverdue
                                    ? AppColors.error
                                    : AppColors.textTertiary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if (task.priority.isHigh && !isTerminal) ...[
                      const _PriorityTag(),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.textQuaternary,
                    ),
                  ],
                ),

                // Closed-outcome badge (replaces the progress bar on the Done
                // tab — a finished task needs its outcome, not its checklist).
                if (isTerminal) ...[
                  const SizedBox(height: AppSpacing.md),
                  _OutcomeBadge(task.status),
                ]
                // Checklist progress pill — actionable tasks only.
                else if (task.hasChecklist) ...[
                  const SizedBox(height: AppSpacing.md),
                  _ProgressPill(task: task),
                ],

                // Recurrence badge
                if (task.recurrence != null &&
                    task.recurrence!.frequency.value != 'none') ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      const Icon(
                        Icons.repeat_rounded,
                        size: 12,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        task.recurrence!.frequency.label,
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot(this.status);
  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      TaskStatus.started => AppColors.textPrimary,
      TaskStatus.waitingReview => AppColors.warning,
      TaskStatus.approved => AppColors.success,
      TaskStatus.rejected => AppColors.error,
      TaskStatus.missed => AppColors.error,
      // Cancelled is neither success nor failure (spec §8) — neutral, and
      // deliberately not the error red that Missed wears.
      TaskStatus.cancelled => AppColors.textSecondary,
      _ => AppColors.textTertiary,
    };
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

/// A restrained "High" marker — a hairline pill, never a colour flood (the
/// monochrome ruling holds; urgency is carried by wording + the card's orbit).
class _PriorityTag extends StatelessWidget {
  const _PriorityTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Text(
        'High',
        style: AppTypography.caption.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// The closed outcome, stated plainly for the Done tab.
class _OutcomeBadge extends StatelessWidget {
  const _OutcomeBadge(this.status);
  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (status) {
      TaskStatus.approved => (
        'Completed',
        Icons.check_circle_rounded,
        AppColors.success,
      ),
      TaskStatus.missed => (
        'Missed',
        Icons.error_rounded,
        AppColors.error,
      ),
      TaskStatus.cancelled => (
        'Cancelled',
        Icons.cancel_rounded,
        AppColors.textSecondary,
      ),
      _ => ('Closed', Icons.circle, AppColors.textTertiary),
    };
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ProgressPill extends StatelessWidget {
  const _ProgressPill({required this.task});
  final TaskEntity task;

  @override
  Widget build(BuildContext context) {
    final done = task.checklistDone;
    final total = task.checklistTotal;
    final complete = done == total;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: task.checklistProgress),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, v, child) => LinearProgressIndicator(
                value: v,
                minHeight: 4,
                backgroundColor: AppColors.darkSurfaceElevated,
                valueColor: AlwaysStoppedAnimation(
                  complete ? AppColors.success : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          '$done/$total',
          style: AppTypography.caption.copyWith(
            color: complete ? AppColors.success : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─── All-clear state ────────────────────────────────────────────────

/// A calm, premium "nothing to do" moment for the Active tab — a soft ringed
/// check over a short, warm message. Scrollable so it still hosts pull-to-
/// refresh. Strictly monochrome; the check is the one small flourish.
class _AllClearState extends StatelessWidget {
  const _AllClearState();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : 0,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.darkSurface,
                      border: Border.all(color: AppColors.darkBorder, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 34,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    "You're all caught up",
                    style: AppTypography.h3,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Enjoy your shift.\nNew tasks will appear here automatically.',
                    style: AppTypography.bodySmall,
                    textAlign: TextAlign.center,
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

// ─── Helpers ──────────────────────────────────────────────────────────

bool _isOverdue(TaskEntity task) {
  final d = task.deadline;
  if (d == null) return false;
  final done =
      task.status.isTerminal ||
      task.status == TaskStatus.completed ||
      task.status == TaskStatus.waitingReview;
  return !done && d.isBefore(DateTime.now());
}

/// One glanceable subtitle line: shift · due (or the overdue flag). Returns
/// null when there is nothing worth a second line.
String? _metaLine(TaskEntity task, bool isOverdue) {
  final parts = <String>[];
  final shift = task.shift;
  if (shift != null) parts.add('${shift.label} shift');

  final d = task.deadline;
  if (d != null) {
    if (isOverdue) {
      parts.add('Late · ${_dateLabel(d)}');
    } else {
      parts.add('Due ${_dateLabel(d)}');
    }
  }
  return parts.isEmpty ? null : parts.join(' · ');
}

String _dateLabel(DateTime d) => AppDateFormatter.dayMonth(d);
