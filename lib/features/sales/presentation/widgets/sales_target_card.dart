import 'package:flutter/material.dart';
import 'package:drop/core/enums/sales_submission_status.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/app_error_state.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/core/widgets/skeleton.dart';
import 'package:drop/core/widgets/status_badge.dart';
import 'package:drop/features/sales/presentation/cubit/sales_month_state.dart';
import 'package:drop/features/sales/presentation/sales_format.dart';
import 'sales_progress_strip.dart';

/// The employee Home sales module: a compact row of the three figures that
/// matter, a progress bar, and a tap into the full sales page.
///
/// Deliberately **not** an empty state with a medallion. A Home module is one
/// row in a dashboard, not a page — the old "Target not set" branch rendered a
/// 180px box built around a large glyph, which is why this card dominated Home
/// while saying almost nothing. Every state here is one or two lines tall.
class SalesTargetCard extends StatelessWidget {
  const SalesTargetCard.loading({super.key})
    : state = null,
      errorMessage = null,
      onRetry = null,
      onOpen = null;

  const SalesTargetCard.error({
    super.key,
    required this.errorMessage,
    required this.onRetry,
  }) : state = null,
       onOpen = null;

  const SalesTargetCard({
    super.key,
    required this.state,
    required this.onOpen,
  }) : errorMessage = null,
       onRetry = null;

  final SalesMonthLoaded? state;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null) {
      return AppProblemPanel(
        title: 'Sales unavailable',
        message: errorMessage!,
        onRetry: onRetry,
      );
    }
    final loaded = state;
    if (loaded == null) {
      return const GlassContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Skeleton(height: 12, width: 110),
            SizedBox(height: AppSpacing.md),
            Skeleton(height: 44),
          ],
        ),
      );
    }

    final snapshot = loaded.snapshot;
    final today = loaded.todaySubmission;
    final semantics = snapshot.hasTarget
        ? 'Monthly sales, ${(snapshot.progressRatioRaw * 100).round()} percent of target'
        : 'Monthly sales, target not set';

    return Semantics(
      button: true,
      label: semantics,
      child: GlassContainer(
        onTap: onOpen,
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
                if (today != null) _TodayBadge(status: today.status),
                const SizedBox(width: AppSpacing.xs),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (!snapshot.hasTarget)
              Text(
                'No target for this month yet. Your manager sets it before daily '
                'sales can be submitted.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              )
            else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Figure(
                      label: 'Today',
                      value: today == null
                          ? 'Not submitted'
                          : formatEgp(today.amountPiastres, withSuffix: true),
                      muted: today == null,
                    ),
                  ),
                  Expanded(
                    child: _Figure(
                      label: 'Achieved',
                      value: formatEgp(
                        snapshot.approvedTotalPiastres,
                        withSuffix: true,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _Figure(
                      label: 'Remaining',
                      value: formatEgp(
                        snapshot.remainingPiastres,
                        withSuffix: true,
                      ),
                      muted: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SalesProgressStrip(
                ratioCapped: snapshot.progressRatioCapped,
                ratioRaw: snapshot.progressRatioRaw,
                remainingPiastres: snapshot.remainingPiastres,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Today's real state — the card used to say "submitted · pending" for a day
/// that had already been approved or rejected.
class _TodayBadge extends StatelessWidget {
  const _TodayBadge({required this.status});
  final SalesSubmissionStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      SalesSubmissionStatus.pending => ('Awaiting review', AppColors.warning),
      SalesSubmissionStatus.approved => ('Approved', AppColors.success),
      SalesSubmissionStatus.rejected => ('Rejected', AppColors.error),
      SalesSubmissionStatus.correctionRequested => (
        'Needs correction',
        AppColors.error,
      ),
    };
    return StatusBadge(label: label, color: color, compact: true);
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    this.muted = false,
  });
  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: AppTypography.label.copyWith(
          color: muted ? AppColors.textSecondary : AppColors.textPrimary,
        ),
      ),
    ],
  );
}
