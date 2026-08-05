import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/app_glass_card.dart';
import 'package:drop/core/widgets/app_motion.dart';
import 'package:drop/core/widgets/brand_watermark.dart';
import 'package:drop/core/widgets/user_avatar.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:drop/features/auth/presentation/cubit/auth_state.dart';

/// The signed-in user's account hub.
///
/// Identity leads, operational shortcuts sit in clear groups, and destructive
/// sign-out is deliberately separated from ordinary navigation. All surfaces
/// reuse the shared glass/motion system so Settings feels like part of DROP,
/// not a platform preferences form.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: 'Settings',
      contentMaxWidth: 680,
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          final user = state.maybeWhen(
            authenticated: (u) => u,
            orElse: () => null,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pagePadding,
              AppSpacing.lg,
              AppSpacing.pagePadding,
              AppSpacing.xxxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Reveal(
                  index: 0,
                  child: _AccountHero(
                    user: user,
                    onTap: () => context.push(RouteNames.profile),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                _Reveal(
                  index: 1,
                  child: const _SectionHeader(label: 'Security'),
                ),
                const SizedBox(height: AppSpacing.md),
                _Reveal(
                  index: 2,
                  child: _SettingsGroup(
                    children: [
                      _SettingsRow(
                        icon: Icons.lock_outline_rounded,
                        label: 'Change password',
                        subtitle: 'Keep your account access secure',
                        isFirst: true,
                        isLast: true,
                        onTap: () => context.push(RouteNames.changePassword),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                _Reveal(
                  index: 3,
                  child: const _SectionHeader(label: 'Workspace'),
                ),
                const SizedBox(height: AppSpacing.md),
                _Reveal(
                  index: 4,
                  child: _SettingsGroup(
                    children: [
                      _SettingsRow(
                        icon: Icons.forum_outlined,
                        label: 'Cases',
                        subtitle: 'Private support conversations',
                        isFirst: true,
                        isLast: true,
                        onTap: () => context.push(RouteNames.cases),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                _Reveal(
                  index: 5,
                  child: const _SectionHeader(label: 'Drop Operation'),
                ),
                const SizedBox(height: AppSpacing.md),
                _Reveal(
                  index: 6,
                  child: _SettingsGroup(
                    children: [
                      _SettingsRow(
                        icon: Icons.info_outline_rounded,
                        label: 'About Drop Operation',
                        subtitle: 'Product details and human support',
                        isFirst: true,
                        onTap: () => context.push(RouteNames.about),
                      ),
                      const _VersionRow(),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                _Reveal(
                  index: 7,
                  child: _SignOutCard(
                    onTap: () => context.read<AuthCubit>().signOut(),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: Text(
                    'DROP THE SHOP · OPERATIONS',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textQuaternary,
                      letterSpacing: 1.4,
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AccountHero extends StatelessWidget {
  const _AccountHero({required this.user, required this.onTap});

  final UserEntity? user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = (user?.displayName ?? '').trim();
    final email = (user?.email ?? '').trim();
    final title = name.isNotEmpty
        ? name
        : email.isNotEmpty
        ? email.split('@').first
        : 'Your account';
    final role = user == null
        ? 'Account'
        : '${user!.role.name[0].toUpperCase()}${user!.role.name.substring(1)}';

    return Semantics(
      button: true,
      label: 'Open profile for $title',
      child: AppGlassCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: BrandWatermark(
          assetLogo: true,
          assetHeight: 76,
          opacity: 0.025,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR ACCOUNT',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  if (user != null)
                    UserAvatar.fromUser(user!, size: 58)
                  else
                    const UserAvatar(size: 58),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.h3,
                        ),
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        _RolePill(label: role),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(height: 1, color: AppColors.darkBorder),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Text(
                    'View and edit profile',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 17,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.primarySurface,
      borderRadius: AppRadius.fullAll,
      border: Border.all(color: AppColors.darkBorder),
    ),
    child: Text(
      label.toUpperCase(),
      style: AppTypography.caption.copyWith(
        color: AppColors.textSecondary,
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.9,
      ),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(
      label.toUpperCase(),
      style: AppTypography.caption.copyWith(
        color: AppColors.textTertiary,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
      ),
    ),
  );
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => AppGlassCard(
    padding: EdgeInsets.zero,
    child: Column(children: children),
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.isFirst = false,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!isFirst)
          const Divider(height: 1, color: AppColors.darkBorder, indent: 68),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: _rowRadius(isFirst: isFirst, isLast: isLast),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.lg,
              ),
              child: Row(
                children: [
                  _IconMedallion(icon: icon),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: AppTypography.labelLarge),
                        if ((subtitle ?? '').isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textQuaternary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _IconMedallion extends StatelessWidget {
  const _IconMedallion({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.primarySurface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.darkBorder),
    ),
    child: Icon(icon, size: 19, color: AppColors.textSecondary),
  );
}

class _VersionRow extends StatelessWidget {
  const _VersionRow();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Divider(height: 1, color: AppColors.darkBorder, indent: 68),
      Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        child: Row(
          children: [
            const _IconMedallion(icon: Icons.apps_rounded),
            const SizedBox(width: AppSpacing.md),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('App version', style: AppTypography.labelLarge),
                  SizedBox(height: 3),
                  Text(
                    'Current installed build',
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
            ),
            Text(
              '1.0.0 (1)',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _SignOutCard extends StatelessWidget {
  const _SignOutCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Sign out of this device',
    child: AppGlassCard(
      onTap: onTap,
      elevated: false,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.error.withAlpha(18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withAlpha(54)),
            ),
            child: const Icon(
              Icons.logout_rounded,
              size: 19,
              color: AppColors.error,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sign out',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'End this session on this device',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: AppColors.error.withAlpha(180),
          ),
        ],
      ),
    ),
  );
}

/// Respects the system's reduced-motion preference without changing the shared
/// animation primitive for every other feature.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
    return EntranceFade(delay: staggerDelay(index), child: child);
  }
}

BorderRadius _rowRadius({required bool isFirst, required bool isLast}) {
  if (isFirst && isLast) return AppRadius.cardAll;
  if (isFirst) {
    return const BorderRadius.vertical(top: Radius.circular(AppRadius.card));
  }
  if (isLast) {
    return const BorderRadius.vertical(bottom: Radius.circular(AppRadius.card));
  }
  return BorderRadius.zero;
}
