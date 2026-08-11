import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/app_error_state.dart';
import 'package:drop/core/widgets/branch_avatar.dart';
import 'package:drop/core/widgets/settings_tiles.dart';
import 'package:drop/core/widgets/skeleton.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
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
/// **Settings and Profile are peers of the account area.** On mobile the
/// app-bar avatar opens Profile directly, and a Settings gear in this screen's
/// app bar reaches the hub (Change Password / Sign Out); on desktop the sidebar
/// footer still opens Settings, whose identity card opens Profile. So Profile
/// answers *who am I and what are my details*, and **nothing else** in its body
/// — it carries no Settings *row* and no Sign out inline; the account hub is the
/// app-bar gear, not a body row.
///
/// That body rule is a correction, not a preference: this screen used to offer
/// both inline, so the one destructive action in the app lived on two different
/// screens. Do not re-add a Sign-out / Settings *row* to the body; the gear is
/// the single account-hub entry from here.
///
/// It borrows Settings' grouped glass rows (`core/widgets/settings_tiles.dart`)
/// and entrance stagger so the two read as one system. What is specific to a
/// profile is the identity lockup and the fact rows, which lead with the value
/// rather than a destination name.
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
      // The account picture now opens Profile directly (role_scaffold), so
      // Settings — Change Password / Sign Out — is reachable from here via this
      // gear. On mobile the avatar is the only door into the account area, so
      // this action is what keeps Sign Out reachable.
      actions: [
        IconButton(
          tooltip: 'Settings',
          icon: const Icon(Icons.settings_outlined,
              color: AppColors.textSecondary),
          onPressed: () => context.push(RouteNames.settings),
        ),
      ],
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
    // for an admin) — so an admin's contact rows are read-only here rather than
    // opening a form that has no such field.
    final VoidCallback? editContact = context.isAdmin ? null : edit;

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
                  onEdit: editContact,
                ),
                ProfileDetailRow(
                  icon: Icons.home_outlined,
                  label: 'Address',
                  value: profile.address,
                  onEdit: editContact,
                ),
                ProfileDetailRow(
                  icon: Icons.emergency_outlined,
                  label: 'Emergency contact',
                  value: profile.emergencyContact,
                  copyable: true,
                  onEdit: editContact,
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

          // Nothing follows. Profile is a **leaf** of the account hub, not a
          // second hub: it had a Settings row (Settings → Profile → Settings,
          // a closed loop) and its own Sign out card, so the same destructive
          // action existed on two screens. Both live in Settings, which is the
          // one door in — see the class doc.
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
    final position = (user?.position ?? '').trim();

    if (branchId.isEmpty) {
      return SettingsGroup(
        children: [
          ProfileDetailRow(
            icon: Icons.storefront_outlined,
            label: 'Branch',
            value: isGlobal ? 'All branches · organisation-wide' : null,
            isFirst: true,
            isLast: position.isEmpty,
          ),
          if (position.isNotEmpty)
            ProfileDetailRow(
              icon: Icons.badge_outlined,
              label: 'Position',
              value: position,
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
              isLast: position.isEmpty && shift.isEmpty,
            ),
            if (position.isNotEmpty)
              ProfileDetailRow(
                icon: Icons.badge_outlined,
                label: 'Position',
                value: position,
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
