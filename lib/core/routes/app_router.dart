import 'package:flutter/cupertino.dart' show CupertinoPage;
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/routes/app_page_route.dart';
import 'package:drop/core/utils/app_logger.dart';
import 'package:drop/core/widgets/app_shell.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:drop/features/auth/presentation/pages/splash_page.dart';
import 'package:drop/features/auth/presentation/pages/login_page.dart';
import 'package:drop/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:drop/features/auth/presentation/pages/force_password_change_page.dart';
import 'package:drop/features/auth/presentation/pages/profile_completion_page.dart';
import 'package:drop/features/auth/presentation/pages/onboarding_welcome_page.dart';
import 'package:drop/features/admin/presentation/pages/admin_shell.dart';
import 'package:drop/features/manager/presentation/pages/manager_shell.dart';
import 'package:drop/features/employee/presentation/pages/employee_shell.dart';
import 'package:drop/features/task/presentation/pages/task_management_screen.dart';
import 'package:drop/features/task/presentation/pages/pending_review_screen.dart';
import 'package:drop/features/task/presentation/pages/my_tasks_screen.dart';
import 'package:drop/features/task/presentation/pages/task_detail_loader_screen.dart';
import 'package:drop/features/operations/presentation/pages/manager_operations_screen.dart';
import 'package:drop/features/schedule/presentation/pages/schedule_management_screen.dart';
import 'package:drop/features/schedule/presentation/pages/branch_schedule_screen.dart';
import 'package:drop/features/schedule/presentation/pages/my_schedule_screen.dart';
import 'package:drop/features/branch/presentation/pages/branch_management_screen.dart';
import 'package:drop/features/admin/presentation/pages/manager_management_screen.dart';
import 'package:drop/features/admin/presentation/pages/employee_management_screen.dart';
import 'package:drop/features/admin/presentation/pages/admin_analytics_screen.dart';
import 'package:drop/features/admin/presentation/pages/create_account_screen.dart';
import 'package:drop/features/profile/presentation/pages/profile_page.dart';
import 'package:drop/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:drop/features/settings/presentation/pages/settings_page.dart';
import 'package:drop/features/settings/presentation/pages/change_password_page.dart';
import 'package:drop/features/settings/presentation/pages/about_page.dart';
import 'package:drop/features/settings/presentation/pages/notifications_settings_screen.dart';
import 'package:drop/features/communications/domain/entities/broadcast_entity.dart';
import 'package:drop/features/communications/presentation/pages/communications_screen.dart';
import 'package:drop/features/communications/presentation/pages/compose_broadcast_screen.dart';
import 'package:drop/features/communications/presentation/pages/broadcast_detail_screen.dart';
import 'package:drop/features/communications/presentation/pages/broadcast_templates_screen.dart';
import 'package:drop/features/communications/presentation/pages/broadcast_schedules_screen.dart';
import 'package:drop/features/notifications/presentation/pages/notifications_screen.dart';
import 'package:drop/features/cases/presentation/pages/cases_screen.dart';
import 'package:drop/features/cases/presentation/pages/create_case_screen.dart';
import 'package:drop/features/cases/presentation/pages/case_conversation_screen.dart';
import 'package:drop/features/chat/presentation/pages/chat_screen.dart';
import 'package:drop/features/chat/presentation/pages/chat_conversation_screen.dart';
import 'package:drop/features/chat/presentation/chat_thread_args.dart';
import 'package:drop/features/chat/presentation/pages/new_chat_screen.dart';
import 'package:drop/features/attendance/domain/attendance_review_link.dart';
import 'package:drop/features/attendance/domain/entities/attendance_entity.dart';
import 'package:drop/features/attendance/presentation/pages/attendance_screen.dart';
import 'package:drop/features/sales/presentation/pages/sales_submission_screen.dart';
import 'package:drop/features/sales/presentation/pages/sales_manager_dashboard_screen.dart';
import 'package:drop/features/sales/presentation/pages/sales_history_screen.dart';
import 'package:drop/features/sales/presentation/pages/sales_submission_detail_screen.dart';
import 'package:drop/features/sales/presentation/pages/sales_admin_overview_screen.dart';
import 'package:drop/features/sales/presentation/pages/employee_sales_screen.dart';
import 'package:drop/core/di/injection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/features/attendance/presentation/pages/admin_attendance_screen.dart';
import 'package:drop/features/attendance/presentation/reporting/attendance_reports_screen.dart';
import 'package:drop/features/attendance/presentation/history/attendance_history_screen.dart';
import 'package:drop/features/attendance/presentation/details/attendance_details_screen.dart';
import 'package:drop/features/attendance/presentation/admin/attendance_admin_workspace_screen.dart';
import 'package:drop/features/attendance/presentation/daily/attendance_daily_review_screen.dart';
import 'package:drop/features/attendance/presentation/reporting/attendance_monthly_report_screen.dart';
import 'package:drop/features/attendance/presentation/reporting/attendance_weekly_report_screen.dart';
import 'package:drop/features/requests/presentation/pages/requests_screen.dart';
import 'package:drop/features/requests/presentation/pages/create_request_screen.dart';
import 'package:drop/features/requests/presentation/pages/request_detail_screen.dart';
import 'route_names.dart';

