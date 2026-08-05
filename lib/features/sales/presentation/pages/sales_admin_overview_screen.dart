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
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:drop/features/branch/presentation/cubit/branch_state.dart';
import 'package:drop/features/sales/domain/entities/sales_month_snapshot.dart';
import 'package:drop/features/sales/domain/sales_branch_scope.dart';
import 'package:drop/features/sales/presentation/cubit/sales_admin_overview_cubit.dart';
import 'package:drop/features/sales/presentation/widgets/sales_money_row.dart';

/// Every branch that runs a monthly target, showing **target · achieved ·
/// remaining** and nothing else.
///
/// Branches that have not opted in are not listed at all — an admin who wants to
/// turn one on goes to Branches, and a page of greyed-out rows was noise on the
/// way to the branches that are actually selling.
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
              final enabled = salesEnabledBranches(branches);

              if (enabled.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(AppSpacing.pagePadding),
                  child: DropEmptyState(
                    title: 'No branch runs a sales target',
                    message:
                        'Turn on the monthly sales target in a branch’s settings '
                        'to start tracking it here.',
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pagePadding,
                  AppSpacing.lg,
                  AppSpacing.pagePadding,
                  AppSpacing.xxl,
                ),
                itemCount: enabled.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) => _BranchSalesRow(
                  branch: enabled[index],
                  snapshot: snapshots[enabled[index].id],
                ),
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
    final month = snapshot;
    final target = month?.target;

    return Semantics(
      button: true,
      label: '${branch.name} branch sales',
      child: GlassContainer(
        onTap: () => context.push(RouteNames.salesManageFor(branch.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    branch.name,
                    style: AppTypography.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (target == null)
              Text(
                'No target set for this month.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              )
            else
              SalesMoneyRow(
                targetPiastres: target.targetPiastres,
                achievedPiastres: month!.approvedTotalPiastres,
                remainingPiastres: month.remainingPiastres,
                compact: true,
              ),
          ],
        ),
      ),
    );
  }
}
