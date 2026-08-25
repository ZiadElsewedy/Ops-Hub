import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/core/responsive/breakpoints.dart';
import 'package:opshub/core/routes/route_names.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/theme/phosphor_icons.dart';
import 'package:opshub/core/widgets/adaptive_scaffold.dart';
import 'package:opshub/core/widgets/app_bottom_nav.dart';
import 'package:opshub/core/widgets/opshub_lockup.dart';
import 'package:opshub/core/widgets/user_avatar.dart';
import 'package:opshub/core/extensions/context_extensions.dart';
import 'package:opshub/features/notifications/presentation/cubit/notification_cubit.dart';
import 'package:opshub/features/notifications/presentation/cubit/notification_state.dart';

/// Shared chrome for every role's home dashboard (admin / manager / employee).
///
/// * **Desktop / macOS** → the persistent navigation lives in [AppShell]'s
///   sidebar, so here we only render the dashboard under a clean
///   [AdaptiveScaffold] page header. No app bar, no bottom nav.
/// * **Mobile / tablet** → the original chrome: a compact app bar
///   (notification bell + tappable avatar → the More/Settings hub, which holds
///   Profile · Change Password · Sign Out) and the OpsHub bottom navigation bar
///   (Home · Tasks · Schedule · Chat). Chat opens the conversation inbox; the
///   list self-scopes and access is enforced server-side.
class RoleScaffold extends StatelessWidget {
  const RoleScaffold({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  static const List<AppNavItem> _items = [
    AppNavItem(
      icon: PhosphorIconsRegular.house,
      activeIcon: PhosphorIconsFill.house,
      label: 'Home',
    ),
    AppNavItem(
      icon: PhosphorIconsRegular.listChecks,
      activeIcon: PhosphorIconsFill.listChecks,
      label: 'Tasks',
    ),
    AppNavItem(
      icon: PhosphorIconsRegular.calendarDots,
      activeIcon: PhosphorIconsFill.calendarDots,
      label: 'Schedule',
    ),
    AppNavItem(
      icon: PhosphorIconsRegular.chatCircle,
      activeIcon: PhosphorIconsFill.chatCircle,
      label: 'Chat',
    ),
  ];

  void _onNavTap(BuildContext context, int index) {
    final role = context.currentRole;
    if (role == null) return;
    switch (index) {
      case 0:
        break; // Already on the role home.
      case 1:
        context.push(RouteNames.tasksForRole(role));
      case 2:
        context.push(RouteNames.scheduleForRole(role));
      case 3:
        // The conversation inbox (not a specific thread). Role-agnostic — the
        // list self-scopes and the backend enforces participant access.
        context.push(RouteNames.chat);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Desktop: the AppShell sidebar is the navigation; just lay the dashboard
    // out under a premium page header.
    if (context.isDesktop) {
      return AdaptiveScaffold(title: title, body: child);
    }
    return _buildMobile(context, context.currentRole ?? UserRole.employee);
  }

  Widget _buildMobile(BuildContext context, UserRole role) {
    final user = context.currentUser;
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        titleSpacing: 24,
        // Brand lockup (mark + "OpsHub" name) leads every role's home. It is
        // wrapped in a scale-down FittedBox so on a crowded bar (the manager has
        // the most actions of any role) it shrinks as one unit rather than
        // truncating the name to "OpsH…" — the exact failure the plain role
        // word had here before. [title] (the role) is the lockup's accessible
        // label and still titles the desktop header; each home's hero greets the
        // user by name, so the bar never needs to spell the role visibly.
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: OpsHubLockup(height: 22, semanticLabel: title),
        ),
        actions: [
          // Communications Center — admin + manager only (employees can't access).
          if (role.isAdmin || role.isManager)
            IconButton(
              icon: const Icon(PhosphorIconsRegular.megaphone,
                  color: AppColors.textSecondary),
              tooltip: 'Communications',
              onPressed: () => context.push(RouteNames.communications),
            ),
          // Attendance — GPS clock in/out, for the roles that work shifts.
          if (role.isEmployee || role.isManager)
            IconButton(
              icon: const Icon(PhosphorIconsRegular.fingerprint,
                  color: AppColors.textSecondary),
              tooltip: 'Attendance',
              onPressed: () => context.push(RouteNames.attendance),
            ),
          // Operations Requests — available to every role (the list self-scopes).
          IconButton(
            icon: const Icon(PhosphorIconsRegular.stamp,
                color: AppColors.textSecondary),
            tooltip: 'Requests',
            onPressed: () => context.push(RouteNames.requests),
          ),
          // Cases moved to Settings → Workspace (it's a reference tool, not a
          // daily-home action) to declutter the app bar, which was overflowing
          // the title on the manager/admin roles.
          _NotificationBell(
            onPressed: () => context.push(RouteNames.notifications),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 4),
            child: GestureDetector(
              // Tapping your picture opens your Profile directly. Settings
              // (Change Password / Sign Out) stays one tap away via the gear in
              // the Profile app bar — so nothing is stranded on mobile, where
              // this avatar is the only entry into the account area.
              onTap: () => context.push(RouteNames.profile),
              child: user != null
                  ? UserAvatar.fromUser(user,
                      size: 36,
                      ringColor: role.isGlobal
                          ? AppColors.primary
                          : AppColors.darkBorder)
                  : const UserAvatar(size: 36),
            ),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: AppBottomNav(
        items: _items,
        currentIndex: 0,
        onTap: (i) => _onNavTap(context, i),
      ),
    );
  }
}

/// The header notification bell with an unread-count dot (Notification System
/// Phase 1). Reads [NotificationCubit] for the unread count.
class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationCubit, NotificationState>(
      builder: (context, _) {
        final unread = context.read<NotificationCubit>().unreadCount;
        return IconButton(
          tooltip: 'Notifications',
          onPressed: onPressed,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(PhosphorIconsRegular.bell,
                  color: AppColors.textSecondary),
              if (unread > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    constraints:
                        const BoxConstraints(minWidth: 14, minHeight: 14),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: AppColors.darkBg, width: 1.5),
                    ),
                    child: Text(
                      unread > 9 ? '9+' : '$unread',
                      textAlign: TextAlign.center,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
