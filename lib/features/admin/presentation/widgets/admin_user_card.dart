import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/glass_container.dart';
import 'package:opshub/core/widgets/premium_button.dart';
import 'package:opshub/core/widgets/user_avatar.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';

/// Premium card for a user in the admin lists (managers / employees / pending).
/// Phase 9: leads with the user's **avatar** (reliable image + initials
/// fallback), then name · email, a status dot, and role/branch/status chips.
/// The screen supplies role/status-aware [actions].
class AdminUserCard extends StatelessWidget {
  const AdminUserCard({
    super.key,
    required this.user,
    this.branchLabel,
    this.actions = const [],
  });

  final UserEntity user;

  /// Human-readable branch label (resolved by the screen); falls back to the id.
  final String? branchLabel;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final name = (user.displayName != null && user.displayName!.isNotEmpty)
        ? user.displayName!
        : user.email;
    final hasBranch = user.branchId != null && user.branchId!.isNotEmpty;
    final statusColor = user.isActive ? AppColors.success : AppColors.error;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: GlassContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              UserAvatar.fromUser(user, size: 46),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: AppTypography.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (name != user.email) ...[
                      const SizedBox(height: 2),
                      Text(user.email,
                          style: AppTypography.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: statusColor, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _Chip(icon: Icons.badge_outlined, label: user.role.value),
              _Chip(
                icon: Icons.store_mall_directory_outlined,
                label: hasBranch
                    ? (branchLabel ?? user.branchId!)
                    : 'no branch',
              ),
              _Chip(
                icon: user.isActive
                    ? Icons.check_circle_outline_rounded
                    : Icons.block_rounded,
                label: user.isActive ? 'active' : 'inactive',
                color: statusColor,
              ),
              if (user.mustChangePassword)
                const _Chip(
                  icon: Icons.lock_clock_rounded,
                  label: 'pending first login',
                  color: AppColors.warning,
                ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: actions,
            ),
          ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, this.color});
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textTertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: c),
          const SizedBox(width: 4),
          Text(label,
              style: AppTypography.caption
                  .copyWith(color: color ?? AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// Compact pill button for admin card actions (mirrors the task card buttons).
class AdminActionButton extends StatelessWidget {
  const AdminActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return PremiumButton(
      label: label,
      icon: icon ?? Icons.chevron_right_rounded,
      onPressed: onPressed,
      tone: color,
    );
  }
}