GoRouter createRouter(
  AuthCubit authCubit, {
  String initialLocation = RouteNames.splash,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: _AuthStateNotifier(authCubit),
    observers: [LoggingNavigatorObserver('root')],
    redirect: (BuildContext context, GoRouterState state) {
      final target = _redirect(authCubit, state);
      if (target != null) {
        AppLog.route('redirect ${state.matchedLocation} → $target');
      }
      return target;
    },
    routes: [
      // ─── Outside the app shell: splash + auth + first-login onboarding ──
      // These must NOT show the persistent sidebar.
      GoRoute(
        path: RouteNames.splash,
        pageBuilder: (context, state) => NoTransitionPage(
          child: SplashPage(onAnimationComplete: () {}, isBootstrapping: false),
        ),
      ),
      GoRoute(
        path: RouteNames.login,
        pageBuilder: (context, state) =>
            _pushPage(state, const LoginPage()),
      ),
      GoRoute(
        path: RouteNames.forgotPassword,
        pageBuilder: (context, state) =>
            _pushPage(state, const ForgotPasswordPage()),
      ),
      GoRoute(
        path: RouteNames.forcePasswordChange,
        pageBuilder: (context, state) =>
            _fadeTransition(state, const ForcePasswordChangePage()),
      ),
      GoRoute(
        path: RouteNames.profileCompletion,
        pageBuilder: (context, state) =>
            _fadeTransition(state, const ProfileCompletionPage()),
      ),
      GoRoute(
        path: RouteNames.welcome,
        pageBuilder: (context, state) =>
            _fadeTransition(state, const OnboardingWelcomePage()),
      ),
      // ─── App shell: persistent desktop sidebar across every route below ──
      ShellRoute(
        observers: [LoggingNavigatorObserver('shell')],
        builder: (context, state, child) =>
            AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: RouteNames.home,
            pageBuilder: (context, state) =>
                _homePage(state, const EmployeeShell()),
          ),
          GoRoute(
            path: RouteNames.adminDashboard,
            pageBuilder: (context, state) =>
                _homePage(state, const AdminShell()),
          ),
          GoRoute(
            path: RouteNames.managerHome,
            pageBuilder: (context, state) =>
                _homePage(state, const ManagerShell()),
          ),
          GoRoute(path: RouteNames.salesManage, pageBuilder: (context, state) {
            final branchId = _salesBranchId(authCubit, state);
            return _pushPage(state, BlocProvider(create: (_) => AppDependencies.createSalesManagerDashboardCubit(), child: SalesManagerDashboardScreen(branchId: branchId)));
          }),
          GoRoute(path: RouteNames.salesAdminOverview, pageBuilder: (context, state) => _pushPage(state, BlocProvider(create: (_) => AppDependencies.createSalesAdminOverviewCubit(), child: const SalesAdminOverviewScreen()))),
          GoRoute(path: RouteNames.salesHistory, pageBuilder: (context, state) {
            final branchId = _salesBranchId(authCubit, state);
            return _pushPage(state, BlocProvider(create: (_) => AppDependencies.createSalesManagerDashboardCubit(), child: SalesHistoryScreen(branchId: branchId, status: state.uri.queryParameters['status'])));
          }),
          GoRoute(path: RouteNames.salesSubmissionDetailPattern, pageBuilder: (context, state) => _pushPage(state, BlocProvider(create: (_) => AppDependencies.createSalesSubmissionDetailCubit(state.pathParameters['submissionId'] ?? ''), child: SalesSubmissionDetailScreen(submissionId: state.pathParameters['submissionId'] ?? '')))),
          // ─── Tasks (Phase 3) ───────────────────────────────────────
          // Guarded like the rest: /admin/tasks is admin-only, /manager/tasks admits
          // manager + admin; /my-tasks is self-scoped.
          GoRoute(
            path: RouteNames.adminTasks,
            pageBuilder: (context, state) =>
                _pushPage(state, const TaskManagementScreen()),
          ),
          // Admin Pending Review drill-down (Summary → Branch → Employee → Task).
          GoRoute(
            path: RouteNames.adminReview,
            pageBuilder: (context, state) =>
                _pushPage(state, const PendingReviewScreen()),
          ),
          // Manager "Operations" tab → the Branch Operations cockpit for the
          // manager's own branch (the task→operations redesign; the full per-branch
          // task list is now reached via the cockpit's "All tasks" → BranchTaskListScreen).
          GoRoute(
            path: RouteNames.managerTasks,
            pageBuilder: (context, state) =>
                _pushPage(state, const ManagerOperationsScreen()),
          ),
          GoRoute(
            path: RouteNames.myTasks,
            pageBuilder: (context, state) =>
                _pushPage(state, const MyTasksScreen()),
          ),
          // Exact-task deep-link (every role) — a task notification lands here.
          GoRoute(
            path: RouteNames.taskDetailPattern,
            pageBuilder: (context, state) => _pushPage(
              state,
              TaskDetailLoaderScreen(
                taskId: state.pathParameters['taskId'] ?? '',
              ),
            ),
          ),
          // ─── Weekly schedule (Phase 7) ─────────────────────────────
          // Guarded like tasks: /admin/schedule is admin-only, /manager/schedule
          // admits manager + admin; /my-schedule is self-scoped (own branch).
          GoRoute(
            path: RouteNames.adminSchedule,
            pageBuilder: (context, state) =>
                _pushPage(state, const ScheduleManagementScreen()),
          ),
          GoRoute(
            path: RouteNames.managerSchedule,
            pageBuilder: (context, state) =>
                _pushPage(state, const BranchScheduleScreen()),
          ),
          GoRoute(
            path: RouteNames.mySchedule,
            pageBuilder: (context, state) =>
                _pushPage(state, const MyScheduleScreen()),
          ),
          // ─── Admin module (Phase 5) ────────────────────────────────
          // All under /admin/*, covered by the admin-only `_isAdminArea` guard.
          GoRoute(
            path: RouteNames.adminBranches,
            pageBuilder: (context, state) =>
                _pushPage(state, const BranchManagementScreen()),
          ),
          GoRoute(
            path: RouteNames.adminManagers,
            pageBuilder: (context, state) =>
                _pushPage(state, const ManagerManagementScreen()),
          ),
          GoRoute(
            path: RouteNames.adminEmployees,
            pageBuilder: (context, state) =>
                _pushPage(state, const EmployeeManagementScreen()),
          ),
          GoRoute(
            path: RouteNames.adminAnalytics,
            pageBuilder: (context, state) =>
                _pushPage(state, const AdminAnalyticsScreen()),
          ),
          GoRoute(
            path: RouteNames.adminCreateAccount,
            pageBuilder: (context, state) =>
                _pushPage(state, const CreateAccountScreen()),
          ),
          // ─── Communications Center (Phase 3) ───────────────────────
          // admin + manager (employees blocked by `_isCommunicationsArea`). The
          // static `/compose` route is declared BEFORE the `:broadcastId` detail
          // route so it is never captured as an id.
          GoRoute(
            path: RouteNames.communications,
            pageBuilder: (context, state) =>
                _pushPage(state, const CommunicationsScreen()),
          ),
          GoRoute(
            path: RouteNames.communicationsCompose,
            pageBuilder: (context, state) => _pushPage(
              state,
              ComposeBroadcastScreen(
                prefill: state.extra is BroadcastEntity
                    ? state.extra as BroadcastEntity
                    : null,
              ),
            ),
          ),
          GoRoute(
            path: RouteNames.communicationsTemplates,
            pageBuilder: (context, state) => _pushPage(
              state,
              BroadcastTemplatesScreen(pickMode: state.extra == 'pick'),
            ),
          ),
          GoRoute(
            path: RouteNames.communicationsSchedules,
            pageBuilder: (context, state) =>
                _pushPage(state, const BroadcastSchedulesScreen()),
          ),
          GoRoute(
            path: RouteNames.communicationsDetailPattern,
            pageBuilder: (context, state) => _pushPage(
              state,
              BroadcastDetailScreen(
                broadcastId: state.pathParameters['broadcastId'] ?? '',
                broadcast: state.extra is BroadcastEntity
                    ? state.extra as BroadcastEntity
                    : null,
              ),
            ),
          ),
          // In-app notification inbox — shared by every role (not under /admin or
          // /manager, so no role guard blocks it).
          GoRoute(
            path: RouteNames.notifications,
            pageBuilder: (context, state) =>
                _pushPage(state, const NotificationsScreen()),
          ),
          // ─── Case Management (private conversation until resolution) ──────────
          // Shared by every role (like notifications); the list self-scopes by role
          // and Firestore rules enforce access. The static `/cases/create` route is
          // declared here; the singular `/case/:caseId` deep-link is a distinct path,
          // so it never captures `create`.
          GoRoute(
            path: RouteNames.cases,
            pageBuilder: (context, state) =>
                _pushPage(state, const CasesScreen()),
          ),
          GoRoute(
            path: RouteNames.casesCreate,
            pageBuilder: (context, state) =>
                _pushPage(state, const CreateCaseScreen()),
          ),
          GoRoute(
            path: RouteNames.caseDetailPattern,
            pageBuilder: (context, state) => _pushPage(
              state,
              CaseConversationScreen(
                caseId: state.pathParameters['caseId'] ?? '',
              ),
            ),
          ),
          // ─── Direct chat (NestJS backend) ────────────────────────────────────
          // Shared by every role; access is participant-scoped server-side, so no
          // role guard. The conversation pattern lives under the same `/chat`
          // prefix — go_router matches the static `/chat` path before the
          // parameterised child, so the inbox is never captured.
          GoRoute(
            path: RouteNames.chat,
            pageBuilder: (context, state) =>
                _pushPage(state, const ChatScreen()),
          ),
          // Static `/chat/new` MUST precede the `:conversationId` pattern so it
          // is matched as the picker, never captured as a conversation id.
          GoRoute(
            path: RouteNames.chatNew,
            pageBuilder: (context, state) =>
                _pushPage(state, const NewChatScreen()),
          ),
          GoRoute(
            path: RouteNames.chatConversationPattern,
            pageBuilder: (context, state) => _pushPage(
              state,
              ChatConversationScreen(
                conversationId: state.pathParameters['conversationId'] ?? '',
                args: state.extra is ChatThreadArgs
                    ? state.extra as ChatThreadArgs
                    : null,
              ),
            ),
          ),
          // ─── Operations Requests (in-the-moment approvals) ───────────────────
          // Shared by every role; the list self-scopes by role and Firestore
          // rules enforce access. The static `/requests/create` route is declared
          // before the singular `/request/:requestId` deep-link (a distinct path,
          // so it never captures `create`).
          GoRoute(
            path: RouteNames.requests,
            pageBuilder: (context, state) =>
                _pushPage(state, const RequestsScreen()),
          ),
          GoRoute(
            path: RouteNames.requestsCreate,
            pageBuilder: (context, state) =>
                _pushPage(state, const CreateRequestScreen()),
          ),
          GoRoute(
            path: RouteNames.requestDetailPattern,
            pageBuilder: (context, state) => _pushPage(
              state,
              RequestDetailScreen(
                requestId: state.pathParameters['requestId'] ?? '',
              ),
            ),
          ),
          GoRoute(
            path: RouteNames.adminAttendance,
            redirect: (context, state) => RouteNames.attendanceReports,
          ),
          GoRoute(
            path: RouteNames.adminAttendanceWorkspace,
            pageBuilder: (context, state) =>
                _pushPage(state, const AttendanceAdminWorkspaceScreen()),
          ),
          GoRoute(
            path: RouteNames.attendanceReports,
            pageBuilder: (context, state) =>
                _pushPage(state, const AdminAttendanceScreen()),
          ),
          GoRoute(
            path: RouteNames.attendanceReportsHub,
            pageBuilder: (context, state) =>
                _pushPage(state, const AttendanceReportsScreen()),
          ),
          GoRoute(
            path: RouteNames.attendanceWeeklyPattern,
            pageBuilder: (context, state) => _pushPage(
              state,
              AttendanceWeeklyReportScreen(
                periodId: state.pathParameters['periodId'] ?? '',
              ),
            ),
          ),
          GoRoute(
            path: RouteNames.attendanceDailyReviewPattern,
            pageBuilder: (context, state) => _pushPage(
              state,
              AttendanceDailyReviewScreen(
                branchId: state.pathParameters['branchId'] ?? '',
                dayKey: state.pathParameters['dayKey'] ?? '',
              ),
            ),
          ),
          GoRoute(
            path: RouteNames.attendanceMonthlyPattern,
            pageBuilder: (context, state) => _pushPage(
              state,
              AttendanceMonthlyReportScreen(
                periodId: state.pathParameters['periodId'] ?? '',
              ),
            ),
          ),
          GoRoute(
            path: RouteNames.attendance,
            pageBuilder: (context, state) =>
                _pushPage(state, const AttendanceScreen()),
          ),
          GoRoute(
            path: RouteNames.salesSubmit,
            pageBuilder: (context, state) => _pushPage(
              state,
              SalesSubmissionScreen(
                submissionId: state.uri.queryParameters['correct'],
              ),
            ),
          ),
          GoRoute(
            path: RouteNames.salesMine,
            pageBuilder: (context, state) =>
                _pushPage(state, const EmployeeSalesScreen()),
          ),
          // Attendance History — the employee's own ledger (role-shared).
          GoRoute(
            path: RouteNames.attendanceHistory,
            pageBuilder: (context, state) =>
                _pushPage(state, const AttendanceHistoryScreen.self()),
          ),
          // Manager/admin branch review (guarded by `_isAttendanceReviewArea`).
          // An [AttendanceReviewLink] may arrive as `extra` to open one person
          // inside the branch + period the link came from; a bare String is
          // still accepted as a name-only filter.
          GoRoute(
            path: RouteNames.attendanceReview,
            pageBuilder: (context, state) {
              final link = _attendanceReviewLink(state.extra);
              return _pushPage(
                state,
                AttendanceHistoryScreen.review(
                  initialBranchId: link?.branchId,
                  initialSearch: link?.employeeName,
                  initialStart: link?.start,
                  initialEnd: link?.end,
                ),
              );
            },
          ),
          // One record's audit detail, deep-linkable. The tapped record rides in
          // `extra` for an instant first paint; rules gate the read.
          GoRoute(
            path: RouteNames.attendanceRecordPattern,
            pageBuilder: (context, state) => _pushPage(
              state,
              AttendanceDetailsScreen(
                recordId: state.pathParameters['id'] ?? '',
                seed: state.extra is AttendanceEntity
                    ? state.extra as AttendanceEntity
                    : null,
              ),
            ),
          ),
          GoRoute(
            path: RouteNames.profile,
            pageBuilder: (context, state) =>
                _pushPage(state, const ProfilePage()),
          ),
          GoRoute(
            path: RouteNames.editProfile,
            pageBuilder: (context, state) =>
                _pushPage(state, const EditProfilePage()),
          ),
          GoRoute(
            path: RouteNames.settings,
            pageBuilder: (context, state) =>
                _pushPage(state, const SettingsPage()),
          ),
          GoRoute(
            path: RouteNames.changePassword,
            pageBuilder: (context, state) =>
                _pushPage(state, const ChangePasswordPage()),
          ),
          GoRoute(
            path: RouteNames.notificationSettings,
            pageBuilder: (context, state) =>
                _pushPage(state, const NotificationsSettingsScreen()),
          ),
          GoRoute(
            path: RouteNames.about,
            pageBuilder: (context, state) =>
                _pushPage(state, const AboutPage()),
          ),
        ],
      ),
    ],
  );
}

