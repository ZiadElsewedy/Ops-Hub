import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:opshub/core/enums/sales_submission_status.dart';
import 'package:opshub/core/routes/route_names.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/adaptive_scaffold.dart';
import 'package:opshub/core/widgets/app_error_state.dart';
import 'package:opshub/core/widgets/opshub_empty_state.dart';
import 'package:opshub/core/widgets/list_skeleton.dart';
import 'package:opshub/features/sales/domain/entities/daily_sales_submission_entity.dart';
import 'package:opshub/features/sales/domain/entities/sales_month_snapshot.dart';
import 'package:opshub/features/sales/domain/sales_business_time.dart';
import 'package:opshub/features/sales/presentation/cubit/sales_manager_dashboard_cubit.dart';
import 'package:opshub/features/sales/presentation/sales_format.dart';
import 'package:opshub/features/sales/presentation/widgets/sales_submission_tile.dart';

/// The branch sales ledger for one month, filtered to one status.
///
/// Pending / Approved / Rejected / History are **four destinations**, not one:
/// each arrives with its own filter, its own page title and its own empty state,
/// so a manager always knows which list they are looking at. The chips let them
/// move between the four without going back.
///
/// Manager/admin only: it reads every submission in the branch-month, which
/// `firestore.rules` grants to those two roles alone. An employee's own records
/// live on their sales page (`/sales/mine`).
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

  DateTime get _month => businessMonthFromKey(_monthKey) ?? DateTime.now();

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
    title: _pageTitle(_filter),
    body: BlocBuilder<SalesManagerDashboardCubit, SalesManagerDashboardState>(
      builder: (context, state) {
        if (state is SalesManagerDashboardLoading) return const ListSkeleton();
        if (state is SalesManagerDashboardDisabled) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            child: OpsHubEmptyState(
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Month, then which list ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pagePadding,
                AppSpacing.md,
                AppSpacing.pagePadding,
                0,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _moveMonth(-1),
                    tooltip: 'Previous month',
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      formatBusinessMonth(_monthKey),
                      textAlign: TextAlign.center,
                      style: AppTypography.label.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _isCurrentMonth ? null : () => _moveMonth(1),
                    tooltip: 'Next month',
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pagePadding,
                ),
                children: [
                  _Chip(
                    label: 'All',
                    count: snapshot.submissions.length,
                    selected: _filter == null,
                    onTap: () => setState(() => _filter = null),
                  ),
                  for (final status in SalesSubmissionStatus.values)
                    _Chip(
                      label: _filterLabel(status),
                      count: _countFor(snapshot, status),
                      selected: _filter == status,
                      onTap: () => setState(() => _filter = status),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: entries.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.pagePadding),
                      child: OpsHubEmptyState(
                        title: _emptyTitle(_filter),
                        message:
                            'Nothing here for ${formatBusinessMonth(_monthKey)}.',
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pagePadding,
                        0,
                        AppSpacing.pagePadding,
                        AppSpacing.xxl,
                      ),
                      itemCount: entries.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) => SalesSubmissionTile(
                        submission: entries[index],
                        onTap: () => context.push(
                          RouteNames.salesSubmissionDetail(entries[index].id),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    ),
  );
}

int _countFor(SalesMonthSnapshot snapshot, SalesSubmissionStatus status) =>
    switch (status) {
      SalesSubmissionStatus.pending => snapshot.pending.length,
      SalesSubmissionStatus.approved => snapshot.approved.length,
      SalesSubmissionStatus.rejected => snapshot.rejected.length,
      SalesSubmissionStatus.correctionRequested =>
        snapshot.correctionRequested.length,
    };

String _pageTitle(SalesSubmissionStatus? filter) => switch (filter) {
  null => 'Sales history',
  SalesSubmissionStatus.pending => 'Pending sales',
  SalesSubmissionStatus.approved => 'Approved sales',
  SalesSubmissionStatus.rejected => 'Rejected sales',
  SalesSubmissionStatus.correctionRequested => 'Corrections requested',
};

String _emptyTitle(SalesSubmissionStatus? filter) => switch (filter) {
  null => 'No sales submissions',
  SalesSubmissionStatus.pending => 'Nothing pending',
  SalesSubmissionStatus.approved => 'Nothing approved',
  SalesSubmissionStatus.rejected => 'Nothing rejected',
  SalesSubmissionStatus.correctionRequested => 'No corrections requested',
};

String _filterLabel(SalesSubmissionStatus status) => switch (status) {
  SalesSubmissionStatus.pending => 'Pending',
  SalesSubmissionStatus.approved => 'Approved',
  SalesSubmissionStatus.rejected => 'Rejected',
  SalesSubmissionStatus.correctionRequested => 'Corrections',
};

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
