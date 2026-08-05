import 'package:flutter/material.dart';
import 'package:drop/core/enums/sales_submission_status.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/app_error_state.dart';
import 'package:drop/core/widgets/drop_empty_state.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/core/widgets/primary_cta.dart';
import 'package:drop/core/widgets/skeleton.dart';
import 'package:drop/core/widgets/stat_strip.dart';
import 'package:drop/core/widgets/status_badge.dart';
import 'package:drop/features/sales/domain/entities/daily_sales_submission_entity.dart';
import 'package:drop/features/sales/domain/entities/sales_month_snapshot.dart';
import 'package:drop/features/sales/presentation/sales_format.dart';
import 'sales_progress_strip.dart';

class SalesTargetCard extends StatelessWidget {
  const SalesTargetCard.loading({super.key})
    : snapshot = null,
      ownSubmissions = const [],
      errorMessage = null,
      onRetry = null,
      onSubmit = null;
  const SalesTargetCard.error({
    super.key,
    required this.errorMessage,
    required this.onRetry,
  }) : snapshot = null,
       ownSubmissions = const [],
       onSubmit = null;
  const SalesTargetCard({
    super.key,
    required this.snapshot,
    required this.ownSubmissions,
    required this.onSubmit,
  }) : errorMessage = null,
       onRetry = null;
  final SalesMonthSnapshot? snapshot;
  final List<DailySalesSubmissionEntity> ownSubmissions;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onSubmit;
  @override
  Widget build(BuildContext context) {
    if (errorMessage != null) {
      return AppProblemPanel(
        title: 'Sales unavailable',
        message: errorMessage!,
        onRetry: onRetry,
      );
    }
    if (snapshot == null) {
      return const GlassContainer(
        child: Column(
          children: [
            Skeleton(height: 14, width: 120),
            SizedBox(height: AppSpacing.lg),
            Skeleton(height: 78),
          ],
        ),
      );
    }
    if (!snapshot!.hasTarget) {
      return const SizedBox(
        height: 180,
        child: DropEmptyState(
          title: 'Target not set',
          message:
              'Your manager needs to set this month’s sales target before you can submit.',
        ),
      );
    }
    final pending = ownSubmissions
        .where((s) => s.status == SalesSubmissionStatus.pending)
        .firstOrNull;
    final rejected = ownSubmissions
        .where(
          (s) =>
              s.status == SalesSubmissionStatus.rejected ||
              s.status == SalesSubmissionStatus.correctionRequested,
        )
        .firstOrNull;
    final todayKey = DateTime.now();
    final dateKey =
        '${todayKey.year.toString().padLeft(4, '0')}${todayKey.month.toString().padLeft(2, '0')}${todayKey.day.toString().padLeft(2, '0')}';
    final todaySubmitted = ownSubmissions.any(
      (s) => s.businessDateKey == dateKey,
    );
    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'MONTHLY SALES',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                    letterSpacing: 1,
                  ),
                ),
              ),
              if (rejected != null)
                const StatusBadge(
                  label: 'Needs correction',
                  color: AppColors.error,
                  compact: true,
                )
              else if (pending != null)
                const StatusBadge(
                  label: 'Awaiting review',
                  color: AppColors.warning,
                  compact: true,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          StatStrip(
            stats: [
              Stat(
                label: 'Target',
                value: formatEgp(
                  snapshot!.target!.targetPiastres,
                  withSuffix: true,
                ),
                tone: AppColors.textSecondary,
              ),
              Stat(
                label: 'Achieved',
                value: formatEgp(
                  snapshot!.approvedTotalPiastres,
                  withSuffix: true,
                ),
              ),
              Stat(
                label: 'Remaining',
                value: formatEgp(snapshot!.remainingPiastres, withSuffix: true),
                tone: AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SalesProgressStrip(
            ratioCapped: snapshot!.progressRatioCapped,
            ratioRaw: snapshot!.progressRatioRaw,
            remainingPiastres: snapshot!.remainingPiastres,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (todaySubmitted)
            Text(
              'Today’s sales submitted · pending',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else
            PrimaryCta(
              icon: Icons.add_chart_rounded,
              label: 'Submit today’s sales',
              onTap: onSubmit!,
            ),
        ],
      ),
    );
  }
}