/// The auth / first-login / role redirect gate. Pure and synchronous — a
/// redirect must NEVER await (a blocked redirect stalls all navigation).
/// Extracted so the router can log the decision in one place.
String? _redirect(AuthCubit authCubit, GoRouterState state) {
  final loc = state.matchedLocation;

  final authState = authCubit.state;

  final user = authState.maybeWhen(authenticated: (u) => u, orElse: () => null);

  final isOnAuthFlow =
      loc == RouteNames.login || loc == RouteNames.forgotPassword;

  if (user != null) {
    // ── First-login gate (admin-provisioned accounts) ──
    // A single ordered decision (temp-password change → profile completion →
    // employees' one-time Welcome), extracted to `firstLoginLocation` so the
    // ordering is unit-tested. While a stage is required, the user is confined
    // to it; already there → allow (null).
    final forced = firstLoginLocation(user);
    if (forced != null) {
      return loc == forced ? null : forced;
    }

    final roleHome = RouteNames.homeForRole(user.role);

    // Role guard. Admin ⊇ manager: admin areas are admin-only, but manager
    // areas admit admins too. The employee home (/) is employee-only.
    // Shared routes (/profile, /settings) stay open to all roles.
    if (_isAdminArea(loc) && !user.role.isAdmin) return roleHome;
    if (loc == RouteNames.salesAdminOverview && !user.role.isAdmin) return roleHome;
    if (isManagerArea(loc) && !(user.role.isManager || user.role.isAdmin)) {
      return roleHome;
    }
    // Communications Center is admin + manager only; employees are bounced.
    if (_isCommunicationsArea(loc) && user.role.isEmployee) {
      return roleHome;
    }
    // Attendance branch review is admin + manager only; employees are bounced
    // (they still reach their OWN history at /attendance/history).
    if (_isAttendanceReviewArea(loc) && user.role.isEmployee) {
      return roleHome;
    }
    // Attendance reports are manager/admin only; employees keep the clock and
    // self-history surfaces.
    if (_isAttendanceReportsArea(loc) && user.role.isEmployee) {
      return roleHome;
    }
    // The two employee-owned sales surfaces. `/sales/history` and
    // `/sales/submission/:id` stay role-shared: they self-scope by role and
    // Firestore rules are the enforcement point (an employee reads only their
    // own records plus their branch's approved ones).
    if ((loc == RouteNames.salesSubmit || loc == RouteNames.salesMine) &&
        !user.role.isEmployee) {
      return roleHome;
    }
    if (loc == RouteNames.home && !user.role.isEmployee) {
      return roleHome;
    }

    // A fully onboarded user never sees the auth / onboarding screens.
    if (isOnAuthFlow ||
        loc == RouteNames.splash ||
        loc == RouteNames.forcePasswordChange ||
        loc == RouteNames.profileCompletion ||
        loc == RouteNames.welcome) {
      return roleHome;
    }

    return null;
  }

  // Only an EXPLICITLY unauthenticated session is bounced to Login —
  // transient cubit states (loading / passwordChanged / passwordResetSent /
  // error / initial) must NOT redirect, so an in-flight action (e.g. the
  // forced password change) never flickers the user out to Login.
  final isUnauthenticated = authState.maybeWhen(
    unauthenticated: () => true,
    orElse: () => false,
  );
  if (isUnauthenticated && !isOnAuthFlow) {
    return RouteNames.login;
  }

  return null;
}

