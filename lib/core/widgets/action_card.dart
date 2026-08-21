import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/glass_container.dart';

/// A premium quick-action tile — an icon in a rounded chip with a title and an
/// optional subtitle. Replaces boring [ListTile]s for the admin's primary
/// actions (Add Branch, Assign Task, …). Built on [GlassContainer] so it shares
/// the press feedback and depth of every other card.
class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.accent,
    this.secondary = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  /// Icon tint (defaults to the white accent).
  final Color? accent;

  /// Uses the quieter, horizontal treatment intended for navigation shortcuts.
  /// Primary quick actions stay vertical and elevated; repeated module links
  /// should set this so they do not compete for the same visual priority.
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final tint = accent ?? AppColors.primary;
    final iconChip = Container(
      width: secondary ? 32 : 38,
      height: secondary ? 32 : 38,
      decoration: BoxDecoration(
        color: tint.withAlpha(28),
        borderRadius: BorderRadius.circular(secondary ? 9 : 11),
      ),
      child: Icon(icon, size: secondary ? 17 : 19, color: tint),
    );
    final labels = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Action labels are never ellipsized. A narrow tile grows vertically
        // instead of making the admin guess what its CTA does.
        Text(title, style: AppTypography.label),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );

    return Semantics(
      button: true,
      label: subtitle == null ? title : '$title, $subtitle',
      child: GlassContainer(
        onTap: onTap,
        elevated: !secondary,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: secondary
            ? Row(
                children: [
                  iconChip,
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: labels),
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 17,
                    color: AppColors.textSecondary,
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  iconChip,
                  const SizedBox(height: AppSpacing.md),
                  labels,
                ],
              ),
      ),
    );
  }
}
