import 'package:drop/core/enums/user_role.dart';
import 'package:drop/core/routes/route_names.dart';

/// The canonical `route` values a notification carries in its payload — the
/// deep-link contract shared by the producers (`NotifyTaskEvent`,
/// `NotifySwapEvent`), the server functions (`dispatchBroadcast`,
/// `onCase*` / `onRequest*`), the FCM push `data` block, and the in-app inbox.
///
/// Keep these in lockstep with the strings the producers write (both Dart and
/// the `functions/index.js` mirrors).
class NotificationRoute {
  NotificationRoute._();

  static const String task = 'task_details';
  static const String broadcast = 'broadcast_detail';
  static const String schedule = 'schedule';
  static const String caseThread = 'case_details';
  static const String request = 'request_details';
  static const String salesSubmission = 'sales_submission';

  /// Direct chat messages. Written by the NestJS chat backend (the one route
  /// not produced by `functions/index.js`) with a `conversationId`.
  static const String chat = 'chat_message';

  /// Attendance corrections + auto-closed sessions. Written by
  /// `writeAttendanceNotifications` in `functions/index.js`, which always stamps
  /// a `recordId` (and a `correctionId` for correction events).
  static const String attendance = 'attendance';
}

/// The single, pure, role-aware deep-link resolver for a notification tap —
/// used by BOTH tap surfaces (the in-app inbox tile and the FCM push handler)
/// so a task/broadcast/schedule/case/request/chat opens the SAME destination
/// however it was tapped (foreground, background, cold-start, or in-app).
///
/// Returns the concrete `go_router` location to navigate to, or `null` when
/// there is no safe destination for this recipient (e.g. an employee tapping a
/// broadcast they can't open, or an unresolved/unknown route). A `null` is a
/// deliberate guarded no-op — the caller falls back safely (stay on the inbox
/// / open the inbox), so **navigation never crashes**.
///
/// [payload] is read leniently: it works for a [NotificationEntity.payload]
/// map (typed values) and for an FCM `RemoteMessage.data` map (all-strings),
/// since ids are coerced to a non-empty `String?`. When a specific target id is
/// missing but a safe list destination exists (cases / requests / chat), the
/// resolver falls back to the list rather than returning `null`, so the tap is
/// never wasted.
String? resolveNotificationRoute({
  required String? route,
  required Map<String, dynamic> payload,
  required UserRole? role,
}) {
  switch (route) {
    case NotificationRoute.task:
      final taskId = _id(payload, 'taskId');
      if (taskId != null) return RouteNames.taskDetail(taskId);
      // No id (stale/legacy) → the role's task list, if we know the role.
      return role == null ? null : RouteNames.tasksForRole(role);

    case NotificationRoute.broadcast:
      final broadcastId = _id(payload, 'broadcastId');
      // Broadcast detail lives in the Communications area — admin/manager only.
      // An employee has no destination here (guarded no-op).
      if (broadcastId != null &&
          (role == UserRole.admin || role == UserRole.manager)) {
        return RouteNames.communicationsDetail(broadcastId);
      }
      return null;

    case NotificationRoute.schedule:
      // Shift-swap notifications open the role's schedule (where the swap queue
      // is); there is no per-swap screen to deep-link into.
      return role == null ? null : RouteNames.scheduleForRole(role);

    case NotificationRoute.caseThread:
      final caseId = _id(payload, 'caseId');
      return caseId != null ? RouteNames.caseDetail(caseId) : RouteNames.cases;

    case NotificationRoute.request:
      final requestId = _id(payload, 'requestId');
      return requestId != null
          ? RouteNames.requestDetail(requestId)
          : RouteNames.requests;

    case NotificationRoute.salesSubmission:
      final submissionId = _id(payload, 'salesSubmissionId');
      if (submissionId != null) {
        return RouteNames.salesSubmissionDetail(submissionId);
      }
      return switch (role) {
        UserRole.admin || UserRole.manager => RouteNames.salesManage,
        UserRole.employee => RouteNames.salesMine,
        null => null,
      };

    case NotificationRoute.chat:
      final conversationId = _id(payload, 'conversationId');
      // Chat is available to every role, so this deliberately has no role gate.
      return conversationId != null
          ? RouteNames.chatConversation(conversationId)
          : RouteNames.chat;

    case NotificationRoute.attendance:
      // Every attendance producer stamps the record id, so a correction filed /
      // decided or an auto-closed session opens the exact record (Firestore
      // rules — not the route — decide who may read it).
      final recordId = _id(payload, 'recordId');
      if (recordId != null) return RouteNames.attendanceRecord(recordId);
      // No record id (legacy doc) → the ledger this recipient is allowed to
      // open: reviewers land on the branch review queue, an employee on their
      // own history.
      return switch (role) {
        UserRole.admin || UserRole.manager => RouteNames.attendanceReview,
        UserRole.employee => RouteNames.attendanceHistory,
        null => null,
      };

    default:
      // Unknown / missing route — no safe deep target.
      return null;
  }
}

/// Reads [key] from [payload] as a trimmed, non-empty `String`, or `null`.
/// Tolerates the two shapes a payload arrives in: typed entity values and the
/// all-strings FCM `data` map (where a missing id is often the empty string).
String? _id(Map<String, dynamic> payload, String key) {
  final raw = payload[key];
  if (raw == null) return null;
  final s = raw.toString().trim();
  return s.isEmpty ? null : s;
}