/// The forced first-login location for [user], or `null` once they've cleared
/// the gate. Pure + ordered so the sequence is unit-tested independently of the
/// GoRouter/page machinery:
///   1. `mustChangePassword` → Force Password Change.
///   2. `!isProfileCompleted` → Profile Completion.
///   3. EMPLOYEES with `!hasCompletedOnboarding` → the one-time Welcome. Seeded
///      `false` at profile completion; the flag persists, so a returning
///      employee (flag `true`) and every non-employee fall straight through.
String? firstLoginLocation(UserEntity user) {
  if (user.mustChangePassword) return RouteNames.forcePasswordChange;
  if (!user.isProfileCompleted) return RouteNames.profileCompletion;
  if (user.role.isEmployee && !user.hasCompletedOnboarding) {
    return RouteNames.welcome;
  }
  return null;
}

/// A role home. On iOS it is a [CupertinoPage] so that a screen pushed on top
/// of it gets the native parallax — the home slides out under the incoming
/// page and tracks the finger back during the edge-swipe. Everywhere else it
/// keeps the calm fade it has always had.
Page<void> _homePage(GoRouterState state, Widget child) {
  if (isGestureBackPlatform(defaultTargetPlatform)) {
    return CupertinoPage<void>(
      key: state.pageKey,
      name: state.uri.toString(),
      child: child,
    );
  }
  return _fadeTransition(state, child);
}

