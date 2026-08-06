import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/di/injection.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/core/widgets/skeleton.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:drop/features/branch/presentation/cubit/branch_state.dart';
import 'package:drop/features/sales/domain/entities/sales_month_snapshot.dart';
import 'package:drop/features/sales/domain/sales_branch_scope.dart';
import 'package:drop/features/sales/presentation/cubit/sales_admin_overview_cubit.dart';
import 'package:drop/features/sales/presentation/sales_format.dart';

/// Admin Home: how much each opted-in branch has achieved this month.
///
/// One line per branch — name, achieved, and the target it is measured against.
/// Branches with `salesTargetEnabled == false` never appear, and when **no**
/// branch runs a target the whole module (its heading included) renders nothing
/// rather than an empty box.
///
/// Owns its own [SalesAdminOverviewCubit] so Home does not have to hold a
/// feature cubit it uses in one place; [BranchCubit] is app-wide and already
/// loaded by the dashboard.
class AdminBranchSalesSummary extends StatelessWidget {
  const AdminBranchSalesSummary({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => AppDependencies.createSalesAdminOverviewCubit()..load(),
    child: const _AdminBranchSalesSummaryView(),
  );
}

class _AdminBranchSalesSummaryView extends StatelessWidget {
  const _AdminBranchSalesSummaryView();

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<BranchCubit, BranchState>(
        builder: (context, branchState) {
          final branches = branchState.maybeWhen(
            loaded: (branches, _) => branches,
            orElse: () => const <BranchEntity>[],
          );
          final enabled = salesEnabledBranches(branches);
          // Nothing opted in (or branches not loaded yet) ⇒ no module at all.
          if (enabled.isEmpty) return const SizedBox.shrink();

          return BlocBuilder<SalesAdminOverviewCubit, SalesAdminOverviewState>(
            builder: (context, salesState) {
              if (salesState is SalesAdminOverviewError) {
                return const SizedBox.shrink();
              }
              final snapshots = salesState is SalesAdminOverviewLoaded
                  ? salesState.snapshotsByBranchId
                  : null;

              // The module owns its own leading gap so an opted-out estate
              // leaves no unexplained space on Home.
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.xl),
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Branch sales',
                            style: AppTypography.labelLarge,
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              context.push(RouteNames.salesAdminOverview),
                          child: const Text('See all'),
                        ),
                      ],
                    ),
                  ),
                  GlassContainer(
                    child: Column(
                      children: [
                        for (var i = 0; i < enabled.length; i++) ...[
                          if (i > 0)
                            const Divider(
                              height: AppSpacing.lg,
                              color: AppColors.darkBorder,
                            ),
                          _BranchLine(
                            branch: enabled[i],
                            snapshot: snapshots?[enabled[i].id],
                            loading: snapshots == null,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
}

class _BranchLine extends StatelessWidget {
  const _BranchLine({
    required this.branch,
    required this.snapshot,
    required this.loading,
  });

  final BranchEntity branch;
  final SalesMonthSnapshot? snapshot;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final month = snapshot;
    final target = month?.target;
    return Semantics(
      button: true,
      label: target == null
          ? '${branch.name}, no target this month'
          : '${branch.name}, achieved '
                '${formatEgp(month!.approvedTotalPiastres, withSuffix: true)} '
                'of ${formatEgp(target.targetPiastres, withSuffix: true)}',
      child: InkWell(
        onTap: () => context.push(RouteNames.salesManageFor(branch.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: ExcludeSemantics(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    branch.name,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                if (loading)
                  const Skeleton(height: 14, width: 96)
                else if (target == null)
                  Text(
                    'No target',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  )
                else
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: formatEgp(month!.approvedTotalPiastres),
                          style: AppTypography.label.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        TextSpan(
                          text:
                              ' of ${formatEgp(target.targetPiastres)} EGP',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textQuaternary,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
