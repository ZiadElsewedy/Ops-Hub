import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:drop/features/auth/presentation/cubit/auth_state.dart';

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
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.lg),

                // ── Account ──
                const _SectionHeader(label: 'Account'),
                const SizedBox(height: AppSpacing.md),
                _SettingsGroup(
                  children: [
                    _SettingsRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Profile',
                      subtitle: user?.displayName ?? user?.email ?? '',
                      isFirst: true,
                      onTap: () => context.push(RouteNames.profile),
                    ),
                    // Every DROP account is email/password (admin-provisioned).
                    _SettingsRow(
                      icon: Icons.lock_outline_rounded,
                      label: 'Change Password',
                      onTap: () => context.push(RouteNames.changePassword),
                    ),
                    _SettingsRow(
                      icon: Icons.logout_rounded,
                      label: 'Sign Out',
                      isLast: true,
                      onTap: () => context.read<AuthCubit>().signOut(),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xxl),

                // ── Workspace ──
                // Cases lives here (not in the crowded home app bar) — it's a
                // reference tool, not a daily-home action.
                const _SectionHeader(label: 'Workspace'),
                const SizedBox(height: AppSpacing.md),
                _SettingsGroup(
                  children: [
                    _SettingsRow(
                      icon: Icons.forum_outlined,
                      label: 'Cases',
                      isFirst: true,
                      isLast: true,
                      onTap: () => context.push(RouteNames.cases),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xxl),

                // ── About ──
                const _SectionHeader(label: 'About'),
                const SizedBox(height: AppSpacing.md),
                _VersionRow(),

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          );
        },
      ),
    );
  }

}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          label.toUpperCase(),
          style: AppTypography.caption.copyWith(letterSpacing: 1.2),
        ),
      );
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!isFirst)
          const Divider(
            height: 1,
            thickness: 1,
            color: AppColors.darkBorder,
            indent: AppSpacing.pagePadding,
            endIndent: AppSpacing.pagePadding,
          ),
        InkWell(
          onTap: onTap,
          borderRadius: isFirst && isLast
              ? AppRadius.cardAll
              : isFirst
                  ? const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.card))
                  : isLast
                      ? const BorderRadius.vertical(
                          bottom: Radius.circular(AppRadius.card))
                      : BorderRadius.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePadding,
              vertical: AppSpacing.lg,
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: AppTypography.label),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VersionRow extends StatefulWidget {
  @override
  State<_VersionRow> createState() => _VersionRowState();
}

class _VersionRowState extends State<_VersionRow> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    if (mounted) setState(() => _version = '1.0.0 (1)');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePadding,
          vertical: AppSpacing.lg,
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                size: 18, color: AppColors.primary),
            const SizedBox(width: AppSpacing.md),
            const Expanded(
              child: Text('App Version',
                  style: AppTypography.label),
            ),
            Text(
              _version.isNotEmpty ? _version : '—',
              style: AppTypography.body,
            ),
          ],
        ),
      ),
    );
  }
}
