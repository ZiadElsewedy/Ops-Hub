import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/app_motion.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/features/chat/presentation/widgets/recent_messages_card.dart';
import 'package:drop/features/statistics/domain/entities/statistics_entity.dart';
import 'package:drop/features/statistics/presentation/cubit/statistics_cubit.dart';
import 'package:drop/features/statistics/presentation/cubit/statistics_state.dart';
import 'package:drop/features/statistics/presentation/widgets/dashboard_section.dart';
import 'package:drop/features/statistics/presentation/widgets/stat_grid.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/task/presentation/widgets/task_feed_section.dart';

/// Manager dashboard (Phase 6, +Phase 10 command-center layout): the manager's
/// own-branch operations at a glance — what needs attention first (active tasks,
/// waiting reviews), then team & today's shifts, then task breakdown.
class ManagerHomeScreen extends StatefulWidget {
  const ManagerHomeScreen({super.key});

  @override
  State<ManagerHomeScreen> createState() => _ManagerHomeScreenState();
}

class _ManagerHomeScreenState extends State<ManagerHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load({bool force = false}) {
    final user = context.currentUser;
    if (user != null) {
      context.read<StatisticsCubit>().load(user, forceRefresh: force);
      // Powers the on-home active-task feed (branch-scoped stream).
      context.read<TaskCubit>().load(user, forceRefresh: force);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _load(force: true),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        children: [
          BlocBuilder<StatisticsCubit, StatisticsState>(
            builder: (context, state) => state.maybeWhen(
              loaded: (s) => _content(s),
              error: (m) => _ErrorCard(message: m),
              orElse: () => const _LoadingSkeleton(),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const RecentMessagesCard(),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader('Active tasks'),
          const SizedBox(height: AppSpacing.md),
          // Branch stream is already scoped by TaskCubit → lock the scope UI.
          TaskFeedSection(
            branchLocked: true,
            branchId: context.currentUser?.branchId,
          ),
        ],
      ),
    );
  }

  Widget _content(StatisticsEntity s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Needs attention'),
        EntranceFade(
          child: Row(
            children: [
              Expanded(
                child: HeroStatCard(
                  label: 'Waiting reviews',
                  value: '${s.waitingReviews}',
                  icon: Icons.rate_review_outlined,
                  highlight: s.waitingReviews > 0,
                  onTap: () => context.push(RouteNames.managerTasks),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: HeroStatCard(
                  label: 'Active tasks',
                  value: '${s.activeTasks}',
                  icon: Icons.assignment_outlined,
                  onTap: () => context.push(RouteNames.managerTasks),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const SectionHeader('Team & shifts today'),
        EntranceFade(
          delay: staggerDelay(1),
          child: StatGrid(items: [
            StatItem('Employees', '${s.employeesInBranch}',
                Icons.groups_outlined),
            StatItem('Scheduled today', '${s.scheduledToday}',
                Icons.event_available_outlined),
            StatItem('Morning shift', '${s.morningShiftEmployees}',
                Icons.wb_sunny_outlined),
            StatItem('Night shift', '${s.nightShiftEmployees}',
                Icons.nightlight_outlined),
          ]),
        ),
        const SizedBox(height: AppSpacing.xl),
        const SectionHeader('Attendance'),
        EntranceFade(
          delay: staggerDelay(2),
          child: const _AttendanceTile(),
        ),
        const SizedBox(height: AppSpacing.xl),
        const SectionHeader('Tasks'),
        EntranceFade(
          delay: staggerDelay(3),
          child: StatGrid(items: [
            StatItem('Completed today', '${s.completedTasksToday}',
                Icons.task_alt_outlined),
            StatItem('Rejected', '${s.rejectedTasks}', Icons.cancel_outlined),
            StatItem('Daily', '${s.dailyTasks}', Icons.event_repeat_outlined),
            StatItem('Special', '${s.specialTasks}',
                Icons.star_outline_rounded),
          ]),
        ),
      ],
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader('Needs attention'),
        StatGridSkeleton(count: 2),
        SizedBox(height: AppSpacing.xl),
        SectionHeader('Team & shifts today'),
        StatGridSkeleton(count: 4),
      ],
    );
  }
}

/// A manager door to the branch Attendance ledger (`/attendance/review`) — the
/// manager's first attendance-oversight surface. Present on the home so mobile
/// managers (no desktop sidebar) can reach it too.
class _AttendanceTile extends StatelessWidget {
  const _AttendanceTile();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.darkSurface,
      borderRadius: AppRadius.cardAll,
      child: InkWell(
        onTap: () => context.push(RouteNames.attendanceReview),
        borderRadius: AppRadius.cardAll,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardAll,
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Row(
            children: [
              const Icon(Icons.fingerprint_rounded,
                  size: 20, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Branch attendance',
                        style: AppTypography.label
                            .copyWith(color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text('Review your team\'s clock-in history',
                        style: AppTypography.caption),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: AppColors.error),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(message,
                style: AppTypography.bodySmall.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
