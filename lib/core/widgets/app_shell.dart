import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/responsive/breakpoints.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/app_sidebar.dart';
import 'package:drop/core/widgets/command_palette.dart';
import 'package:drop/core/widgets/user_avatar.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/chat/presentation/cubit/chat_list_cubit.dart';
import 'package:drop/features/chat/presentation/cubit/chat_list_state.dart';
import 'package:drop/features/notifications/presentation/cubit/notification_cubit.dart';
import 'package:drop/features/notifications/presentation/cubit/notification_state.dart';

/// The desktop application shell — the single source of persistent navigation
/// chrome for the whole signed-in app.
///
/// Wired into the router as a [ShellRoute] so the [AppSidebar] is mounted **once**
/// and survives every route change (no re-animation, no flicker) — the structural
/// difference between a real macOS productivity app and a stack of pushed mobile
/// screens. On mobile/tablet the shell is a no-op pass-through: those widths keep
/// the original per-screen app bars + bottom navigation untouched.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.location, required this.child});

  /// Current router location (from `GoRouterState.matchedLocation`).
  final String location;
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();

  static const _digitKeys = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];

  /// The role's sidebar destinations — public so the ⌘K command palette can
  /// present the same list with the same ⌘n ordering.
  static List<SidebarSection> sectionsForRole(UserRole role) {
    const notifications = SidebarItem(
      icon: Icons.notifications_none_rounded,
      activeIcon: Icons.notifications_rounded,
      label: 'Notifications',
      route: RouteNames.notifications,
    );
    const communications = SidebarItem(
      icon: Icons.campaign_outlined,
      activeIcon: Icons.campaign_rounded,
      label: 'Communications',
      route: RouteNames.communications,
    );
    const chat = SidebarItem(
      icon: Icons.chat_bubble_outline_rounded,
      activeIcon: Icons.chat_bubble_rounded,
      label: 'Chat',
      route: RouteNames.chat,
      trailingBuilder: _chatUnreadBadge,
    );
    const cases = SidebarItem(
      icon: Icons.forum_outlined,
      activeIcon: Icons.forum_rounded,
      label: 'Cases',
      route: RouteNames.cases,
    );
    const requests = SidebarItem(
      icon: Icons.approval_outlined,
      activeIcon: Icons.approval_rounded,
      label: 'Requests',
      route: RouteNames.requests,
    );
    const attendance = SidebarItem(
      icon: Icons.fingerprint_rounded,
      activeIcon: Icons.fingerprint_rounded,
      label: 'Attendance',
      route: RouteNames.attendance,
    );

    switch (role) {
      case UserRole.admin:
        return [
          const SidebarSection(items: [
            SidebarItem(
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard_rounded,
              label: 'Dashboard',
              route: RouteNames.adminDashboard,
            ),
            SidebarItem(
              icon: Icons.fact_check_outlined,
              activeIcon: Icons.fact_check_rounded,
              label: 'Tasks',
              route: RouteNames.adminTasks,
            ),
            SidebarItem(
              icon: Icons.calendar_view_week_outlined,
              activeIcon: Icons.calendar_view_week_rounded,
              label: 'Schedule',
              route: RouteNames.adminSchedule,
            ),
            SidebarItem(
              icon: Icons.fingerprint_rounded,
              activeIcon: Icons.fingerprint_rounded,
              label: 'Attendance',
              route: RouteNames.adminAttendance,
            ),
            communications,
            chat,
            cases,
            requests,
            notifications,
          ]),
          const SidebarSection(title: 'Administration', items: [
            SidebarItem(
              icon: Icons.analytics_outlined,
              activeIcon: Icons.analytics_rounded,
              label: 'Analytics',
              route: RouteNames.adminAnalytics,
            ),
            SidebarItem(
              icon: Icons.store_outlined,
              activeIcon: Icons.store_rounded,
              label: 'Branches',
              route: RouteNames.adminBranches,
            ),
            SidebarItem(
              icon: Icons.badge_outlined,
              activeIcon: Icons.badge_rounded,
              label: 'Managers',
              route: RouteNames.adminManagers,
            ),
            SidebarItem(
              icon: Icons.people_outline_rounded,
              activeIcon: Icons.people_rounded,
              label: 'Employees',
              route: RouteNames.adminEmployees,
            ),
          ]),
        ];
      case UserRole.manager:
        return [
          const SidebarSection(items: [
            SidebarItem(
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard_rounded,
              label: 'Dashboard',
              route: RouteNames.managerHome,
            ),
            SidebarItem(
              icon: Icons.fact_check_outlined,
              activeIcon: Icons.fact_check_rounded,
              label: 'Operations',
              route: RouteNames.managerTasks,
            ),
            SidebarItem(
              icon: Icons.calendar_view_week_outlined,
              activeIcon: Icons.calendar_view_week_rounded,
              label: 'Schedule',
              route: RouteNames.managerSchedule,
            ),
            SidebarItem(
              icon: Icons.fingerprint_rounded,
              activeIcon: Icons.fingerprint_rounded,
              label: 'Attendance',
              route: RouteNames.attendanceReview,
            ),
            communications,
            chat,
            cases,
            requests,
            notifications,
          ]),
        ];
      case UserRole.employee:
        return [
          const SidebarSection(items: [
            SidebarItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Home',
              route: RouteNames.home,
            ),
            SidebarItem(
              icon: Icons.fact_check_outlined,
              activeIcon: Icons.fact_check_rounded,
              label: 'My Tasks',
              route: RouteNames.myTasks,
            ),
            SidebarItem(
              icon: Icons.calendar_view_week_outlined,
              activeIcon: Icons.calendar_view_week_rounded,
              label: 'My Schedule',
              route: RouteNames.mySchedule,
            ),
            attendance,
            chat,
            cases,
            requests,
            notifications,
          ]),
        ];
    }
  }
}

