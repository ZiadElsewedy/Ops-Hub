import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/app_error_state.dart';
import 'package:drop/core/widgets/drop_logo.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/core/widgets/skeleton.dart';
import 'package:drop/features/sales/presentation/cubit/sales_month_state.dart';
import 'sales_money_row.dart';

/// The employee Home sales module: the **branch's** target · achieved ·
/// remaining, and a tap into the full page. Nothing else.
///
/// Labelled "branch" deliberately — the monthly target is a team number every
/// colleague's approved day feeds, not a personal quota.
///
/// No progress bar, no percentage, no pace figures, no status badge — a Home
/// module is one row in a dashboard, and every extra it carried was available
/// one tap away on `/sales/mine`. The DROP mark sits in the corner at low
/// opacity as a quiet owner of the surface, not as decoration.
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

  const SalesTargetCard({super.key, required this.state, required this.onOpen})
    : errorMessage = null,
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
            SizedBox(height: AppSpacing.lg),
            Skeleton(height: 40),
          ],
        ),
      );
    }

    final snapshot = loaded.snapshot;
    return Semantics(
      button: true,
      label: 'Branch monthly sales',
      child: GlassContainer(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'BRANCH MONTHLY SALES',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textTertiary,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Opacity(
                  opacity: 0.18,
                  child: DropLogo(height: 13, color: AppColors.textPrimary),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (!snapshot.hasTarget)
              Text(
                'No branch target set for this month yet.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              )
            else
              SalesMoneyRow(
                targetPiastres: snapshot.target!.targetPiastres,
                achievedPiastres: snapshot.approvedTotalPiastres,
                remainingPiastres: snapshot.remainingPiastres,
                compact: true,
              ),
          ],
        ),
      ),
    );
  }
}
