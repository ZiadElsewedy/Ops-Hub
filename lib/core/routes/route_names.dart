import 'package:drop/core/enums/user_role.dart';

class RouteNames {
  RouteNames._();

  static const String splash = '/splash';
  static const String home = '/';
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';

  /// First-login forced password change (admin-issued temp password). The router
  /// confines a user with `mustChangePassword == true` here.
  static const String forcePasswordChange = '/force-password-change';

  /// First-login profile completion. The router confines a user with
  /// `isProfileCompleted == false` here (after any forced password change).
  static const String profileCompletion = '/complete-profile';

  /// One-time cinematic Welcome. The router confines an **employee** whose
  /// profile is complete but `hasCompletedOnboarding == false` here — shown once
  /// per account, right after profile completion, before the role home.
  static const String welcome = '/welcome';

  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';
  static const String settings = '/settings';
  static const String changePassword = '/settings/change-password';

  /// In-app notification inbox (Notification System Phase 1) — shared by every
  /// role.
  static const String notifications = '/notifications';

  // ─── Case Management (private conversation until resolution) ────
  // Shared by every role (like notifications) — the list self-scopes by role
  // (admin: all · manager: branch · employee: own) and Firestore rules enforce
  // access, so these sit outside the role-area guards.
  static const String cases = '/cases';
  static const String casesCreate = '/cases/create';

  /// The single-case deep-link pattern (`/case/:caseId`) — a case notification
  /// opens the exact case here, for every role.
  static const String caseDetailPattern = '/case/:caseId';

  /// The concrete case-detail path for [caseId].
  static String caseDetail(String caseId) => '/case/$caseId';

  // ─── Direct chat (NestJS backend) ───────────────────────────────
  // Shared by every role — access is participant-scoped server-side (Bearer
  // token; a non-participant sees "not found"), so these sit outside the
  // role-area guards. `/chat` is the inbox; the conversation pattern is its
  // stable deep-link path (thread UI lands in a later phase).
  static const String chat = '/chat';

  /// The new-conversation teammate picker. A static child of `/chat`; it is
  /// registered before the `:conversationId` pattern so it is never captured
  /// as a conversation id.
  static const String chatNew = '/chat/new';

  /// The single-conversation pattern (`/chat/:conversationId`).
  static const String chatConversationPattern = '/chat/:conversationId';

  /// The concrete conversation path for [conversationId].
  static String chatConversation(String conversationId) =>
      '/chat/$conversationId';

  // ─── Operations Requests (in-the-moment approvals) ─────────────
  // Shared by every role (like cases) — the list self-scopes by role (admin:
  // all · manager: branch · employee: own) and Firestore rules enforce access,
  // so these sit outside the role-area guards.
  static const String requests = '/requests';
  static const String requestsCreate = '/requests/create';

  /// Employee GPS clock-in/out surface (also reachable by managers who clock).
  static const String attendance = '/attendance';

  /// Admin attendance dashboard — branch-scoped roster × attendance oversight +
  /// the correction queue (a future manager view reuses the same screen).
  static const String adminAttendance = '/admin/attendance';

  /// Attendance History ledger — the employee's own history. Reachable by any
  /// authenticated role (a manager/admin who also clocks has their own here).
  static const String attendanceHistory = '/attendance/history';

  /// Manager/admin branch attendance review (the longitudinal ledger). Guarded to
  /// admin‖manager by `_isAttendanceReviewArea` (mirrors the Communications area).
  static const String attendanceReview = '/attendance/review';

  /// The single attendance-record detail pattern (`/attendance/record/:id`) —
  /// deep-linkable; access is enforced by `firestore.rules`, not the route.
  static const String attendanceRecordPattern = '/attendance/record/:id';

  /// The concrete attendance-record detail path for [id].
  static String attendanceRecord(String id) => '/attendance/record/$id';

