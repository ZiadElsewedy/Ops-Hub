import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/enums/task_priority.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/core/responsive/breakpoints.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/adaptive_scaffold.dart';
import 'package:opshub/core/widgets/app_empty_state.dart';
import 'package:opshub/core/widgets/app_motion.dart';
import 'package:opshub/core/widgets/brand_watermark.dart';
import 'package:opshub/core/widgets/glass_container.dart';
import 'package:opshub/core/widgets/list_skeleton.dart';
import 'package:opshub/core/widgets/responsive_card_grid.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/operations/domain/branch_workload.dart';
import 'package:opshub/features/operations/domain/employee_workload.dart';
import 'package:opshub/features/operations/domain/shift_filter.dart';
import 'package:opshub/features/operations/presentation/cubit/branch_operations_cubit.dart';
import 'package:opshub/features/operations/presentation/cubit/branch_operations_state.dart';
import 'package:opshub/features/operations/presentation/pages/employee_detail_screen.dart';
import 'package:opshub/features/operations/presentation/widgets/workload_card.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/domain/task_outcomes.dart';
import 'package:opshub/features/task/presentation/cubit/task_cubit.dart';
import 'package:opshub/features/task/presentation/cubit/task_state.dart';
import 'package:opshub/features/task/presentation/widgets/manager_task_card.dart';
import 'package:opshub/features/task/presentation/widgets/task_empty_state.dart';
import 'package:opshub/core/widgets/app_error_state.dart';

/// The four operational questions exposed by the Branch Operations headline.
/// Each value opens a distinct drill-down experience while sharing one live,
/// architecture-safe implementation.
enum OperationsMetric { activeTasks, overdue, pendingReview, staffActive }

extension OperationsMetricPresentation on OperationsMetric {
  String get title => switch (this) {
    OperationsMetric.activeTasks => 'Active tasks',
    OperationsMetric.overdue => 'Late tasks',
    OperationsMetric.pendingReview => 'Pending review',
    OperationsMetric.staffActive => 'Staff active',
  };

  String get eyebrow => switch (this) {
    OperationsMetric.activeTasks => 'LIVE WORKLOAD',
    OperationsMetric.overdue => 'NEEDS ATTENTION',
    OperationsMetric.pendingReview => 'DECISION QUEUE',
    OperationsMetric.staffActive => 'TODAY\'S ROSTER',
  };

  String get description => switch (this) {
    OperationsMetric.activeTasks =>
      'Open work moving through pending, in progress and rework.',
    OperationsMetric.overdue =>
      'Active work past its deadline, ordered by longest waiting.',
    OperationsMetric.pendingReview =>
      'Completed work waiting for a manager or admin decision.',
    OperationsMetric.staffActive =>
      'Employees rostered today in the current shift lens.',
  };

  IconData get icon => switch (this) {
    OperationsMetric.activeTasks => Icons.bolt_rounded,
    OperationsMetric.overdue => Icons.warning_amber_rounded,
    OperationsMetric.pendingReview => Icons.fact_check_outlined,
    OperationsMetric.staffActive => Icons.groups_2_outlined,
  };
}

/// Premium metric drill-down reached from one of the four Branch Operations
/// KPI tiles. It reads the already-live [BranchOperationsCubit] and [TaskCubit]
/// instances inherited from the cockpit; no extra query or write path exists.
class OperationsMetricScreen extends StatelessWidget {
  const OperationsMetricScreen({
    super.key,
    required this.metric,
    required this.branchId,
    required this.branchName,
    required this.isAdmin,
  });

