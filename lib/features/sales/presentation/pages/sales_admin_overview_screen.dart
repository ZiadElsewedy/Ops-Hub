import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/app_error_state.dart';
import 'package:drop/core/widgets/drop_empty_state.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/core/widgets/list_skeleton.dart';
import 'package:drop/core/widgets/page_hero.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:drop/features/branch/presentation/cubit/branch_state.dart';
import 'package:drop/features/sales/domain/entities/sales_month_snapshot.dart';
import 'package:drop/features/sales/presentation/cubit/sales_admin_overview_cubit.dart';
import 'package:drop/features/sales/presentation/sales_format.dart';
import 'package:drop/features/sales/presentation/widgets/sales_progress_strip.dart';

/// Every branch's monthly sales at a glance. Branches that have not opted in are
/// listed but visibly off, so an admin can see the whole estate and knows the
/// switch lives in branch settings rather than here.
class SalesAdminOverviewScreen extends StatefulWidget {
  const SalesAdminOverviewScreen({super.key});

  @override
  State<SalesAdminOverviewScreen> createState() =>
      _SalesAdminOverviewScreenState();
}

class _SalesAdminOverviewScreenState extends State<SalesAdminOverviewScreen> {
  void _load() {
    context.read<SalesAdminOverviewCubit>().load();
    context.read<BranchCubit>().loadIfNeeded();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) => AdaptiveScaffold(
    title: 'Branch sales',
    body: BlocBuilder<BranchCubit, BranchState>(
      builder: (context, branchState) =>
          BlocBuilder<SalesAdminOverviewCubit, SalesAdminOverviewState>(
            builder: (context, salesState) {
              final branchError = branchState.maybeWhen(
                error: (message) => message,
                orElse: () => null,
              );
              if (branchError != null) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.pagePadding),
                  child: AppProblemPanel(
                    title: 'Branches unavailable',
                    message: branchError,
                    onRetry: _load,
                  ),
                );
              }
              final branches = branchState.maybeWhen(
                loaded: (branches, _) => branches,
                orElse: () => null,
              );
              if (branches == null || salesState is SalesAdminOverviewLoading) {
                return const ListSkeleton();
              }
              if (salesState is SalesAdminOverviewError) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.pagePadding),
                  child: AppProblemPanel(
                    title: 'Sales unavailable',
                    message: salesState.message,
                    onRetry: _load,
                  ),
                );
              }
              final snapshots =
                  (salesState as SalesAdminOverviewLoaded).snapshotsByBranchId;
              if (branches.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(AppSpacing.pagePadding),
                  child: DropEmptyState(
                    title: 'No branches yet',
                    message: 'Create a branch to start tracking monthly sales.',
                  ),
                );
              }

              // Opted-in branches first: those are the ones that need attention.
              final ordered = [...branches]
                ..sort((a, b) {
                  if (a.salesTargetEnabled == b.salesTargetEnabled) {
                    return a.name.compareTo(b.name);
                  }
                  return a.salesTargetEnabled ? -1 : 1;
                });
              final enabledCount = ordered
                  .where((branch) => branch.salesTargetEnabled)
                  .length;

              return ListView(
                padding: const EdgeInsets.all(AppSpacing.pagePadding),
                children: [
                  PageHero(
                    eyebrow: 'Branch ledger',
                    title: 'Branch sales',
                    subtitle:
                        '$enabledCount of ${ordered.length} '
                        '${ordered.length == 1 ? 'branch runs' : 'branches run'} '
                        'a monthly target. Turn a branch on or off in its branch '
                        'settings.',
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  for (final branch in ordered) ...[
                    _BranchSalesRow(
                      branch: branch,
                      snapshot: snapshots[branch.id],
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],
              );
            },
          ),
    ),
  );
}

class _BranchSalesRow extends StatelessWidget {
  const _BranchSalesRow({required this.branch, required this.snapshot});

  final BranchEntity branch;
  final SalesMonthSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final enabled = branch.salesTargetEnabled;
    final month = snapshot;
    final hasTarget = month?.target != null;
    final pending = month?.pending.length ?? 0;

    return Semantics(
      button: enabled,
      label: enabled
          ? '${branch.name} branch sales'
          : '${branch.name}, monthly target off',
      child: GlassContainer(
        onTap: enabled
            ? () => context.push(RouteNames.salesManageFor(branch.id))
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    branch.name,
                    style: AppTypography.h3.copyWith(
                      color: enabled
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
                  ),
                ),
                if (enabled)
                  const Icon(
                    Icons.arrow_outward_rounded,
                    color: AppColors.textTertiary,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (!enabled)
              Text(
                'Monthly target off — no sales workflow for this branch.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              )
            else if (hasTarget) ...[
              SalesProgressStrip(
                ratioCapped: month!.progressRatioCapped,
                ratioRaw: month.progressRatioRaw,
                remainingPiastres: month.remainingPiastres,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                pending == 0
                    ? '${formatEgp(month.approvedTotalPiastres, withSuffix: true)} approved · nothing waiting'
                    : '${formatEgp(month.approvedTotalPiastres, withSuffix: true)} approved · '
                          '$pending ${pending == 1 ? 'day' : 'days'} awaiting review',
                style: AppTypography.caption.copyWith(
                  color: pending == 0
                      ? AppColors.textTertiary
                      : AppColors.textSecondary,
                ),
              ),
            ] else
              Text(
                'No target set for this month — open the branch to set one.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
