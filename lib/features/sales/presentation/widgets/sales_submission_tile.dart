import 'package:flutter/material.dart';
import 'package:opshub/core/enums/sales_submission_status.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/widgets/activity_card.dart';
import 'package:opshub/core/widgets/status_badge.dart';
import 'package:opshub/features/auth/presentation/widgets/app_button.dart';
import 'package:opshub/features/sales/domain/entities/daily_sales_submission_entity.dart';
import 'package:opshub/features/sales/presentation/sales_format.dart';

/// One daily close in a list. The review actions are optional: a manager's
/// queue passes approve/reject, an employee's own history passes correct.
class SalesSubmissionTile extends StatelessWidget {
  const SalesSubmissionTile({
    super.key,
    required this.submission,
    this.onTap,
    this.onApprove,
    this.onReject,
    this.onCorrect,
    this.busy = false,
    this.showSubmitter = true,
  });
  final DailySalesSubmissionEntity submission;
  final VoidCallback? onTap;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onCorrect;
  final bool busy;

  /// Off in the employee's own list, where every row is theirs.
  final bool showSubmitter;

  @override
  Widget build(BuildContext context) {
    final day = formatBusinessDate(submission.businessDateKey);
    return Column(
      children: [
        ActivityCard(
          title: formatEgp(submission.amountPiastres, withSuffix: true),
          subtitle: showSubmitter
              ? '${submission.submittedByName ?? 'Employee'} · $day'
              : day,
          trailing: salesStatusBadge(submission.status),
          onTap: onTap,
        ),
        if (onApprove != null || onReject != null)
          Padding(
            // Separate the actions from the card above; without it the buttons
            // read as if they belong to the row and sit cramped against it.
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Row(
              children: [
                // Reject and Approve are the same button height (56) so they
                // align — an outline Reject balances the filled Approve rather
                // than a bare text link floating beside a solid pill.
                if (onReject != null)
                  Expanded(
                    child: AppButton.secondary(
                      label: 'Reject',
                      onPressed: busy ? null : onReject,
                    ),
                  ),
                if (onReject != null && onApprove != null)
                  const SizedBox(width: AppSpacing.sm),
                if (onApprove != null)
                  Expanded(
                    child: AppButton(
                      label: 'Approve',
                      isLoading: busy,
                      onPressed: busy ? null : onApprove!,
                    ),
                  ),
              ],
            ),
          ),
        if (onCorrect != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'Fix and resubmit',
                isLoading: busy,
                onPressed: busy ? null : onCorrect!,
              ),
            ),
          ),
      ],
    );
  }
}

StatusBadge salesStatusBadge(SalesSubmissionStatus status) {
  final (label, color) = switch (status) {
    SalesSubmissionStatus.pending => ('Pending', AppColors.warning),
    SalesSubmissionStatus.approved => ('Approved', AppColors.success),
    SalesSubmissionStatus.rejected => ('Rejected', AppColors.error),
    SalesSubmissionStatus.correctionRequested => (
      'Needs correction',
      AppColors.error,
    ),
  };
  return StatusBadge(label: label, color: color, compact: true);
}
