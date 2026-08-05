import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/app_error_state.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/core/widgets/page_hero.dart';
import 'package:drop/core/widgets/skeleton.dart';
import 'package:drop/features/auth/presentation/widgets/app_button.dart';
import 'package:drop/features/sales/presentation/cubit/sales_submission_detail_cubit.dart';
import 'package:drop/features/sales/presentation/sales_format.dart';
import 'package:drop/features/sales/presentation/widgets/sales_reason_sheet.dart';
import 'package:drop/features/sales/presentation/widgets/sales_submission_tile.dart';
import 'package:drop/features/sales/presentation/widgets/sales_target_editor_sheet.dart';

class SalesSubmissionDetailScreen extends StatelessWidget {
  const SalesSubmissionDetailScreen({super.key, required this.submissionId});
  final String submissionId;
  @override
  Widget build(BuildContext context) => AdaptiveScaffold(
    title: 'Sales submission',
    body: BlocBuilder<SalesSubmissionDetailCubit, SalesSubmissionDetailState>(
      builder: (context, state) {
        if (state is SalesSubmissionDetailLoading) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Skeleton(height: 30),
                SizedBox(height: AppSpacing.xl),
                Skeleton(height: 210),
              ],
            ),
          );
        }
        if (state is SalesSubmissionDetailUnavailable) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.pagePadding),
            child: AppProblemPanel(
              title: 'Sales unavailable',
              message: 'This submission is no longer available.',
            ),
          );
        }
        if (state is SalesSubmissionDetailError) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            child: AppProblemPanel(
              title: 'Sales unavailable',
              message: state.message,
            ),
          );
        }
        final loaded = state as SalesSubmissionDetailLoaded;
        final sale = loaded.submission;
        final cubit = context.read<SalesSubmissionDetailCubit>();
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          children: [
            PageHero(
              eyebrow: 'Daily close',
              title: 'Sales submission',
              subtitle: sale.businessDateKey,
            ),
            const SizedBox(height: AppSpacing.xl),
            GlassContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(formatEgp(sale.amountPiastres, withSuffix: true)),
                  const SizedBox(height: AppSpacing.md),
                  Text('Business day · ${sale.businessDateKey}'),
                  Text('Submitted by · ${sale.submittedByName ?? 'Employee'}'),
                  Text(
                    'Submitted · ${sale.submittedAt == null ? '—' : AppDateFormatter.dayMonthYearTime(sale.submittedAt!)}',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  salesStatusBadge(sale.status),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (sale.isPending)
              AppButton(
                label: 'Approve',
                isLoading: loaded.busy,
                onPressed: loaded.busy ? null : cubit.approve,
              ),
            if (sale.isPending)
              TextButton(
                onPressed: loaded.busy
                    ? null
                    : () async {
                        final reason = await showSalesReasonSheet(
                          context,
                          title: 'Reject sales',
                          confirmLabel: 'Reject',
                        );
                        if (reason != null) cubit.reject(reason);
                      },
                child: const Text('Reject'),
              ),
            if (sale.isPending)
              TextButton(
                onPressed: loaded.busy
                    ? null
                    : () async {
                        final reason = await showSalesReasonSheet(
                          context,
                          title: 'Request correction',
                          confirmLabel: 'Request correction',
                        );
                        if (reason != null) cubit.requestCorrection(reason);
                      },
                child: const Text('Request correction'),
              ),
            if (sale.isApproved)
              TextButton(
                onPressed: loaded.busy
                    ? null
                    : () async {
                        final result = await showSalesTargetEditorSheet(
                          context,
                          title: 'Edit approved amount',
                          initialAmount: formatEgp(sale.amountPiastres),
                          confirmLabel: 'Save amount',
                        );
                        if (result != null) {
                          cubit.editApproved(
                            result.amountPiastres,
                            result.reason,
                            sale.revision,
                          );
                        }
                      },
                child: const Text('Edit amount'),
              ),
          ],
        );
      },
    ),
  );
}