  final OperationsMetric metric;
  final String branchId;
  final String branchName;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BranchOperationsCubit, BranchOperationsState>(
      builder: (context, state) => state.maybeWhen(
        loaded: (_, workload, filter, loadedName, _) => AdaptiveScaffold(
          title: metric.title,
          subtitle: '${loadedName ?? branchName} · ${_scopeLabel(filter)}',
          constrainContent: false,
          body: metric == OperationsMetric.staffActive
              ? _staffBody(context, workload, filter)
              : _taskBody(context, workload, filter),
        ),
        error: (message) => AdaptiveScaffold(
          title: metric.title,
          body: AppErrorState(
            icon: Icons.wifi_off_rounded,
            title: 'Could not load branch operations',
            message: message,
            onRetry: () => context.read<BranchOperationsCubit>().refresh(),
          ),
        ),
        orElse: () =>
            AdaptiveScaffold(title: metric.title, body: const ListSkeleton()),
      ),
    );
  }

  Widget _taskBody(
    BuildContext context,
    BranchWorkload workload,
    ShiftFilter filter,
  ) {
    return BlocBuilder<TaskCubit, TaskState>(
      builder: (context, state) => state.maybeWhen(
        loaded: (all, busy, directory, _, _) {
          final tasks = _metricTasks(all, filter);
          // "Finished late" is a second view over the same overdue lens — the
          // work that used to count here and no longer does the moment it's
          // finished, which is exactly why the owner could never find it.
          final finishedLate = metric == OperationsMetric.overdue
              ? _finishedLateTasks(all, filter)
              : const <TaskEntity>[];
          return Column(
            children: [
              if (busy) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pagePadding,
                    AppSpacing.lg,
                    AppSpacing.pagePadding,
                    AppSpacing.xxxl * 2,
                  ),
                  children: [
                    _MetricHero(
                      metric: metric,
                      count: tasks.length,
                      scope: _scopeLabel(filter),
                      facts: _taskFacts(tasks),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (metric == OperationsMetric.overdue) ...[
                      if (tasks.isEmpty && finishedLate.isEmpty)
                        SizedBox(
                          height: 280,
                          child: TaskEmptyState(message: _emptyMessage),
                        )
                      else ...[
                        if (tasks.isNotEmpty) ...[
                          _ResultsHeader(
                            label: _resultsLabel,
                            count: tasks.length,
                            trailing: 'oldest first',
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _taskGrid(tasks, directory),
                        ],
                        if (finishedLate.isNotEmpty) ...[
                          if (tasks.isNotEmpty)
                            const SizedBox(height: AppSpacing.xl),
                          _ResultsHeader(
                            label: 'Finished late',
                            count: finishedLate.length,
                            trailing: 'most late first',
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _taskGrid(finishedLate, directory),
                        ],
                      ],
                    ] else ...[
                      _ResultsHeader(
                        label: _resultsLabel,
                        count: tasks.length,
                        trailing: 'priority order',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (tasks.isEmpty)
                        SizedBox(
                          height: 280,
                          child: TaskEmptyState(message: _emptyMessage),
                        )
                      else
                        _taskGrid(tasks, directory),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const ListSkeleton(),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }

  Widget _taskGrid(List<TaskEntity> tasks, Map<String, UserEntity> directory) =>
      ResponsiveCardGrid(
        runSpacing: 0,
        maxItemWidth: 500,
        children: [
          for (var i = 0; i < tasks.length; i++)
            EntranceFade(
              delay: staggerDelay(i),
              child: ManagerTaskCard(
                task: tasks[i],
                directory: directory,
                isAdmin: isAdmin,
                defaultBranchId: branchId,
              ),
            ),
        ],
      );

  Widget _staffBody(
    BuildContext context,
    BranchWorkload workload,
    ShiftFilter filter,
  ) {
    final staff = workload.employees
        .where((employee) => employee.shiftsToday.isNotEmpty)
        .toList();
    final morning = staff
        .where(
          (employee) => employee.shiftsToday.contains(ScheduleShift.morning),
        )
        .length;
    final night = staff
        .where((employee) => employee.shiftsToday.contains(ScheduleShift.night))
        .length;
    final both = staff
        .where((employee) => employee.shiftsToday.length > 1)
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.lg,
        AppSpacing.pagePadding,
        AppSpacing.xxxl * 2,
      ),
      children: [
        _MetricHero(
          metric: metric,
          count: staff.length,
          scope: _scopeLabel(filter),
          facts: [
            _HeroFact('Morning', morning),
            _HeroFact('Night', night),
            _HeroFact('Both shifts', both),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        _ResultsHeader(
          label: 'Rostered today',
          count: staff.length,
          trailing: 'workload order',
        ),
        const SizedBox(height: AppSpacing.md),
        if (staff.isEmpty)
          const AppEmptyState(
            icon: Icons.event_busy_outlined,
            title: 'No staff in this shift',
            message: 'No employees are rostered today for the current lens.',
          )
        else
          ResponsiveCardGrid(
            runSpacing: 0,
            maxItemWidth: 500,
            children: [
              for (var i = 0; i < staff.length; i++)
                EntranceFade(
                  delay: staggerDelay(i),
                  child: WorkloadCard(
                    workload: staff[i],
                    onTap: () => _openEmployee(context, staff[i]),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  void _openEmployee(BuildContext context, EmployeeWorkload workload) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EmployeeDetailScreen(
          employee: workload.user,
          isAdmin: isAdmin,
          defaultBranchId: branchId,
        ),
      ),
    );
  }

  List<TaskEntity> _metricTasks(List<TaskEntity> all, ShiftFilter filter) {
    final now = DateTime.now();
    final tasks = all
        .where((task) => (task.branchId ?? '') == branchId)
        .where((task) => filter.matchesTask(task.shift))
        .where(
          (task) => switch (metric) {
            OperationsMetric.activeTasks => isOperationalActiveTask(task),
            OperationsMetric.overdue => isOperationalOverdueTask(task, now),
            OperationsMetric.pendingReview => isOperationalPendingReviewTask(
              task,
            ),
            OperationsMetric.staffActive => false,
          },
        )
        .toList();

    tasks.sort((a, b) {
      if (metric == OperationsMetric.overdue) {
        return a.deadline!.compareTo(b.deadline!);
      }
      if (metric == OperationsMetric.pendingReview) {
        final ad = a.submittedAt ?? a.updatedAt ?? a.createdAt;
        final bd = b.submittedAt ?? b.updatedAt ?? b.createdAt;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      }
      final rankA = _activeRank(a, now);
      final rankB = _activeRank(b, now);
      if (rankA != rankB) return rankA.compareTo(rankB);
      return _compareDeadlines(a.deadline, b.deadline);
    });
    return tasks;
  }

  /// The same branch/shift scope as [_metricTasks], but for work that has
  /// **finished** and missed its deadline — [isOperationalOverdueTask] goes to
  /// zero the instant a task is submitted, so this is the only way to find it
  /// afterwards. Sorted most late first.
  List<TaskEntity> _finishedLateTasks(List<TaskEntity> all, ShiftFilter filter) {
    final tasks = all
        .where((task) => (task.branchId ?? '') == branchId)
        .where((task) => filter.matchesTask(task.shift))
        .where(isOperationalFinishedLateTask)
        .toList();
    tasks.sort((a, b) => taskLateness(b)!.compareTo(taskLateness(a)!));
    return tasks;
  }

  List<_HeroFact> _taskFacts(List<TaskEntity> tasks) {
    final now = DateTime.now();
    return switch (metric) {
      OperationsMetric.activeTasks => [
        _HeroFact(
          'In progress',
          tasks.where((t) => t.status == TaskStatus.started).length,
        ),
        _HeroFact(
          'Pending',
          tasks.where((t) => t.status == TaskStatus.pending).length,
        ),
        _HeroFact(
          'Rework',
          tasks.where((t) => t.status == TaskStatus.rejected).length,
        ),
      ],
      OperationsMetric.overdue => [
        _HeroFact(
          '24h+',
          tasks.where((t) => now.difference(t.deadline!).inHours >= 24).length,
        ),
        _HeroFact(
          'High priority',
          tasks.where((t) => t.priority == TaskPriority.high).length,
        ),
        _HeroFact('Unassigned', tasks.where((t) => !t.isAssigned).length),
      ],
      OperationsMetric.pendingReview => [
        _HeroFact(
          'Submitted',
          tasks.where((t) => t.status == TaskStatus.completed).length,
        ),
        _HeroFact(
          'In review',
          tasks.where((t) => t.status == TaskStatus.waitingReview).length,
        ),
        _HeroFact('With proof', tasks.where(_hasProof).length),
      ],
      OperationsMetric.staffActive => const [],
    };
  }

  bool _hasProof(TaskEntity task) =>
      (task.proofImageUrl ?? '').isNotEmpty ||
      task.activityLog.any((entry) => entry.attachments.isNotEmpty);

  String get _resultsLabel => switch (metric) {
    OperationsMetric.activeTasks => 'Open work',
    OperationsMetric.overdue => 'Past deadline',
    OperationsMetric.pendingReview => 'Awaiting decision',
    OperationsMetric.staffActive => 'Rostered today',
  };

  String get _emptyMessage => switch (metric) {
    OperationsMetric.activeTasks =>
      'No active tasks in the current branch and shift lens.',
    OperationsMetric.overdue =>
      'Nothing late. The current shift is on track.',
    OperationsMetric.pendingReview =>
      'No completed work is waiting for review.',
    OperationsMetric.staffActive => 'No staff are rostered today.',
  };
}

class _MetricHero extends StatelessWidget {
  const _MetricHero({
    required this.metric,
    required this.count,
    required this.scope,
    required this.facts,
  });

  final OperationsMetric metric;
  final int count;
  final String scope;
  final List<_HeroFact> facts;

  @override
  Widget build(BuildContext context) {
    final alert = metric == OperationsMetric.overdue && count > 0;
    final accent = alert ? AppColors.error : AppColors.textPrimary;
    return GlassContainer(
      padding: EdgeInsets.zero,
      highlight: alert,
      accent: AppColors.error,
      child: BrandWatermark(
        opacity: 0.025,
        assetLogo: true,
        assetHeight: 104,
        child: Padding(
          padding: EdgeInsets.all(
            context.isDesktop ? AppSpacing.xl : AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accent.withAlpha(alert ? 24 : 14),
                      borderRadius: AppRadius.lgAll,
                      border: Border.all(
                        color: accent.withAlpha(alert ? 90 : 45),
                      ),
                    ),
                    child: Icon(metric.icon, color: accent, size: 23),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          metric.eyebrow,
                          style: AppTypography.caption.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(metric.description, style: AppTypography.body),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$count',
                        style: AppTypography.h1.copyWith(
                          fontSize: context.isDesktop ? 42 : 34,
                          color: accent,
                        ),
                      ),
                      Text(scope, style: AppTypography.caption),
                    ],
                  ),
                ],
              ),
              if (facts.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                _FactStrip(facts: facts, alert: alert),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FactStrip extends StatelessWidget {
  const _FactStrip({required this.facts, required this.alert});

  final List<_HeroFact> facts;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkBg.withAlpha(180),
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          for (var i = 0; i < facts.length; i++) ...[
            if (i > 0)
              Container(width: 1, height: 30, color: AppColors.darkBorder),
            Expanded(
              child: Column(
                children: [
                  Text(
                    '${facts[i].value}',
                    style: AppTypography.h3.copyWith(
                      color: alert && facts[i].value > 0
                          ? AppColors.error
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    facts[i].label,
                    style: AppTypography.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({
    required this.label,
    required this.count,
    required this.trailing,
  });

  final String label;
  final int count;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.darkSurfaceElevated,
            borderRadius: AppRadius.smAll,
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Text('$count', style: AppTypography.caption),
        ),
        const Spacer(),
        Text(trailing, style: AppTypography.caption),
      ],
    );
  }
}

class _HeroFact {
  const _HeroFact(this.label, this.value);
  final String label;
  final int value;
}

int _activeRank(TaskEntity task, DateTime now) {
  if (isOperationalOverdueTask(task, now)) return 0;
  return switch (task.status) {
    TaskStatus.started => 1,
    TaskStatus.rejected => 2,
    TaskStatus.pending => 3,
    _ => 4,
  };
}

int _compareDeadlines(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}

String _scopeLabel(ShiftFilter filter) => switch (filter) {
  ShiftFilter.all => 'All shifts',
  ShiftFilter.morning => 'Morning shift',
  ShiftFilter.night => 'Night shift',
};
