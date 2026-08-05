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
import 'package:drop/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:drop/features/branch/presentation/cubit/branch_state.dart';
import 'package:drop/features/sales/domain/entities/sales_month_snapshot.dart';
import 'package:drop/features/sales/presentation/cubit/sales_admin_overview_cubit.dart';
import 'package:drop/features/sales/presentation/widgets/sales_progress_strip.dart';

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
      builder: (context, branchState) => BlocBuilder<
        SalesAdminOverviewCubit,
        SalesAdminOverviewState
      >(
        builder: (context, salesState) {
          final branchError = branchState.maybeWhen(
            error: (message) => message,
            orElse: () => null,
          );
          if (branchError != null) {
            return AppProblemPanel(
              title: 'Branches unavailable',
              message: branchError,
              onRetry: _load,
            );
          }
          final branches = branchState.maybeWhen(
            loaded: (branches, _) => branches,
            orElse: () => null,
          );
          if (branches == null ||
              salesState is SalesAdminOverviewLoading) {
            return const ListSkeleton();
          }
          if (salesState is SalesAdminOverviewError) {
            return AppProblemPanel(
              title: 'Sales unavailable',
              message: salesState.message,
              onRetry: _load,
            );
          }
          final snapshots = (salesState as SalesAdminOverviewLoaded)
              .snapshotsByBranchId;
          if (branches.isEmpty) {
            return const DropEmptyState(
              title: 'No branches yet',
              message: 'Create a branch to start tracking monthly sales.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            children: [
              const PageHero(
                eyebrow: 'Branch ledger',
                title: 'Branch sales',
                subtitle: 'Track monthly targets across every branch.',
              ),
              const SizedBox(height: AppSpacing.xl),
              for (final branch in branches) ...[
                _BranchSalesRow(
                  branchId: branch.id,
                  branchName: branch.name,
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
  const _BranchSalesRow({
    required this.branchId,
    required this.branchName,
    required this.snapshot,
  });

  final String branchId;
  final String branchName;
  final SalesMonthSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final hasTarget = snapshot?.target != null;
    return Semantics(
      button: true,
      label: '$branchName branch sales',
      child: GlassContainer(
        onTap: () => context.push(
          '${RouteNames.salesManage}?branchId=${Uri.encodeQueryComponent(branchId)}',
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(branchName, style: AppTypography.h3)),
                const Icon(
                  Icons.arrow_outward_rounded,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (hasTarget)
              SalesProgressStrip(
                ratioCapped: snapshot!.progressRatioCapped,
                ratioRaw: snapshot!.progressRatioRaw,
                remainingPiastres: snapshot!.remainingPiastres,
              )
            else
              Text('Target not set', style: AppTypography.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${snapshot?.pending.length ?? 0} pending',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
