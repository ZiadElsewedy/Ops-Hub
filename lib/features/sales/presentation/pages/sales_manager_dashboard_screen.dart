import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/app_error_state.dart';
import 'package:drop/core/widgets/app_snackbar.dart';
import 'package:drop/core/widgets/brand_watermark.dart';
import 'package:drop/core/widgets/drop_empty_state.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/core/widgets/list_skeleton.dart';
import 'package:drop/features/sales/presentation/cubit/sales_manager_dashboard_cubit.dart';
import 'package:drop/features/sales/domain/sales_calculator.dart';
import 'package:drop/features/sales/domain/sales_kpis_calculator.dart';
import 'package:drop/features/sales/domain/sales_trend.dart';
import 'package:drop/features/sales/presentation/sales_format.dart';
import 'package:drop/features/sales/presentation/widgets/sales_month_overview.dart';
import 'package:drop/features/sales/presentation/widgets/sales_needed_per_day.dart';
import 'package:drop/features/sales/presentation/widgets/sales_pace_card.dart';
import 'package:drop/features/sales/presentation/widgets/sales_reason_sheet.dart';
import 'package:drop/features/sales/presentation/widgets/sales_submission_tile.dart';
import 'package:drop/features/sales/presentation/widgets/sales_submissions_door.dart';
import 'package:drop/features/sales/presentation/widgets/sales_target_editor_sheet.dart';

/// The branch sales dashboard, top to bottom: the **month** (achieved · a
/// progress ring · remaining, then the target), what **today** needs, the
/// **queue** to act on, **one door** into the full ledger, and a **Pace** card
/// (the target verdict + the last-7-days chart).
///
/// The four filtered tiles were collapsed to one door — they opened the same
/// list screen — and the old pace strip returned as a single card that pairs the
/// "are we going to make it?" verdict with the trend that backs it, rather than
/// restating the month from four angles.
class SalesManagerDashboardScreen extends StatefulWidget {
  const SalesManagerDashboardScreen({super.key, this.branchId});
  final String? branchId;
  @override
  State<SalesManagerDashboardScreen> createState() =>
      _SalesManagerDashboardScreenState();
}

