import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:opshub/core/routes/route_names.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/adaptive_scaffold.dart';
import 'package:opshub/core/widgets/app_glass_card.dart';
import 'package:opshub/core/widgets/brand_watermark.dart';
import 'package:opshub/core/widgets/user_avatar.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_state.dart';
import 'package:opshub/core/widgets/settings_tiles.dart';

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
                SettingsReveal(
                  index: 0,
                  child: _AccountHero(
                    user: user,
                    onTap: () => context.push(RouteNames.profile),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                const SettingsReveal(
                  index: 1,
                  child: SettingsSectionHeader(label: 'Preferences'),
                ),
                const SizedBox(height: AppSpacing.md),
                SettingsReveal(
                  index: 2,
                  child: SettingsGroup(
                    children: [
                      SettingsRow(
                        icon: Icons.notifications_none_rounded,
                        label: 'Notifications',
                        subtitle: 'Manage notification preferences',
                        isFirst: true,
                        isLast: true,
                        onTap: () =>
                            context.push(RouteNames.notificationSettings),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const SettingsReveal(
                  index: 3,
                  child: SettingsGroup(
                    children: [
                      SettingsRow(
                        icon: Icons.palette_outlined,
                        label: 'Appearance',
                        subtitle: 'Customize app appearance',
                        isFirst: true,
                        isLast: true,
                        // Deliberately inert for v1: the row states that the
                        // destination is coming rather than opening an empty
                        // screen or pretending to switch a theme DROP does not
                        // have yet (it is dark-only — ADR-004).
                        onTap: null,
                        trailing: SettingsComingSoonLabel(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                const SettingsReveal(
                  index: 4,
                  child: SettingsSectionHeader(label: 'Security'),
                ),
                const SizedBox(height: AppSpacing.md),
                SettingsReveal(
                  index: 5,
                  child: SettingsGroup(
                    children: [
                      SettingsRow(
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
                const SettingsReveal(
                  index: 6,
                  child: SettingsSectionHeader(label: 'Workspace'),
                ),
                const SizedBox(height: AppSpacing.md),
                SettingsReveal(
                  index: 7,
                  child: SettingsGroup(
                    children: [
                      SettingsRow(
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
                const SettingsReveal(
                  index: 8,
                  child: SettingsSectionHeader(label: 'OpsHub'),
                ),
                const SizedBox(height: AppSpacing.md),
                SettingsReveal(
                  index: 9,
                  child: SettingsGroup(
                    children: [
                      SettingsRow(
                        icon: Icons.info_outline_rounded,
                        label: 'About OpsHub',
                        subtitle: 'Product details and human support',
                        isFirst: true,
                        onTap: () => context.push(RouteNames.about),
                      ),
                      const _VersionRow(),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                SettingsReveal(
                  index: 10,
                  child: _SignOutCard(
                    onTap: () => context.read<AuthCubit>().signOut(),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: Text(
                    'OPSHUB · OPERATIONS',
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

class _VersionRow extends StatelessWidget {
  const _VersionRow();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SettingsRowDivider(),
      Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        child: Row(
          children: [
            const SettingsIconMedallion(icon: Icons.apps_rounded),
            const SizedBox(width: AppSpacing.md),
            const Expanded(
              child: SettingsRowLabel(
                label: 'App version',
                subtitle: 'Current installed build',
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
