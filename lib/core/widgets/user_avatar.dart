import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';

/// A reliable circular user avatar.
///
/// Renders the user's [imageUrl] when present and loadable; otherwise falls back
/// to an **initials** chip. Missing/empty URLs, network failures and decode
/// errors all resolve to the initials fallback — never a broken-image icon, a
/// spinner storm, or a crash. This is the single source of avatar rendering
/// across the app (task cards, admin lists, schedule chips), and the fix for the
/// Phase 9 "assignee image sometimes fails to appear" bug:
///
/// * `users/{uid}.photoUrl` is kept in sync with the profile `profileImage`
///   (see `ProfileModel.editMap`), so the URL is read consistently everywhere.
/// * decode size is capped (`cacheWidth`) so a large remote bitmap can't jank.
/// * `gaplessPlayback` avoids a flash between the placeholder and the image.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.email,
    this.size = 36,
    this.ringColor,
  });

  /// Build directly from a [UserEntity] (the common case).
  factory UserAvatar.fromUser(
    UserEntity user, {
    double size = 36,
    Color? ringColor,
  }) =>
      UserAvatar(
        imageUrl: user.photoUrl,
        name: user.displayName,
        email: user.email,
        size: size,
        ringColor: ringColor,
      );

  final String? imageUrl;
  final String? name;
  final String? email;
  final double size;

  /// Border ring — set to the surface color when stacking avatars so they read
  /// as separate discs.
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    final initials = avatarInitials(name, email);
    final url = imageUrl?.trim() ?? '';
    final dpr = MediaQuery.of(context).devicePixelRatio;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.darkSurfaceElevated,
        border: Border.all(color: ringColor ?? AppColors.darkBorder, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? _Initials(initials, size: size)
          : Image.network(
              url,
              fit: BoxFit.cover,
              width: size,
              height: size,
              cacheWidth: (size * dpr).round(),
              gaplessPlayback: true,
              // Show the initials while bytes load, then swap to the image — no
              // spinner, no layout jump.
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : _Initials(initials, size: size),
              // Any failure (404, rules, offline, bad bytes) → initials.
              errorBuilder: (_, _, _) => _Initials(initials, size: size),
            ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials(this.text, {required this.size});
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          text,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textSecondary,
            fontSize: size * 0.38,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      );
}

/// 1–2 uppercase letters derived from a display name (preferred) or email.
/// Never empty — falls back to `?` so the chip always renders.
String avatarInitials(String? name, String? email) {
  final n = (name ?? '').trim();
  if (n.isNotEmpty) {
    final parts = n.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    final one = parts.first;
    return (one.length >= 2 ? one.substring(0, 2) : one).toUpperCase();
  }
  final e = (email ?? '').trim();
  if (e.isNotEmpty) {
    final local = e.split('@').first;
    if (local.isNotEmpty) {
      return (local.length >= 2 ? local.substring(0, 2) : local).toUpperCase();
    }
  }
  return '?';
}

/// A row of overlapping [UserAvatar]s with a "+N" overflow disc — the task-card
/// assignee preview. Shows up to [max] avatars; any remainder collapses into a
/// trailing count. Renders nothing when [users] is empty (the card shows an
/// "Unassigned" affordance instead). Wrap-tap is handled by the caller.
class AvatarStack extends StatelessWidget {
  const AvatarStack({
    super.key,
    required this.users,
    this.max = 3,
    this.size = 30,
  });

  final List<UserEntity> users;
  final int max;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) return const SizedBox.shrink();
    final shown = users.length > max ? users.take(max).toList() : users;
    final overflow = users.length - shown.length;

    // Each disc is offset by [step]; ~38% of each avatar overlaps the previous.
    final step = size * 0.62;
    final discCount = shown.length + (overflow > 0 ? 1 : 0);
    final totalWidth = size + (discCount - 1) * step;

    final children = <Widget>[];
    for (var i = 0; i < shown.length; i++) {
      children.add(Positioned(
        left: i * step,
        child: UserAvatar.fromUser(shown[i],
            size: size, ringColor: AppColors.darkSurface),
      ));
    }
    if (overflow > 0) {
      children.add(Positioned(
        left: shown.length * step,
        child: _OverflowDisc(count: overflow, size: size),
      ));
    }

    return SizedBox(
      width: totalWidth,
      height: size,
      child: Stack(clipBehavior: Clip.none, children: children),
    );
  }
}

class _OverflowDisc extends StatelessWidget {
  const _OverflowDisc({required this.count, required this.size});
  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.darkSurfaceElevated,
        border: Border.all(color: AppColors.darkSurface, width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        '+$count',
        style: AppTypography.labelSmall.copyWith(
          color: AppColors.textSecondary,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }
}
