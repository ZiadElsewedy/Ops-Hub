import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/app_glass_card.dart';
import 'package:opshub/core/widgets/metric_pill.dart';

/// Admin Home **Pending Actions** panel — a consolidated, actionable queue of
/// everything waiting on the admin: shift-swap requests, tasks waiting review,
/// and overdue tasks. Each non-empty queue is a tappable row that jumps straight
/// to where it's resolved. (Employee approvals were removed — OpsHub is
/// admin-provisioned, so there is no approval queue.)
///
/// Presentational only (counts + callbacks) so it renders in widget tests with no
/// cubits/router. **Always rendered** by the dashboard — when everything is clear
/// it collapses to a quiet confirmation row rather than competing with real
/// operational risks.
class PendingActions extends StatelessWidget {
  const PendingActions({
    super.key,
    required this.swaps,
    required this.reviews,
    required this.overdue,
    required this.onSwaps,
    required this.onReviews,
    required this.onOverdue,
  });

  final int swaps;
  final int reviews;
  final int overdue;
  final VoidCallback onSwaps;
  final VoidCallback onReviews;
  final VoidCallback onOverdue;

  /// Total items needing attention — also drives the section subtitle.
  int get total => swaps + reviews + overdue;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      if (swaps > 0)
        _ActionRow(
          icon: Icons.swap_horiz_rounded,
          label: swaps == 1 ? '1 Swap Request' : '$swaps Swap Requests',
          detail: 'Review shift swaps',
          accent: AppColors.warning,
          onTap: onSwaps,
        ),
      if (reviews > 0)
        _ActionRow(
          icon: Icons.rate_review_rounded,
          label: reviews == 1
              ? '1 Task Waiting Review'
              : '$reviews Tasks Waiting Review',
          detail: 'Approve or send back',
          accent: AppColors.warning,
          onTap: onReviews,
        ),
      if (overdue > 0)
        _ActionRow(
          icon: Icons.warning_amber_rounded,
          label: overdue == 1 ? '1 Late Task' : '$overdue Late Tasks',
          detail: 'Past the deadline',
          accent: AppColors.error,
          onTap: onOverdue,
        ),
    ];

    if (rows.isEmpty) {
      // Keep an explicit empty state, but make it deliberately compact: the
      // dashboard's attention hierarchy belongs to real operational gaps.
      return AppGlassCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha(28),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 17,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nothing queued', style: AppTypography.label),
                  const SizedBox(height: 2),
                  Text(
                    'No swaps, reviews or late tasks.',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Glanceable summary pills (non-zero only) above the actionable rows.
    final pills = <Widget>[
      if (reviews > 0)
        MetricPill(
          value: '$reviews',
          label: reviews == 1 ? 'review' : 'reviews',
          icon: Icons.rate_review_rounded,
          tone: AppColors.warning,
        ),
      if (swaps > 0)
        MetricPill(
          value: '$swaps',
          label: swaps == 1 ? 'swap' : 'swaps',
          icon: Icons.swap_horiz_rounded,
          tone: AppColors.warning,
        ),
      if (overdue > 0)
        MetricPill(
          value: '$overdue',
          label: 'late',
          icon: Icons.warning_amber_rounded,
          tone: AppColors.error,
        ),
    ];

    return AppGlassCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pills.length > 1) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: pills,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Divider(color: AppColors.darkBorder, height: 1),
          ],
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(color: AppColors.darkBorder, height: 1),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.detail,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withAlpha(28),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 20, color: accent),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTypography.label),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
