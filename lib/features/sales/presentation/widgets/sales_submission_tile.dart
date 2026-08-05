import 'package:flutter/material.dart';
import 'package:drop/core/enums/sales_submission_status.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/widgets/activity_card.dart';
import 'package:drop/core/widgets/status_badge.dart';
import 'package:drop/features/auth/presentation/widgets/app_button.dart';
import 'package:drop/features/sales/domain/entities/daily_sales_submission_entity.dart';
import 'package:drop/features/sales/presentation/sales_format.dart';

class SalesSubmissionTile extends StatelessWidget {
  const SalesSubmissionTile({
    super.key,
    required this.submission,
    this.onTap,
    this.onApprove,
    this.onReject,
    this.busy = false,
  });
  final DailySalesSubmissionEntity submission;
  final VoidCallback? onTap;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final bool busy;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      ActivityCard(
        title: formatEgp(submission.amountPiastres, withSuffix: true),
        subtitle:
            '${submission.submittedByName ?? 'Employee'} · ${submission.businessDateKey}',
        trailing: salesStatusBadge(submission.status),
        onTap: onTap,
      ),
      if (onApprove != null || onReject != null)
        Row(
          children: [
            if (onReject != null)
              Expanded(
                child: TextButton(
                  onPressed: busy ? null : onReject,
                  child: const Text('Reject'),
                ),
              ),
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
    ],
  );
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
