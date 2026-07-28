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
      bottom: SegmentedTabBar(
        controller: _tabs,
        tabs: const ['Active', 'Done'],
      ),
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
    return Column(
      children: [
        if (busy)
          const LinearProgressIndicator(minHeight: 2, color: AppColors.primary),
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
      return const TaskEmptyState(
        message: 'All clear! No active tasks right now.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<TaskCubit>().refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          AppSpacing.md,
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

    return RefreshIndicator(
      onRefresh: () => context.read<TaskCubit>().refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          AppSpacing.md,
          AppSpacing.pagePadding,
          AppSpacing.xxxl,
        ),
        children: [
          ResponsiveCardGrid(
            runSpacing: 0, // EmployeeTaskCard carries its own bottom margin
            maxItemWidth: 480,
            children: [
              for (var i = 0; i < done.length; i++)
                _AnimatedCard(
                  key: ValueKey(done[i].id),
                  index: i,
                  child: EmployeeTaskCard(task: done[i], directory: directory),
                ),
            ],
          ),
        ],
      ),
    );
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
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
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
class EmployeeTaskCard extends StatelessWidget {
  const EmployeeTaskCard({
    super.key,
    required this.task,
    required this.directory,
  });

  final TaskEntity task;
  final Map<String, UserEntity> directory;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (ctx, animation, secAnim) =>
              TaskDetailsScreen(task: task, directory: directory),
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
      ),
      child: _MinimalCard(task: task, directory: directory),
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

    // Live-activity sweep (NOT status — decoupled from the status dot). Only
    // actionable states animate; the margin sits outside so the sweep tracks
    // the border, not the gap between cards.
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: LiveStatusBorder(
        color: liveActivityColor(task),
        speed: liveOrbitSpeed(task),
        pulse: taskOverdue(task),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(16),
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
                          style: AppTypography.label.copyWith(
                            fontSize: 15,
                            color: task.status == TaskStatus.approved
                                ? AppColors.textTertiary
                                : AppColors.textPrimary,
                            decoration: task.status == TaskStatus.approved
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (task.deadline != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            isOverdue
                                ? 'Overdue · ${_dateLabel(task.deadline!)}'
                                : _dateLabel(task.deadline!),
                            style: AppTypography.caption.copyWith(
                              color: isOverdue
                                  ? AppColors.error
                                  : AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),

              // Checklist progress pill
              if (task.hasChecklist) ...[
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
      margin: const EdgeInsets.only(top: 5),
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
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
                minHeight: 3,
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

String _dateLabel(DateTime d) => AppDateFormatter.dayMonth(d);
