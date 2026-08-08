import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/di/injection.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/core/widgets/rolling_number.dart';
import 'package:drop/core/widgets/skeleton.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:drop/features/branch/presentation/cubit/branch_state.dart';
import 'package:drop/features/sales/domain/entities/sales_month_snapshot.dart';
import 'package:drop/features/sales/domain/sales_branch_scope.dart';
import 'package:drop/features/sales/presentation/cubit/sales_admin_overview_cubit.dart';
import 'package:drop/features/sales/presentation/sales_format.dart';
import 'package:drop/features/sales/presentation/widgets/sales_progress_ring.dart';

/// Admin Home: how much each opted-in branch has achieved this month.
///
/// One row per branch, styled like the manager Home card — a compact emerald
/// progress ring, the branch name, the achieved figure (a [RollingNumber]
/// odometer) over its target, and the remainder.
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
                'of ${formatEgp(target.targetPiastres, withSuffix: true)}, '
                '${formatEgp(month.remainingPiastres, withSuffix: true)} '
                'remaining',
      child: InkWell(
        onTap: () => context.push(RouteNames.salesManageFor(branch.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: ExcludeSemantics(
            child: Row(
              children: [
                // The same compact emerald gauge the manager card leads with —
                // a still slot while loading, an empty ring when no target.
                _MiniRing(
                  ratio: (loading || target == null)
                      ? 0
                      : month!.progressRatioCapped,
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        branch.name,
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textTertiary,
                          letterSpacing: 1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (loading) ...[
                        const Skeleton(height: 22, width: 160),
                        const SizedBox(height: 6),
                        const Skeleton(height: 12, width: 120),
                      ] else if (target == null)
                        Text(
                          'No target this month',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        )
                      else ...[
                        // achieved (emerald, rolling) / target (grey, static)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              RollingNumber(
                                value: month!.approvedTotalPiastres,
                                formatter: (v) => formatEgp(v.round()),
                                animateOnMount: true,
                                duration: const Duration(milliseconds: 700),
                                perPlaceStep: const Duration(milliseconds: 40),
                                maxExtra: const Duration(milliseconds: 320),
                                style: AppTypography.h3.copyWith(
                                  color: AppColors.salesEmerald,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              Text(
                                ' / ${formatEgp(target.targetPiastres)}',
                                maxLines: 1,
                                style: AppTypography.body.copyWith(
                                  color: AppColors.textTertiary,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        RollingNumber(
                          value: month.remainingPiastres,
                          formatter: (v) =>
                              '${formatEgp(v.round())} EGP remaining',
                          animateOnMount: true,
                          delay: const Duration(milliseconds: 220),
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ],
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

/// A compact, empty-centred gauge — the same emerald arc the manager Home card
/// leads with, sweeping in on the shared premium curve. No figure inside; the
/// figures sit beside it.
class _MiniRing extends StatelessWidget {
  const _MiniRing({required this.ratio});

  final double ratio;

  @override
  Widget build(BuildContext context) {
    final capped = ratio.isNaN ? 0.0 : ratio.clamp(0.0, 1.0).toDouble();
    return SizedBox(
      width: 48,
      height: 48,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: capped),
        duration: const Duration(milliseconds: 2800),
        curve: kReelSettle,
        builder: (context, value, _) => CustomPaint(
          painter: SalesRingPainter(
            ratio: value,
            stroke: 6,
            arcColor: AppColors.salesEmerald,
            arcColorEnd: AppColors.salesEmeraldGlow,
            glow: true,
          ),
        ),
      ),
    );
  }
}