class _AppShellState extends State<AppShell> {
  /// Distraction-free mode: the persistent nav sidebar collapses so the active
  /// screen (schedule, tasks…) runs full-width — Notion/Linear focus mode.
  /// Collapsing the shell sidebar is app-wide by nature, so this applies to
  /// every desktop screen, toggled with ⌘\ or the sidebar's collapse control.
  /// Held in State: the shell is mounted once by the router's [ShellRoute], so
  /// the choice survives every route change within a session. (It resets on a
  /// cold launch — cross-restart memory needs a local-prefs store the app does
  /// not have yet.)
  bool _focusMode = false;

  void _toggleFocus() => setState(() => _focusMode = !_focusMode);

  @override
  Widget build(BuildContext context) {
    final location = widget.location;
    // Mobile / tablet: unchanged. Also bail out if we somehow render without a
    // session (the router's redirect guards normally prevent this).
    final user = context.currentUser;
    if (!context.isDesktop || user == null) return widget.child;

    final role = user.role;
    final sections = AppShell.sectionsForRole(role);
    final destinations = [for (final s in sections) ...s.items];
    // Honour the OS "reduce motion" switch for the collapse animation.
    final animate = !MediaQuery.of(context).disableAnimations;

    // ⌘1…⌘9 jump straight to the Nth sidebar destination, ⌘K opens the command
    // palette, and ⌘\ toggles focus mode — the baseline keyboard navigation a
    // native macOS productivity app is expected to have. CallbackShortcuts
    // fires whenever focus is anywhere in the subtree; meta combos never insert
    // text, so they're safe while typing.
    return CallbackShortcuts(
      bindings: {
        for (var i = 0;
            i < destinations.length && i < AppShell._digitKeys.length;
            i++)
          SingleActivator(AppShell._digitKeys[i], meta: true): () {
            final route = destinations[i].route;
            if (route != location) context.go(route);
          },
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
            showCommandPalette(context, user: user, sections: sections),
        const SingleActivator(LogicalKeyboardKey.backslash, meta: true):
            _toggleFocus,
      },
      child: FocusScope(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppColors.darkBg,
          body: Stack(
            children: [
              Positioned.fill(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Collapsible sidebar: its width eases to 0 in focus mode
                    // while the sidebar keeps its natural width internally, so
                    // its contents never reflow mid-collapse.
                    _CollapsibleSidebar(
                      collapsed: _focusMode,
                      animate: animate,
                      child: AppSidebar(
                        sections: sections,
                        location: location,
                        onCollapse: _toggleFocus,
                        onSelect: (route) {
                          if (route != location) context.go(route);
                        },
                        footer: _SidebarUserFooter(
                          user: user,
                          role: role,
                          onTap: () => context.go(RouteNames.profile),
                        ),
                      ),
                    ),
                    // The child is go_router's shell Navigator — ONE widget with
                    // a GlobalKey. It must never be wrapped in anything that
                    // mounts it twice (AnimatedSwitcher, cross-fades, keyed
                    // swaps): that duplicates the GlobalKey mid-transition,
                    // corrupts the element tree, and froze all navigation on
                    // macOS. Its position in this Row is stable across focus
                    // toggles, so the element is never remounted. The desktop
                    // fade between destinations already lives at the PAGE level.
                    Expanded(child: widget.child),
                  ],
                ),
              ),
              // When the sidebar is hidden, a quiet handle brings it back (⌘\
              // also works). It fades with focus mode rather than popping.
              Positioned(
                top: 14,
                left: 12,
                child: _FocusRestoreHandle(
                  visible: _focusMode,
                  animate: animate,
                  onExpand: _toggleFocus,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pinned sidebar footer: unread-aware avatar + name + role, tappable → profile.
class _SidebarUserFooter extends StatefulWidget {
  const _SidebarUserFooter({
    required this.user,
    required this.role,
    required this.onTap,
  });

  final UserEntity user;
  final UserRole role;
  final VoidCallback onTap;

  @override
  State<_SidebarUserFooter> createState() => _SidebarUserFooterState();
}

class _SidebarUserFooterState extends State<_SidebarUserFooter> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final name = (user.displayName?.isNotEmpty ?? false)
        ? user.displayName!
        : 'Profile';
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _hovered ? const Color(0x12FFFFFF) : AppColors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              UserAvatar.fromUser(user, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label,
                    ),
                    Text(
                      widget.role.name.toUpperCase(),
                      style: AppTypography.caption.copyWith(
                        letterSpacing: 1,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const _FooterBell(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sidebar trailing badge for the Chat destination — the live total unread
/// count across all conversations (hidden at zero). Top-level so it can be a
/// `const` tear-off on the chat [SidebarItem].
Widget _chatUnreadBadge(BuildContext context) => const _ChatUnreadBadge();

class _ChatUnreadBadge extends StatelessWidget {
  const _ChatUnreadBadge();

  @override
  Widget build(BuildContext context) {
    // Optional dependency: the app always provides the singleton ChatListCubit,
    // but isolated widget tests that render the shell may not — degrade to
    // nothing rather than throwing a provider-not-found.
    ChatListCubit? cubit;
    try {
      cubit = context.read<ChatListCubit>();
    } catch (_) {
      return const SizedBox.shrink();
    }
    return BlocBuilder<ChatListCubit, ChatListState>(
      bloc: cubit,
      builder: (context, _) {
        final unread = cubit!.totalUnread;
        if (unread <= 0) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(left: 6),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          constraints: const BoxConstraints(minWidth: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            unread > 99 ? '99+' : '$unread',
            style: AppTypography.caption.copyWith(
              color: AppColors.onAccent,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        );
      },
    );
  }
}

/// Small unread-count indicator in the footer so notifications are glanceable
/// even when the inbox isn't the active destination.
class _FooterBell extends StatelessWidget {
  const _FooterBell();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationCubit, NotificationState>(
      builder: (context, _) {
        final unread = context.read<NotificationCubit>().unreadCount;
        if (unread <= 0) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(left: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            unread > 9 ? '9+' : '$unread',
            style: AppTypography.caption.copyWith(
              color: AppColors.onAccent,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      },
    );
  }
}

/// Wraps the [AppSidebar] so its width can ease to 0 for focus mode. The child
/// keeps its natural [Breakpoints.sidebarWidth] internally ([OverflowBox]) and
/// is clipped as the outer box shrinks, so nothing inside reflows while
/// collapsing. [IgnorePointer] kills phantom hits once it is hidden.
class _CollapsibleSidebar extends StatelessWidget {
  const _CollapsibleSidebar({
    required this.collapsed,
    required this.animate,
    required this.child,
  });

  final bool collapsed;
  final bool animate;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: animate ? const Duration(milliseconds: 240) : Duration.zero,
      curve: Curves.easeInOutCubic,
      width: collapsed ? 0 : Breakpoints.sidebarWidth,
      child: IgnorePointer(
        ignoring: collapsed,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: Breakpoints.sidebarWidth,
            maxWidth: Breakpoints.sidebarWidth,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The floating "show sidebar" control shown over the top-left of the content
/// while focus mode is on. Fades with [visible] instead of popping in/out.
class _FocusRestoreHandle extends StatefulWidget {
  const _FocusRestoreHandle({
    required this.visible,
    required this.animate,
    required this.onExpand,
  });

  final bool visible;
  final bool animate;
  final VoidCallback onExpand;

  @override
  State<_FocusRestoreHandle> createState() => _FocusRestoreHandleState();
}

class _FocusRestoreHandleState extends State<_FocusRestoreHandle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration:
          widget.animate ? const Duration(milliseconds: 200) : Duration.zero,
      opacity: widget.visible ? 1 : 0,
      child: IgnorePointer(
        ignoring: !widget.visible,
        child: Semantics(
          button: true,
          label: 'Show sidebar',
          child: Tooltip(
            message: 'Show sidebar   ⌘\\',
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hovered = true),
              onExit: (_) => setState(() => _hovered = false),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onExpand,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _hovered
                        ? const Color(0xFF232327)
                        : AppColors.darkSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.darkBorder),
                  ),
                  child: const Icon(
                    Icons.menu_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
