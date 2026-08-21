import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/glass_container.dart';

/// Small uppercase-ish section label used to group dashboard content
/// (Phase 10 — command-center hierarchy, like Linear / Stripe).
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Text(title.toUpperCase(),
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
              )),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// A prominent "needs attention" metric — larger than a [StatGrid] cell, with an
/// accent when its value is non-zero (e.g. waiting reviews, active tasks). Built
/// on the shared [GlassContainer] so it matches every other card.
class HeroStatCard extends StatelessWidget {
  const HeroStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;

  /// When true (e.g. count > 0), draws an accent border + tinted icon so it
  /// reads as "act on this".
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = highlight ? AppColors.warning : AppColors.textTertiary;
    return GlassContainer(
      onTap: onTap,
      highlight: highlight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color:
                      highlight ? accent.withAlpha(28) : AppColors.darkSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const Spacer(),
              if (onTap != null)
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.textTertiary),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(value,
              style: AppTypography.h1,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label,
              style: AppTypography.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