  /// The single-request deep-link pattern (`/request/:requestId`) — a request
  /// notification opens the exact request here, for every role.
  static const String requestDetailPattern = '/request/:requestId';

  /// The concrete request-detail path for [requestId].
  static String requestDetail(String requestId) => '/request/$requestId';

  // ─── Role shells (Phase 1) ──────────────────────────────────
  // The employee role uses [home] ('/') as its landing.
  static const String adminDashboard = '/admin';
  static const String managerHome = '/manager';

  // ─── Tasks (Phase 3) ────────────────────────────────────────
  // Admin/manager task screens live under their role area so the existing
  // `_isAdminArea` / `_isManagerArea` guards cover them; the employee task
  // screen is self-scoped (shows only the caller's own tasks).
  static const String adminTasks = '/admin/tasks';
  static const String managerTasks = '/manager/tasks';
  static const String myTasks = '/my-tasks';

  /// Admin **Pending Review** drill-down (Summary → Branch → Employee → Task).
  /// Admin-only (covered by `_isAdminArea`).
  static const String adminReview = '/admin/review';

  /// The single-task deep-link pattern (`/task/:taskId`) — a task notification
  /// opens the exact task here, for every role. Outside the role-area guards: a
  /// user only reaches it via a task they were notified about, and Firestore
  /// rules enforce read access.
  static const String taskDetailPattern = '/task/:taskId';

  /// The concrete task-detail path for [taskId].
  static String taskDetail(String taskId) => '/task/$taskId';

  // ─── Weekly schedule (Phase 7) ──────────────────────────────
  // Admin/manager schedule screens live under their role area so the existing
  // `_isAdminArea` / `_isManagerArea` guards cover them; the employee schedule
  // screen is self-scoped (the caller's own branch, read-only).
  static const String adminSchedule = '/admin/schedule';
  static const String managerSchedule = '/manager/schedule';
  static const String mySchedule = '/my-schedule';

  // ─── Communications Center (Phase 3) ────────────────────────
  // A single area for admin + manager (employees are blocked by the router's
  // `_isCommunicationsArea` guard). Not under /admin or /manager because both
  // roles share it.
  static const String communications = '/communications';
  static const String communicationsCompose = '/communications/compose';
  static const String communicationsTemplates = '/communications/templates';
  static const String communicationsSchedules = '/communications/schedules';

  /// The broadcast-detail route pattern (`/communications/:broadcastId`).
  static const String communicationsDetailPattern =
      '/communications/:broadcastId';

  /// The concrete detail path for [broadcastId].
  static String communicationsDetail(String broadcastId) =>
      '/communications/$broadcastId';

  // ─── Admin module (Phase 5) ─────────────────────────────────
  // All under the admin area, so the existing `_isAdminArea` guard covers them.
  static const String adminBranches = '/admin/branches';
  static const String adminManagers = '/admin/managers';
  static const String adminEmployees = '/admin/employees';
  static const String adminAnalytics = '/admin/analytics';

  /// Admin → User Management → Create Account (admin-only provisioning form).
  static const String adminCreateAccount = '/admin/users/create';

  /// The landing route for a given role, used by the router redirect and the
  /// splash screen to dispatch each user to their own shell.
  static String homeForRole(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return adminDashboard;
      case UserRole.manager:
        return managerHome;
      case UserRole.employee:
        return home;
    }
  }

  /// The task screen for a given role (admin: all branches, manager: own branch,
  /// employee: own tasks). Used by the shared role chrome.
  static String tasksForRole(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return adminTasks;
      case UserRole.manager:
        return managerTasks;
      case UserRole.employee:
        return myTasks;
    }
  }

  /// The weekly-schedule screen for a given role (admin: any branch, manager:
  /// own branch, employee: own branch read-only). Used by the shared role chrome.
  static String scheduleForRole(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return adminSchedule;
      case UserRole.manager:
        return managerSchedule;
      case UserRole.employee:
        return mySchedule;
    }
  }
}
