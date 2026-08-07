import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/app_error_state.dart';
import 'package:drop/core/widgets/app_glass_card.dart';
import 'package:drop/core/widgets/branch_avatar.dart';
import 'package:drop/core/widgets/settings_tiles.dart';
import 'package:drop/core/widgets/skeleton.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:drop/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:drop/features/branch/presentation/cubit/branch_state.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/features/profile/domain/entities/profile_entity.dart';
import 'package:drop/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:drop/features/profile/presentation/cubit/profile_state.dart';
import 'package:drop/features/profile/presentation/widgets/profile_detail_row.dart';
import 'package:drop/features/profile/presentation/widgets/profile_identity_card.dart';

/// The signed-in user's own profile — who they are, where they work, how the
/// company reaches them, and how their account is set up.
///
/// It reads as the sibling of Settings on purpose: the same grouped glass rows
/// (`core/widgets/settings_tiles.dart`), the same entrance stagger, the same
/// isolated destructive sign-out. What is specific to a profile is the identity
/// lockup (cover + avatar + role) and the fact rows, which lead with the value
/// rather than a destination name and offer tap-to-copy.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final uid = context.currentUser?.uid;
    if (uid != null) context.read<ProfileCubit>().loadProfile(uid);
    // Branch directory for the assigned-branch row (§8b).
    context.read<BranchCubit>().loadIfNeeded();
  }

  /// Pull-to-refresh / retry. Bypasses the cubit's revisit guard — this is the
  /// one path where the user is explicitly asking for a re-read.
  Future<void> _refresh() async {
    final uid = context.currentUser?.uid;
    if (uid == null) return;
    await context.read<ProfileCubit>().loadProfile(uid, forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: 'Profile',
      contentMaxWidth: 680,
      body: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, state) {
          return state.maybeWhen(
            loading: () => const _ProfileSkeleton(),
            error: (msg) => AppErrorState(
              title: 'Profile unavailable',
              message: msg,
              icon: Icons.cloud_off_rounded,
              onRetry: _refresh,
            ),
            orElse: () {
              final profile = state.maybeWhen(
                loaded: (p) => p,
                saving: (p, _) => p,
                saved: (p) => p,
                orElse: () => null,
              );
              if (profile == null) return const _ProfileSkeleton();
              return RefreshIndicator(
                onRefresh: _refresh,
                color: AppColors.primary,
                backgroundColor: AppColors.darkSurfaceElevated,
                child: _ProfileContent(profile: profile),
              );
            },
          );
        },
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.profile});

  final ProfileEntity profile;

  @override
  Widget build(BuildContext context) {
    final user = context.currentUser;
    void edit() => context.push(RouteNames.editProfile);

    // The self-service contact block is for managers and employees only (owner
    // ruling, mirrored in EditProfilePage, which does not render those fields
    // for an admin) — so an admin's empty row must not offer a door onto a form
    // that has no such field.
    final VoidCallback? addContact = context.isAdmin ? null : edit;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
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
            child: ProfileIdentityCard(
              profile: profile,
              role: user?.role,
              position: user?.position,
              onEdit: edit,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // ─── Workplace ──────────────────────────────────────────────
          const SettingsReveal(
            index: 1,
            child: SettingsSectionHeader(label: 'Workplace'),
          ),
          const SizedBox(height: AppSpacing.md),
          SettingsReveal(index: 2, child: _WorkplaceGroup(user: user)),
          const SizedBox(height: AppSpacing.xxl),

          // ─── Contact ────────────────────────────────────────────────
          const SettingsReveal(
            index: 3,
            child: SettingsSectionHeader(label: 'Contact'),
          ),
          const SizedBox(height: AppSpacing.md),
          SettingsReveal(
            index: 4,
            child: SettingsGroup(
              children: [
                ProfileDetailRow(
                  icon: Icons.alternate_email_rounded,
                  label: 'Email',
                  value: profile.email,
                  copyable: true,
                  isFirst: true,
                ),
                ProfileDetailRow(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: profile.phoneNumber,
                  copyable: true,
                  onAdd: addContact,
                ),
                ProfileDetailRow(
                  icon: Icons.home_outlined,
                  label: 'Address',
                  value: profile.address,
                  onAdd: addContact,
                ),
                ProfileDetailRow(
                  icon: Icons.emergency_outlined,
                  label: 'Emergency contact',
                  value: profile.emergencyContact,
                  copyable: true,
                  onAdd: addContact,
                  isLast: true,
                ),
              ],
            ),
          ),

          // ─── Account ────────────────────────────────────────────────
          const SizedBox(height: AppSpacing.xxl),
          const SettingsReveal(
            index: 5,
            child: SettingsSectionHeader(label: 'Account'),
          ),
          const SizedBox(height: AppSpacing.md),
          SettingsReveal(index: 6, child: _AccountGroup(profile: profile)),

          // ─── Actions ────────────────────────────────────────────────
          const SizedBox(height: AppSpacing.xxl),
          SettingsReveal(
            index: 7,
            child: SettingsGroup(
              children: [
                SettingsRow(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  subtitle: 'Preferences, security and workspace',
                  isFirst: true,
                  isLast: true,
                  onTap: () => context.push(RouteNames.settings),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SettingsReveal(
            index: 8,
            child: _SignOutCard(
              onTap: () => context.read<AuthCubit>().signOut(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Where this person works. The branch row carries the branch's own logo rather
/// than a generic glyph — identity is resolved through the app-wide
/// [BranchCubit], so it costs no extra read.
///
/// **An admin has no `branchId`** (the role is global), so instead of rendering
/// an empty branch row the group states the truth: access is org-wide.
class _WorkplaceGroup extends StatelessWidget {
  const _WorkplaceGroup({required this.user});

  final UserEntity? user;

  @override
  Widget build(BuildContext context) {
    final branchId = user?.branchId ?? '';
    final isGlobal = user?.role.isGlobal ?? false;
    final shift = (user?.assignedShift ?? '').trim();
    // Position is deliberately NOT a row here — it is already a chip on the
    // identity card, and one screen must not state the same fact twice.

    if (branchId.isEmpty) {
      return SettingsGroup(
        children: [
          ProfileDetailRow(
            icon: Icons.storefront_outlined,
            label: 'Branch',
            value: isGlobal ? 'All branches · organisation-wide' : null,
            isFirst: true,
            isLast: true,
          ),
        ],
      );
    }

    return BlocBuilder<BranchCubit, BranchState>(
      builder: (context, _) {
        final branch = context.read<BranchCubit>().branchById(branchId);
        final name = branch?.name ?? 'Your branch';
        final location = (branch?.location ?? '').trim();
        return SettingsGroup(
          children: [
            ProfileDetailRow(
              icon: Icons.storefront_outlined,
              label: 'Assigned branch',
              value: location.isEmpty ? name : '$name · $location',
              leading: BranchAvatar(
                logoUrl: branch?.logoUrl,
                name: name,
                size: 40,
                radius: 12,
              ),
              isFirst: true,
              isLast: shift.isEmpty,
            ),
            if (shift.isNotEmpty)
              ProfileDetailRow(
                icon: Icons.schedule_rounded,
                label: 'Assigned shift',
                value: shift,
                isLast: true,
              ),
          ],
        );
      },
    );
  }
}

/// How the account itself is set up — the facts a person checks when something
/// looks wrong, not settings they can change here.
class _AccountGroup extends StatelessWidget {
  const _AccountGroup({required this.profile});

  final ProfileEntity profile;

  @override
  Widget build(BuildContext context) {
    final updated = profile.updatedAt;
    return SettingsGroup(
      children: [
        ProfileDetailRow(
          icon: Icons.key_outlined,
          label: 'Sign-in method',
          value: _providerLabel(profile.authProvider),
          isFirst: true,
        ),
        ProfileDetailRow(
          icon: Icons.event_available_outlined,
          label: 'Member since',
          value: profile.createdAt == null
              ? null
              : AppDateFormatter.monthDayYear(profile.createdAt!),
          isLast: updated == null,
        ),
        if (updated != null)
          ProfileDetailRow(
            icon: Icons.history_rounded,
            label: 'Last updated',
            value: AppDateFormatter.monthDayYear(updated),
            isLast: true,
          ),
      ],
    );
  }

  static String _providerLabel(String provider) => switch (provider) {
    'email' || 'password' => 'Email and password',
    'phone' => 'Phone',
    'google.com' || 'google' => 'Google',
    'unknown' || '' => 'Not recorded',
    _ => provider,
  };
}

/// Sign-out is deliberately its own surface, away from ordinary navigation —
/// the same shape Settings uses, so the destructive action looks identical
/// wherever the user meets it.
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

// ─── Loading ───────────────────────────────────────────────────────────────

/// Keeps the shape of what is arriving: the identity card, then two groups.
class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.lg,
        AppSpacing.pagePadding,
        AppSpacing.xxxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(height: 268),
          SizedBox(height: AppSpacing.xxl),
          Skeleton(width: 90, height: 12),
          SizedBox(height: AppSpacing.md),
          Skeleton(height: 148),
          SizedBox(height: AppSpacing.xxl),
          Skeleton(width: 90, height: 12),
          SizedBox(height: AppSpacing.md),
          Skeleton(height: 220),
        ],
      ),
    );
  }
}
