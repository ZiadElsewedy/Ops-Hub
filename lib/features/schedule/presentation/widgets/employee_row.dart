import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/user_avatar.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/schedule/presentation/widgets/schedule_helpers.dart';

/// A compact, premium employee row — avatar · name · role, with a status dot and
/// an optional [trailing] action. Replaces the old developer-looking chips; the
/// single employee presentation across the shift sheet, the assign picker, and
/// the resolve flow.
///
/// The status dot reflects account health: green = active, amber = deactivated.
class EmployeeRow extends StatelessWidget {
  const EmployeeRow({
    super.key,
    required this.user,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.dense = false,
    this.surface = AppColors.darkSurface,
  });

  final UserEntity user;

  /// Overrides the default role label (e.g. "Also on Night" for a conflict).
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool dense;

  /// The colour the row sits on — used as the status-dot ring so it reads as a
  /// separate disc.
  final Color surface;

  @override
  Widget build(BuildContext context) {
    final size = dense ? 34.0 : 40.0;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: dense ? 6 : AppSpacing.sm),
        child: Row(
          children: [
            SizedBox(
              width: size,
              height: size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  UserAvatar.fromUser(user, size: size),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: _StatusDot(color: _statusColor(user), ring: surface),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userDisplayName(user),
                    style: AppTypography.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle ?? roleLabel(user.role),
                    style: AppTypography.caption.copyWith(
                      color: subtitle != null
                          ? AppColors.warning
                          : AppColors.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(UserEntity u) =>
      u.isActive ? AppColors.success : AppColors.warning;
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color, required this.ring});
  final Color color;
  final Color ring;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: 2),
      ),
    );
  }
}
