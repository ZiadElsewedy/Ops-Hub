import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/adaptive_scaffold.dart';
import 'package:opshub/core/widgets/app_motion.dart';
import 'package:opshub/core/extensions/context_extensions.dart';
import 'package:opshub/features/statistics/domain/entities/statistics_entity.dart';
import 'package:opshub/features/statistics/presentation/cubit/statistics_cubit.dart';
import 'package:opshub/features/statistics/presentation/cubit/statistics_state.dart';
import 'package:opshub/features/statistics/presentation/widgets/stat_grid.dart';

/// Admin → Analytics (Phase 9). The full operational metric wall, moved off the
/// (now KPI-only) Admin Home into its own page. Grouped into Workforce / Tasks /
/// Coverage sections for readability.
class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final user = context.currentUser;
    if (user != null) context.read<StatisticsCubit>().load(user);
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: 'Analytics',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded,
              color: AppColors.textSecondary),
          tooltip: 'Refresh',
          onPressed: _load,
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async => _load(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.pagePadding,
              AppSpacing.lg, AppSpacing.pagePadding, AppSpacing.xxxl),
          children: [
            BlocBuilder<StatisticsCubit, StatisticsState>(
              builder: (context, state) => state.maybeWhen(
                loaded: (s) => _sections(s),
                error: (m) => _errorCard(m),
                orElse: () => const StatGridSkeleton(count: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sections(StatisticsEntity s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section('Workforce', [
          StatItem('Branches', '${s.totalBranches}',
              Icons.store_mall_directory_outlined),
          StatItem('Managers', '${s.totalManagers}',
              Icons.supervisor_account_outlined),
          StatItem('Employees', '${s.totalEmployees}', Icons.groups_outlined),
          StatItem('Unstaffed branches', '${s.branchesWithoutManagers}',
              Icons.report_gmailerrorred_outlined),
        ]),
        const SizedBox(height: AppSpacing.xl),
        _section('Tasks', [
          StatItem('Active tasks', '${s.activeTasks}',
              Icons.assignment_outlined),
          StatItem('Completed', '${s.completedTasks}', Icons.task_alt_outlined),
          StatItem('Waiting reviews', '${s.waitingReviews}',
              Icons.rate_review_outlined),
          StatItem('Rejected today', '${s.rejectedTasksToday}',
              Icons.cancel_outlined),
        ]),
        const SizedBox(height: AppSpacing.xl),
        _section('Coverage', [
          StatItem(
              'Schedule coverage',
              '${s.branchesWithSchedule}/${s.totalBranches}',
              Icons.event_available_outlined),
          StatItem('No-manager branches', '${s.branchesWithoutManagers}',
              Icons.report_gmailerrorred_outlined),
        ]),
      ],
    );
  }

  Widget _section(String title, List<StatItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.labelSmall),
        const SizedBox(height: AppSpacing.md),
        EntranceFade(child: StatGrid(items: items)),
      ],
    );
  }

  Widget _errorCard(String message) {
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