CustomTransitionPage<void> _fadeTransition(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      // Real path in the page's RouteSettings so navigation logs name routes.
      name: state.uri.toString(),
      child: child,
      transitionDuration: const Duration(milliseconds: 180),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
    );

/// Every pushed route in the app.
///
/// On **iOS** this is a [CupertinoPage], which is what makes the interactive
/// left-edge swipe-back exist at all — it is the only way back there, because
/// the app bar draws no chevron (see `core/routes/app_page_route.dart`).
/// On Android and desktop it stays the existing [CustomTransitionPage], so the
/// Material back button, the system back gesture and the desktop fade are
/// unchanged.
///
/// The branch is on the **platform**, never on window width: the `Page`
/// subtype is part of the route's identity, so flipping it while the app is
/// running (an iPad resized into Split View) would tear the route down and
/// rebuild it mid-gesture.
Page<void> _pushPage(GoRouterState state, Widget child) {
  if (isGestureBackPlatform(defaultTargetPlatform)) {
    return CupertinoPage<void>(
      key: state.pageKey,
      name: state.uri.toString(),
      child: child,
    );
  }
  return _slideTransition(state, child);
}

CustomTransitionPage<void> _slideTransition(
  GoRouterState state,
  Widget child,
) => CustomTransitionPage<void>(
  key: state.pageKey,
  // Real path in the page's RouteSettings so navigation logs name routes.
  name: state.uri.toString(),
  // Desktop reads the fade band (≈160ms of the 320ms window); mobile uses
  // the full window for the slide.
  transitionDuration: const Duration(milliseconds: 320),
  child: child,
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    // Desktop / macOS: no mobile slide — a calm, quick fade so sidebar
    // navigation feels native, not like pushing phone screens.
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
    if (isDesktop) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
        ),
        child: child,
      );
    }
    final slide = Tween<Offset>(
      begin: const Offset(1.0, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
    return SlideTransition(
      position: slide,
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.6),
        ),
        child: child,
      ),
    );
  },
);

