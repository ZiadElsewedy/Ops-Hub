import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/app_error_state.dart';
import 'package:drop/core/widgets/attention_panel.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/core/widgets/list_skeleton.dart';
import 'package:drop/core/widgets/metric_tile.dart';
import 'package:drop/core/widgets/page_hero.dart';
import 'package:drop/features/sales/presentation/cubit/sales_manager_dashboard_cubit.dart';
import 'package:drop/features/sales/presentation/sales_format.dart';
import 'package:drop/features/sales/presentation/widgets/sales_progress_strip.dart';
import 'package:drop/features/sales/presentation/widgets/sales_reason_sheet.dart';
import 'package:drop/features/sales/presentation/widgets/sales_submission_tile.dart';
import 'package:drop/features/sales/presentation/widgets/sales_target_editor_sheet.dart';

class SalesManagerDashboardScreen extends StatefulWidget {
  const SalesManagerDashboardScreen({super.key});
  @override
  State<SalesManagerDashboardScreen> createState() =>
      _SalesManagerDashboardScreenState();
}

class _SalesManagerDashboardScreenState
    extends State<SalesManagerDashboardScreen> {
  String? get _branchId => context.currentUser?.branchId;
  void _load() {
    final id = _branchId;
    if (id != null && id.isNotEmpty) {
      context.read<SalesManagerDashboardCubit>().loadForBranch(branchId: id);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) => AdaptiveScaffold(
    title: 'Branch sales',
    body: BlocBuilder<SalesManagerDashboardCubit, SalesManagerDashboardState>(
      builder: (context, state) {
        if (state is SalesManagerDashboardLoading) return const ListSkeleton();
        if (state is SalesManagerDashboardError) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            child: AppProblemPanel(
              title: 'Sales unavailable',
              message: state.message,
              onRetry: _load,
            ),
          );
        }
        final loaded = state as SalesManagerDashboardLoaded;
        final snapshot = loaded.snapshot;
        final cubit = context.read<SalesManagerDashboardCubit>();
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          children: [
            PageHero(
              eyebrow: 'Branch ledger',
              title: 'Branch sales',
              subtitle: 'Approve daily closes and track the monthly target.',
              trailing: [
                TextButton(
                  onPressed: () async {
                    final result = await showSalesTargetEditorSheet(
                      context,
                      title: 'Edit monthly target',
                      initialAmount: snapshot.target == null
                          ? null
                          : formatEgp(snapshot.target!.targetPiastres),
                    );
                    if (result != null) {
                      cubit.setTarget(
                        result.amountPiastres,
                        result.reason,
                        expectedTargetRevision: snapshot.target?.targetRevision,
                      );
                    }
                  },
                  child: const Text('Edit monthly target'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            GlassContainer(
              child: SalesProgressStrip(
                ratioCapped: snapshot.progressRatioCapped,
                ratioRaw: snapshot.progressRatioRaw,
                remainingPiastres: snapshot.remainingPiastres,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AttentionPanel(
              signals: [
                AttentionSignal(
                  id: 'pending',
                  count: snapshot.pending.length,
                  accent: AppColors.primary,
                  icon: Icons.pending_actions_rounded,
                  label: 'Pending sales',
                  sublabel: 'Awaiting approval',
                  onTap: () {},
                ),
                AttentionSignal(
                  id: 'correction',
                  count: snapshot.correctionRequested.length,
                  accent: AppColors.error,
                  icon: Icons.edit_note_rounded,
                  label: 'Corrections requested',
                  sublabel: 'Awaiting resubmission',
                  onTap: () {},
                ),
              ],
            ),
            for (final item in [
              ...snapshot.pending,
              ...snapshot.correctionRequested,
            ])
              SalesSubmissionTile(
                submission: item,
                busy: loaded.isBusy(item.id),
                onTap: () =>
                    context.push(RouteNames.salesSubmissionDetail(item.id)),
                onApprove: item.isPending ? () => cubit.approve(item.id) : null,
                onReject: item.isPending
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
            const SizedBox(height: AppSpacing.xl),
            MetricTileRow(
              tiles: [
                MetricTile(
                  value: snapshot.approved.length,
                  label: 'Approved',
                  icon: Icons.check_rounded,
                  onTap: () => context.push(RouteNames.salesHistory),
                ),
                MetricTile(
                  value: snapshot.rejected.length,
                  label: 'Rejected',
                  icon: Icons.close_rounded,
                  onTap: () => context.push(RouteNames.salesHistory),
                ),
                MetricTile(
                  value: snapshot.submissions.length,
                  label: 'History',
                  icon: Icons.history_rounded,
                  onTap: () => context.push(RouteNames.salesHistory),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}
