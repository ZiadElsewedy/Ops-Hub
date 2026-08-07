import 'package:flutter/material.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/app_glass_card.dart';
import 'package:drop/core/widgets/brand_watermark.dart';
import 'package:drop/core/widgets/premium_button.dart';
import 'package:drop/features/profile/domain/entities/profile_entity.dart';
import 'package:drop/features/profile/presentation/widgets/profile_avatar.dart';

/// The identity lockup that opens the Profile screen — cover, avatar, name,
/// who the person is in the org, their bio, and the screen's **one** primary
/// action.
///
/// The cover image was already uploadable from Edit Profile but had nowhere to
/// be seen; it renders here under a scrim so the avatar and name stay legible
/// over any photo. With no cover the band falls back to the shared neutral wash
/// plus the quiet DROP mark — a finished surface, not a hole where an image
/// failed to load.
///
/// An incomplete profile is a **status**, so the card carries the semantic
/// warning edge and its CTA reads *Complete profile* instead of *Edit profile*
/// (same destination — one CTA, two truths).
class ProfileIdentityCard extends StatelessWidget {
  const ProfileIdentityCard({
    super.key,
    required this.profile,
    required this.role,
    required this.position,
    required this.onEdit,
  });

  final ProfileEntity profile;

  /// The signed-in user's access role, from the auth session (the profile
  /// document deliberately does not carry privileged fields).
  final UserRole? role;

  /// Job title within the branch, from the auth session. Null / empty when the
  /// admin has not set one.
  final String? position;

  final VoidCallback onEdit;

  static const double _coverHeight = 72;
  static const double _avatarSize = 62;
  static const double _avatarOverlap = _avatarSize / 2;

  @override
  Widget build(BuildContext context) {
    final incomplete = !profile.isComplete;
    final bio = profile.bio?.trim() ?? '';
    // Position rides the identity line rather than taking a second chip: at
    // 390pt the chip row shares its line with the CTA, and "Shift Supervisor"
    // beside a role chip wrapped to two lines there.
    final secondary = [
      profile.handle.isNotEmpty ? profile.handle : profile.email,
      ?_position,
    ].join(' · ');

    return Semantics(
      container: true,
      label: 'Profile of ${profile.displayName}',
      child: AppGlassCard(
        padding: EdgeInsets.zero,
        highlight: incomplete,
        accent: AppColors.warning,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _CoverBand(imageUrl: profile.coverImage),
                Positioned(
                  left: AppSpacing.lg,
                  bottom: -_avatarOverlap,
                  child: ProfileAvatar(
                    initials: profile.initials,
                    imageUrl: profile.profileImage,
                    size: _avatarSize,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                _avatarOverlap + AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayName,
                    style: AppTypography.h3,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (secondary.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      secondary,
                      style: AppTypography.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (bio.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      bio,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  // The chips and the screen's one CTA share a line — the
                  // divider + helper paragraph the card used to close with cost
                  // ~60pt of height and said nothing the button doesn't.
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          children: _pills,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      PremiumButton(
                        label: incomplete ? 'Complete profile' : 'Edit profile',
                        icon: Icons.edit_outlined,
                        style: PremiumButtonStyle.filled,
                        onPressed: onEdit,
                      ),
                    ],
                  ),
                  // Only an incomplete profile earns an extra line: it has to
                  // say *what* is missing, which the CTA label cannot.
                  if (incomplete) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Add your name and username to finish setting up.',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.warning,
                      ),
                      maxLines: 2,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The job title, or null when the admin has not set one.
  String? get _position {
    final p = (position ?? '').trim();
    return p.isEmpty ? null : p;
  }

  List<Widget> get _pills => [
    if (role != null) ProfileMetaPill(label: _roleLabel(role!), strong: true),
  ];

  static String _roleLabel(UserRole role) =>
      '${role.name[0].toUpperCase()}${role.name.substring(1)}';
}

/// The cover strip. A photo is always scrimmed towards the card surface so the
/// avatar's ring and the name below never fight a bright image; with no photo
/// the band is the shared neutral wash carrying the quiet DROP mark.
class _CoverBand extends StatelessWidget {
  const _CoverBand({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.card),
      ),
      child: SizedBox(
        height: ProfileIdentityCard._coverHeight,
        width: double.infinity,
        child: url.isEmpty
            ? const BrandWatermark(
                assetLogo: true,
                assetHeight: 104,
                opacity: 0.05,
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: AppColors.subtleGradient),
                  child: SizedBox.expand(),
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    url,
                    fit: BoxFit.cover,
                    // Caps the decoded bitmap for a short strip — a full-res
                    // cover would otherwise decode at native size.
                    cacheWidth: 1280,
                    errorBuilder: (_, _, _) => const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppColors.subtleGradient,
                      ),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), Color(0xB3000000)],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// A small monochrome fact chip (role, position). Never a status — it takes no
/// semantic colour (ADR-004).
class ProfileMetaPill extends StatelessWidget {
  const ProfileMetaPill({super.key, required this.label, this.strong = false});

  final String label;

  /// The primary fact of the row (the access role) sits a step brighter than
  /// the ones beside it, so no two adjacent chips share a grey.
  final bool strong;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.primarySurface,
      borderRadius: AppRadius.fullAll,
      border: Border.all(color: AppColors.darkBorder),
    ),
    child: Text(
      label.toUpperCase(),
      style: AppTypography.caption.copyWith(
        color: strong ? AppColors.textPrimary : AppColors.textSecondary,
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.9,
      ),
    ),
  );
}