class _SalesManagerDashboardScreenState
    extends State<SalesManagerDashboardScreen> {
  String? get _branchId => widget.branchId ?? context.currentUser?.branchId;

  void _load({bool force = false}) {
    final id = _branchId;
    if (id != null) {
      context.read<SalesManagerDashboardCubit>().loadForBranch(
        branchId: id,
        force: force,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// Set and Edit are the same server action; only the wording changes.
  Future<void> _editTarget(
    SalesManagerDashboardCubit cubit,
    int? currentPiastres,
    int? revision,
  ) async {
    final creating = currentPiastres == null;
    final result = await showSalesTargetEditorSheet(
      context,
      title: creating ? 'Set monthly target' : 'Edit monthly target',
      subtitle: creating
          ? 'Employees can submit daily sales once a target exists.'
          : 'Everyone in this branch is told when the target changes.',
      initialAmount: creating ? null : formatEgp(currentPiastres),
      confirmLabel: creating ? 'Set target' : 'Save target',
    );
    if (result == null) return;
    await cubit.setTarget(
      result.amountPiastres,
      result.reason,
      expectedTargetRevision: revision,
    );
  }

  @override
  Widget build(BuildContext context) => AdaptiveScaffold(
    title: 'Branch sales',
    body: BlocConsumer<SalesManagerDashboardCubit, SalesManagerDashboardState>(
      listenWhen: (previous, current) =>
          current is SalesManagerDashboardLoaded && current.message != null,
      listener: (context, state) {
        final message = (state as SalesManagerDashboardLoaded).message!;
        final ok =
            message.endsWith('approved.') ||
            message.endsWith('rejected.') ||
            message.endsWith('requested.') ||
            message.endsWith('updated.') ||
            message.endsWith('set.');
        ok
            ? AppSnackbar.success(context, message)
            : AppSnackbar.error(context, message);
      },
      builder: (context, state) {
        if (state is SalesManagerDashboardLoading) return const ListSkeleton();
        if (state is SalesManagerDashboardDisabled) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            child: DropEmptyState(
              title: 'Sales targets are off',
              message:
                  '${state.branchName ?? 'This branch'} doesn’t run a monthly '
                  'sales target. An admin turns it on in the branch settings.',
            ),
          );
        }
        if (state is SalesManagerDashboardError) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            child: AppProblemPanel(
              title: 'Sales unavailable',
              message: state.message,
              onRetry: () => _load(force: true),
            ),
          );
        }
        final loaded = state as SalesManagerDashboardLoaded;
        final snapshot = loaded.snapshot;
        final cubit = context.read<SalesManagerDashboardCubit>();
        final target = snapshot.target;
        final branchId = _branchId ?? '';
        // One `now` feeds both derivations so the KPIs and the trend cannot
        // disagree about which Cairo day it is.
        final now = DateTime.now();
        final kpis = computeSalesKpis(snapshot, now: now);
        final trend = computeSalesTrend(snapshot, now: now);
        final outlook = salesTargetOutlook(
          expectedMonthEndPiastres: kpis.expectedMonthEndPiastres,
          targetPiastres: target?.targetPiastres ?? 0,
          approvedDayCount: kpis.approvedDayCount,
        );
        final queue = [...snapshot.pending, ...snapshot.correctionRequested]
          ..sort((a, b) => b.businessDateKey.compareTo(a.businessDateKey));

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pagePadding,
            AppSpacing.lg,
            AppSpacing.pagePadding,
            AppSpacing.xxl,
          ),
          children: [
            // ── The month ──────────────────────────────────────────────
            GlassContainer(
              child: BrandWatermark(
                opacity: 0.05,
                assetLogo: true,
                assetHeight: 52,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${(loaded.branchName ?? 'Branch').toUpperCase()} · '
                            '${formatBusinessMonth(loaded.monthKey).toUpperCase()}',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textTertiary,
                              letterSpacing: 1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton(
                          onPressed: loaded.isBusyAnywhere
                              ? null
                              : () => _editTarget(
                                  cubit,
                                  target?.targetPiastres,
                                  target?.targetRevision,
                                ),
                          child: Text(
                            target == null ? 'Set target' : 'Edit target',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (target == null)
                      Text(
                        'No target for this month. Set one to open daily sales '
                        'submissions for this branch.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      )
                    else
                      SalesMonthOverview(
                        targetPiastres: target.targetPiastres,
                        achievedPiastres: snapshot.approvedTotalPiastres,
                        remainingPiastres: snapshot.remainingPiastres,
                        progressRatio: snapshot.progressRatioCapped,
                      ),
                  ],
                ),
              ),
            ),

            // ── What today needs ───────────────────────────────────────
            if (target != null) ...[
              const SizedBox(height: AppSpacing.lg),
              SalesNeededPerDay(
                neededPerDayPiastres: kpis.neededPerDayPiastres,
                todayPiastres: loaded.todayPiastres,
                daysRemaining: kpis.daysRemaining,
              ),
            ],

            // ── Act on these ───────────────────────────────────────────
            if (queue.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              Text('Waiting on you', style: AppTypography.labelLarge),
              const SizedBox(height: AppSpacing.md),
              for (final item in queue)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: SalesSubmissionTile(
                    submission: item,
                    busy: loaded.isBusy(item.id),
                    onTap: () =>
                        context.push(RouteNames.salesSubmissionDetail(item.id)),
                    onApprove: item.isPending && !loaded.isBusyAnywhere
                        ? () => cubit.approve(item.id)
                        : null,
                    onReject: item.isPending && !loaded.isBusyAnywhere
                        ? () async {
                            final reason = await showSalesReasonSheet(
                              context,
                              title: 'Reject sales',
                              confirmLabel: 'Reject',
                            );
                            if (reason != null) cubit.reject(item.id, reason);
                          }
                        : null,
                  ),
                ),
            ],

            // ── One door into the whole ledger ─────────────────────────
            if (target != null) ...[
              const SizedBox(height: AppSpacing.xl),
              SalesSubmissionsDoor(
                pending: snapshot.pending.length,
                approved: snapshot.approved.length,
                rejected: snapshot.rejected.length,
                total: snapshot.submissions.length,
                onTap: () => context.push(
                  RouteNames.salesHistoryFor(branchId: branchId),
                ),
              ),
            ],

            // ── Pace: the verdict + the last-7-days trend ──────────────
            if (target != null && trend.hasAnyApproved) ...[
              const SizedBox(height: AppSpacing.lg),
              SalesPaceCard(
                trend: trend,
                outlook: outlook,
                projectedDeltaPiastres:
                    kpis.expectedMonthEndPiastres - target.targetPiastres,
              ),
            ],
          ],
        );
      },
    ),
  );
}
