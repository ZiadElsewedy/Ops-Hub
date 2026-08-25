import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/skeleton.dart';

/// A single dashboard metric.
class StatItem {
  final String label;
  final String value;
  final IconData icon;
  const StatItem(this.label, this.value, this.icon);
}

/// Width-aware grid of operational metric cards (shared by all three
/// dashboards): 2 columns on mobile, 3–4 compact tiles on desktop so the metric
/// cards stay a premium size instead of two over-wide cards.
int statGridColumns(double maxWidth) =>
    (maxWidth / 280).round().clamp(2, 4);

class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.items});

  final List<StatItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const gap = AppSpacing.md;
        final cols = statGridColumns(c.maxWidth);
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(width: w, child: _StatCard(item: item)),
          ],
        );
      },
    );
  }
}

/// Shimmering placeholder shown while the dashboard stats load — mirrors the
/// [StatGrid] two-column layout so the screen doesn't jump when data arrives.
class StatGridSkeleton extends StatelessWidget {
  const StatGridSkeleton({super.key, this.count = 6});

  /// Roughly how many metric cards this dashboard shows (admin/manager ≈ 9,
  /// employee ≈ 4) — only affects how many placeholders render.
  final int count;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const gap = AppSpacing.md;
        final cols = statGridColumns(c.maxWidth);
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < count; i++)
              SizedBox(width: w, child: const _StatCardSkeleton()),
          ],
        );
      },
    );
  }
}

class _StatCardSkeleton extends StatelessWidget {
  const _StatCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(
              width: 20,
              height: 20,
              borderRadius: BorderRadius.all(Radius.circular(6))),
          SizedBox(height: AppSpacing.md),
          Skeleton(width: 44, height: 22),
          SizedBox(height: 6),
          Skeleton(width: 76, height: 11),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.item});
  final StatItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, size: 20, color: AppColors.textTertiary),
          const SizedBox(height: AppSpacing.md),
          Text(item.value,
              style: AppTypography.h2,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(item.label,
              style: AppTypography.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
