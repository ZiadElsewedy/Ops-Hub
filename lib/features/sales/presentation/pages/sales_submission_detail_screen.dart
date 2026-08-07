import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/app_error_state.dart';
import 'package:drop/core/widgets/app_snackbar.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/core/widgets/page_hero.dart';
import 'package:drop/core/widgets/skeleton.dart';
import 'package:drop/features/auth/presentation/widgets/app_button.dart';
import 'package:drop/features/sales/domain/entities/daily_sales_submission_entity.dart';
import 'package:drop/features/sales/presentation/cubit/sales_submission_detail_cubit.dart';
import 'package:drop/features/sales/presentation/sales_format.dart';
import 'package:drop/features/sales/presentation/widgets/sales_reason_sheet.dart';
import 'package:drop/features/sales/presentation/widgets/sales_target_editor_sheet.dart';
import 'package:drop/features/sales/presentation/widgets/sales_submission_tile.dart';

/// One daily close, with the actions the **viewer's role** actually allows.
///
/// The employee who submitted a day may open it (they get a notification when
/// it is decided), but every write here belongs to a manager or admin. The
/// screen previously offered "Edit amount" on any approved record to anyone who
/// could see it — the callable refused, so it read as a broken button.
class SalesSubmissionDetailScreen extends StatelessWidget {
  const SalesSubmissionDetailScreen({super.key, required this.submissionId});
  final String submissionId;

  @override
  Widget build(BuildContext context) => AdaptiveScaffold(
    title: 'Sales submission',
    body: BlocConsumer<SalesSubmissionDetailCubit, SalesSubmissionDetailState>(
      listenWhen: (previous, current) =>
          current is SalesSubmissionDetailLoaded && current.message != null,
      listener: (context, state) {
        final message = (state as SalesSubmissionDetailLoaded).message!;
        message.endsWith('.') &&
                (message.contains('approved') ||
                    message.contains('rejected') ||
                    message.contains('requested') ||
                    message.contains('updated') ||
                    message.contains('reopened'))
            ? AppSnackbar.success(context, message)
            : AppSnackbar.error(context, message);
      },
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

        // Only a manager or an admin decides a daily close. An employee opening
        // their own record sees the facts and nothing to press.
        final canDecide = context.isAdmin || context.isManager;
        final canReopen = context.isAdmin && sale.isTerminal;

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          children: [
            PageHero(
              eyebrow: 'Daily close',
              title: formatEgp(sale.amountPiastres, withSuffix: true),
              subtitle: formatBusinessDate(sale.businessDateKey),
            ),
            const SizedBox(height: AppSpacing.xl),
            GlassContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Status', style: AppTypography.labelLarge),
                      ),
                      salesStatusBadge(sale.status),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _Fact(
                    label: 'Business day',
                    value: formatBusinessDate(sale.businessDateKey),
                  ),
                  _Fact(
                    label: 'Submitted by',
                    value: sale.submittedByName ?? 'Employee',
                  ),
                  _Fact(
                    label: 'Submitted',
                    value: sale.submittedAt == null
                        ? '—'
                        : AppDateFormatter.dayMonthYearTime(sale.submittedAt!),
                  ),
                  if (sale.decisionByName != null)
                    _Fact(
                      label: 'Decided by',
                      value: sale.decisionAt == null
                          ? sale.decisionByName!
                          : '${sale.decisionByName} · '
                                '${AppDateFormatter.dayMonthYearTime(sale.decisionAt!)}',
                    ),
                  if (sale.lastEditedByName != null)
                    _Fact(
                      label: 'Last edited by',
                      value: sale.lastEditedByName!,
                    ),
                  if (sale.revision > 1)
                    _Fact(label: 'Revision', value: '${sale.revision}'),
                ],
              ),
            ),
            if (sale.decisionReason != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppProblemPanel(
                title: sale.needsCorrection
                    ? 'Correction requested'
                    : sale.isRejected
                    ? 'Rejection reason'
                    : 'Reason',
                message: sale.decisionReason!,
              ),
            ],
            if (canDecide) ...[
              const SizedBox(height: AppSpacing.xl),
              _Actions(
                sale: sale,
                busy: loaded.busy,
                canReopen: canReopen,
                cubit: cubit,
              ),
            ],
          ],
        );
      },
    ),
  );
}

/// One primary action per state; everything else is a secondary control.
class _Actions extends StatelessWidget {
  const _Actions({
    required this.sale,
    required this.busy,
    required this.canReopen,
    required this.cubit,
  });

  final DailySalesSubmissionEntity sale;
  final bool busy;
  final bool canReopen;
  final SalesSubmissionDetailCubit cubit;

  Future<void> _reason(
    BuildContext context, {
    required String title,
    required String confirmLabel,
    required void Function(String reason) onConfirm,
  }) async {
    final reason = await showSalesReasonSheet(
      context,
      title: title,
      confirmLabel: confirmLabel,
    );
    if (reason != null) onConfirm(reason);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (sale.isPending) ...[
        AppButton(
          label: 'Approve',
          isLoading: busy,
          onPressed: busy ? null : cubit.approve,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: busy
                    ? null
                    : () => _reason(
                        context,
                        title: 'Reject sales',
                        confirmLabel: 'Reject',
                        onConfirm: cubit.reject,
                      ),
                child: const Text('Reject'),
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed: busy
                    ? null
                    : () => _reason(
                        context,
                        title: 'Request correction',
                        confirmLabel: 'Request correction',
                        onConfirm: cubit.requestCorrection,
                      ),
                child: const Text('Request correction'),
              ),
            ),
          ],
        ),
      ] else if (sale.isApproved) ...[
        AppButton(
          label: 'Edit approved amount',
          isLoading: busy,
          onPressed: busy
              ? null
              : () async {
                  final result = await showSalesTargetEditorSheet(
                    context,
                    title: 'Edit approved amount',
                    subtitle:
                        'The branch total is re-summed from approved days, so '
                        'this changes the month immediately.',
                    initialAmount: formatEgp(sale.amountPiastres),
                    confirmLabel: 'Save amount',
                    reasonRequired: false,
                  );
                  if (result != null) {
                    cubit.editApproved(
                      result.amountPiastres,
                      result.reason,
                      sale.revision,
                    );
                  }
                },
        ),
      ] else if (sale.needsCorrection)
        Text(
          'Waiting for the employee to resubmit this day.',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      if (canReopen) ...[
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: busy
              ? null
              : () => _reason(
                  context,
                  title: 'Reopen sales submission',
                  confirmLabel: 'Reopen',
                  onConfirm: cubit.reopen,
                ),
          child: const Text('Reopen for review'),
        ),
      ],
    ],
  );
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    ),
  );
}