/// Which branch a sales screen opens on.
///
/// Only an **admin** is global, so only an admin may steer the screen with
/// `?branchId=` (that is how the admin overview drills into a branch). A manager
/// is pinned to their own branch no matter what a link asks for — Firestore
/// rules would deny the read anyway, but a UI that tries and fails reads as a
/// bug rather than as a boundary.
String _salesBranchId(AuthCubit authCubit, GoRouterState state) {
  final user = authCubit.state.maybeWhen(
    authenticated: (user) => user,
    orElse: () => null,
  );
  final own = user?.branchId ?? '';
  if (user != null && user.role.isAdmin) {
    final requested = state.uri.queryParameters['branchId'];
    if (requested != null && requested.isNotEmpty) return requested;
  }
  return own;
}

/// True when [loc] is anywhere inside the admin area (`/admin` or `/admin/...`).
bool _isAdminArea(String loc) =>
    loc == RouteNames.adminDashboard ||
    loc.startsWith('${RouteNames.adminDashboard}/');

/// True when [loc] is anywhere inside the manager area (`/manager` or
/// `/manager/...`), plus the manager/admin branch-sales surfaces.
///
/// Public so the sales-path classification is unit-tested — a prefix match here
/// silently locked employees out of their own screens.
///
/// ⚠️ The sales dashboard is matched EXACTLY (`/sales`), never by a `/sales/`
/// prefix. `/sales/submit` and `/sales/mine` are employee-owned and
/// `/sales/history` + `/sales/submission/:id` are role-shared; a prefix match
/// made all four manager-only and silently bounced every employee back to Home
/// — including the sales notification deep link.
bool isManagerArea(String loc) =>
    loc == RouteNames.managerHome ||
    loc.startsWith('${RouteNames.managerHome}/') ||
    loc == RouteNames.salesManage ||
    loc == RouteNames.salesHistory;

