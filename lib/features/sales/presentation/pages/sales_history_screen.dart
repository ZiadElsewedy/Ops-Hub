import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/widgets/activity_card.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/app_error_state.dart';
import 'package:drop/core/widgets/drop_empty_state.dart';
import 'package:drop/core/widgets/list_skeleton.dart';
import 'package:drop/core/widgets/page_hero.dart';
import 'package:drop/core/widgets/stat_strip.dart';
import 'package:drop/features/sales/domain/sales_business_time.dart';
import 'package:drop/features/sales/presentation/cubit/sales_manager_dashboard_cubit.dart';
import 'package:drop/features/sales/presentation/sales_format.dart';
import 'package:drop/features/sales/presentation/widgets/sales_submission_tile.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});
  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  late String _monthKey;
  String? get _branchId => context.currentUser?.branchId;
  @override
  void initState() {
    super.initState();
    _monthKey = businessMonthKey(DateTime.now());
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final id = _branchId;
    if (id != null && id.isNotEmpty) {
      context.read<SalesManagerDashboardCubit>().loadForBranch(
        branchId: id,
        monthKey: _monthKey,
      );
    }
  }

  DateTime get _month => DateTime(
    int.parse(_monthKey.substring(0, 4)),
    int.parse(_monthKey.substring(4, 6)),
  );
  void _moveMonth(int delta) {
    final next = DateTime(_month.year, _month.month + delta);
    if (businessMonthKey(next).compareTo(businessMonthKey(DateTime.now())) > 0) {
      return;
    }
    setState(
      () => _monthKey =
          '${next.year.toString().padLeft(4, '0')}${next.month.toString().padLeft(2, '0')}',
    );
    _load();
  }

  @override
  Widget build(BuildContext context) => AdaptiveScaffold(
    title: 'Sales history',
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
        final snapshot = (state as SalesManagerDashboardLoaded).snapshot;
        final entries = [...snapshot.submissions]
          ..sort((a, b) => b.businessDateKey.compareTo(a.businessDateKey));
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          children: [
            PageHero(
              eyebrow: 'Branch ledger',
              title: 'Sales history',
              trailing: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _moveMonth(-1),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Text(AppDateFormatter.monthYear(_month)),
                    IconButton(
                      onPressed: _monthKey == businessMonthKey(DateTime.now())
                          ? null
                          : () => _moveMonth(1),
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
                  value: formatEgp(
                    snapshot.target?.targetPiastres ?? 0,
                    withSuffix: true,
                  ),
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
                  value: '${(snapshot.progressRatioRaw * 100).round()}%',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (entries.isEmpty)
              const DropEmptyState(
                title: 'No sales submissions',
                message: 'There are no daily sales submissions for this month.',
              ),
            for (final sale in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ActivityCard(
                  title: formatEgp(sale.amountPiastres, withSuffix: true),
                  subtitle:
                      '${sale.submittedByName ?? 'Employee'} · ${sale.businessDateKey}',
                  trailing: salesStatusBadge(sale.status),
                ),
              ),
          ],
        );
      },
    ),
  );
}
