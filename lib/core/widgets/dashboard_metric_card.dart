import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/animated_count.dart';
import 'package:opshub/core/widgets/glass_container.dart';

/// A small premium metric tile — an icon chip, a big value, a label and an
/// optional trend/status footnote. Used across the dashboards (admin overview,
/// branch health, etc.). Built on [GlassContainer] for consistent depth.
class DashboardMetricCard extends StatelessWidget {
  const DashboardMetricCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.trend,
    this.trendColor,
    this.onTap,
    this.accent,
  });

  final IconData icon;
  final String value;
  final String label;

  /// Optional small status/trend line under the label (e.g. "3 need review").
  final String? trend;
  final Color? trendColor;
  final VoidCallback? onTap;

  /// Tint for the icon chip (defaults to the white accent).
  final Color? accent;

  Widget _value() {
    final n = int.tryParse(value);
    return n != null
        ? AnimatedCount(value: n, style: AppTypography.h1, maxLines: 1)
        : Text(value, style: AppTypography.h1, maxLines: 1);
  }

  @override
  Widget build(BuildContext context) {
    final tint = accent ?? AppColors.primary;
    return GlassContainer(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: tint.withAlpha(28),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: tint),
              ),
              const Spacer(),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // A purely numeric value counts up smoothly on change; anything else
          // (e.g. the "—" loading placeholder) renders as plain text.
          _value(),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          // Always reserve the trend line's height, even when a card has no
          // trend to show — otherwise cards in the same grid row end up at
          // different heights (e.g. "Managers" sitting shorter than its
          // neighbours) and the grid reads as uneven.
          const SizedBox(height: 6),
          Visibility(
            visible: trend != null,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: Text(
              trend ?? ' ',
              style: AppTypography.caption.copyWith(
                color: trendColor ?? AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