/// True when [loc] is anywhere inside the Communications Center
/// (`/communications` or `/communications/...`) — admin + manager only.
bool _isCommunicationsArea(String loc) =>
    loc == RouteNames.communications ||
    loc.startsWith('${RouteNames.communications}/');

/// Normalises whatever rode in `extra` for the review ledger. A typed
/// [AttendanceReviewLink] carries branch + period; a bare String stays valid as
/// a name-only filter so an older or hand-built link still works. Anything else
/// (including a null extra on a plain sidebar visit) yields no pre-filter.
AttendanceReviewLink? _attendanceReviewLink(Object? extra) => switch (extra) {
  final AttendanceReviewLink link => link,
  final String name when name.trim().isNotEmpty => AttendanceReviewLink(
    employeeName: name,
  ),
  _ => null,
};

/// True when [loc] is the manager/admin attendance **review** ledger
/// (`/attendance/review` or a sub-path) — admin + manager only. The employee's
/// own history (`/attendance/history`) and a record detail
/// (`/attendance/record/:id`) are deliberately NOT here: they're role-shared and
/// gated by `firestore.rules`.
bool _isAttendanceReviewArea(String loc) =>
    loc == RouteNames.attendanceReview ||
    loc.startsWith('${RouteNames.attendanceReview}/');

/// True when [loc] is inside the Attendance & Reports reporting hub area.
/// Employees are excluded here; manager/admin scope is enforced by the ledger
/// rules and by explicit branch selection in the screen.
bool _isAttendanceReportsArea(String loc) =>
    loc == RouteNames.attendanceReports ||
    loc.startsWith('${RouteNames.attendanceReports}/') ||
    // Daily review settles other people's shifts, so it is a manager/admin
    // surface for the same reason the branch review ledger is.
    loc.startsWith('/attendance/daily/');

class _AuthStateNotifier extends ChangeNotifier {
  _AuthStateNotifier(AuthCubit cubit) {
    cubit.stream.listen((_) => notifyListeners());
  }
}
