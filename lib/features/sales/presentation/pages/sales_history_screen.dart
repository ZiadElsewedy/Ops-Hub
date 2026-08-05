import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/enums/sales_submission_status.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/app_error_state.dart';
import 'package:drop/core/widgets/drop_empty_state.dart';
import 'package:drop/core/widgets/list_skeleton.dart';
import 'package:drop/core/widgets/page_hero.dart';
import 'package:drop/core/widgets/stat_strip.dart';
import 'package:drop/features/sales/domain/entities/daily_sales_submission_entity.dart';
import 'package:drop/features/sales/domain/sales_business_time.dart';
import 'package:drop/features/sales/presentation/cubit/sales_manager_dashboard_cubit.dart';
import 'package:drop/features/sales/presentation/sales_format.dart';
import 'package:drop/features/sales/presentation/widgets/sales_submission_tile.dart';

/// The branch sales ledger for one month, optionally filtered to one status.
///
/// Manager/admin only: it reads every submission in the branch-month, which
/// `firestore.rules` grants to those two roles alone. An employee's own ledger
/// is on their sales page (`/sales/mine`).
class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key, required this.branchId, this.status});

  final String branchId;

  /// A [SalesSubmissionStatus] name, or null for every status.
  final String? status;

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  late String _monthKey;
  late SalesSubmissionStatus? _filter;

  @override
  void initState() {
    super.initState();
    _monthKey = businessMonthKey(DateTime.now());
    _filter = _parseStatus(widget.status);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// An unknown `?status=` is treated as "no filter" rather than as an empty
  /// list — a stale link must not look like a branch with no sales.
  static SalesSubmissionStatus? _parseStatus(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'all') return null;
    for (final status in SalesSubmissionStatus.values) {
      if (status.name == raw) return status;
    }
    return null;
  }

  void _load({bool force = false}) {
    if (widget.branchId.isEmpty) return;
    context.read<SalesManagerDashboardCubit>().loadForBranch(
      branchId: widget.branchId,
      monthKey: _monthKey,
      force: force,
    );
  }

  DateTime get _month =>
      businessMonthFromKey(_monthKey) ?? DateTime.now();

  bool get _isCurrentMonth => _monthKey == businessMonthKey(DateTime.now());

  void _moveMonth(int delta) {
    final next = DateTime(_month.year, _month.month + delta);
    final nextKey =
        '${next.year.toString().padLeft(4, '0')}${next.month.toString().padLeft(2, '0')}';
    // Never page into the future: a month that has not started has no ledger.
    if (nextKey.compareTo(businessMonthKey(DateTime.now())) > 0) return;
    setState(() => _monthKey = nextKey);
    _load();
  }

  @override
  Widget build(BuildContext context) => AdaptiveScaffold(
    title: 'Sales history',
    body: BlocBuilder<SalesManagerDashboardCubit, SalesManagerDashboardState>(
      builder: (context, state) {
        if (state is SalesManagerDashboardLoading) return const ListSkeleton();
        if (state is SalesManagerDashboardDisabled) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            child: DropEmptyState(
              title: 'Sales targets are off',
              message:
                  '${state.branchName ?? 'This branch'} doesn’t run a monthly '
                  'sales target, so it has no sales ledger.',
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
        final entries = <DailySalesSubmissionEntity>[
          for (final sale in snapshot.newestFirst)
            if (_filter == null || sale.status == _filter) sale,
        ];

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          children: [
            PageHero(
              eyebrow: loaded.branchName ?? 'Branch ledger',
              title: 'Sales history',
              trailing: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _moveMonth(-1),
                      tooltip: 'Previous month',
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Text(formatBusinessMonth(_monthKey)),
                    IconButton(
                      onPressed: _isCurrentMonth ? null : () => _moveMonth(1),
                      tooltip: 'Next month',
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            StatStrip(
              stats: [
                Stat(
                  label: 'Target',
                  value: snapshot.hasTarget
                      ? formatEgp(
                          snapshot.target!.targetPiastres,
                          withSuffix: true,
                        )
                      : 'Not set',
                ),
                Stat(
                  label: 'Approved',
                  value: formatEgp(
                    snapshot.approvedTotalPiastres,
                    withSuffix: true,
                  ),
                ),
                Stat(
                  label: 'Progress',
                  value: snapshot.hasTarget
                      ? '${(snapshot.progressRatioRaw * 100).round()}%'
                      : '—',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _StatusFilterBar(
              selected: _filter,
              counts: {
                SalesSubmissionStatus.pending: snapshot.pending.length,
                SalesSubmissionStatus.approved: snapshot.approved.length,
                SalesSubmissionStatus.rejected: snapshot.rejected.length,
                SalesSubmissionStatus.correctionRequested:
                    snapshot.correctionRequested.length,
              },
              total: snapshot.submissions.length,
              onSelected: (status) => setState(() => _filter = status),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (entries.isEmpty)
              DropEmptyState(
                title: _filter == null
                    ? 'No sales submissions'
                    : 'Nothing ${_filterLabel(_filter!).toLowerCase()}',
                message: _filter == null
                    ? 'There are no daily sales submissions for this month.'
                    : 'No day in ${formatBusinessMonth(_monthKey)} is '
                          '${_filterLabel(_filter!).toLowerCase()}.',
              ),
            for (final sale in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: SalesSubmissionTile(
                  submission: sale,
                  onTap: () =>
                      context.push(RouteNames.salesSubmissionDetail(sale.id)),
                ),
              ),
          ],
        );
      },
    ),
  );
}

String _filterLabel(SalesSubmissionStatus status) => switch (status) {
  SalesSubmissionStatus.pending => 'Pending',
  SalesSubmissionStatus.approved => 'Approved',
  SalesSubmissionStatus.rejected => 'Rejected',
  SalesSubmissionStatus.correctionRequested => 'Needs correction',
};

/// One row of monochrome status chips. The dashboard's tiles land here already
/// filtered; these let a manager move between statuses without going back.
class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({
    required this.selected,
    required this.counts,
    required this.total,
    required this.onSelected,
  });

  final SalesSubmissionStatus? selected;
  final Map<SalesSubmissionStatus, int> counts;
  final int total;
  final ValueChanged<SalesSubmissionStatus?> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        _Chip(
          label: 'All',
          count: total,
          selected: selected == null,
          onTap: () => onSelected(null),
        ),
        for (final status in SalesSubmissionStatus.values)
          _Chip(
            label: _filterLabel(status),
            count: counts[status] ?? 0,
            selected: selected == status,
            onTap: () => onSelected(status),
          ),
      ],
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: AppSpacing.sm),
    child: Semantics(
      selected: selected,
      button: true,
      child: ChoiceChip(
        label: Text('$label · $count'),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        backgroundColor: AppColors.darkSurface,
        selectedColor: AppColors.primary,
      ),
    ),
  );
}
