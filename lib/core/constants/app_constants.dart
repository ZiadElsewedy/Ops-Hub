class AppConstants {
  AppConstants._();

  static const String appName = 'DROP';
  static const String usersCollection = 'users';
  static const String tasksCollection = 'tasks';
  static const String taskTemplatesCollection = 'task_templates';
  static const String recurringTaskTemplatesCollection =
      'recurringTaskTemplates';

  /// Automation execution history (Automated Task Engine observability, ADR-011).
  /// One document per (template, day) at a deterministic id `{templateId}_{dateKey}`
  /// → idempotent history. Written ONLY by the `generateShiftTaskInstances` Cloud
  /// Function (server-authoritative); the client reads it for the run timeline.
  static const String automationRunsCollection = 'automationRuns';
  static const String branchesCollection = 'branches';
  static const String weeklySchedulesCollection = 'weekly_schedules';
  static const String shiftTemplatesCollection = 'shift_templates';
  static const String shiftSwapsCollection = 'shift_swaps';
  static const String broadcastsCollection = 'broadcasts';
  static const String notificationsCollection = 'notifications';

  /// Case Management (private conversation until resolution). The reporter's
  /// identity lives in the private subcollection `cases/{id}/reporter/identity`;
  /// the conversation lives in `cases/{id}/messages`.
  static const String casesCollection = 'cases';

  /// Operations Requests (in-the-moment approvals during the work day). The
  /// event-driven timeline lives in the subcollection `requests/{id}/events`; a
  /// monotonic reference sequence lives at `counters/requests`.
  static const String requestsCollection = 'requests';
  static const String countersCollection = 'counters';

  /// Attendance records (clock in/out). One document per (user, day, shift) at a
  /// deterministic id `{uid}_{yyyyMMdd}_{shift}` (see `attendanceDocId`); the
  /// append-only audit trail lives in `attendance/{id}/events`, and an optional
  /// clock-in selfie in Storage at `attendance/{id}/selfie/{id}.<ext>`.
  static const String attendanceCollection = 'attendance';

  /// Server-materialized attendance reporting ledger. One row per expected
  /// `(user, business day, shift)` slot at the same deterministic id as the raw
  /// attendance record. Read-only to clients; written by
  /// `closeAttendanceExpectations`.
  static const String attendanceExpectationsCollection =
      'attendance_expectations';

  /// Attendance **correction requests** — an employee disputes/fixes a settled
  /// record (a missing clock-out, a wrong time, an absent flagged in error). A
  /// first-class approval object at `attendance_corrections/{id}` with a
  /// `Pending → Approved / Rejected` lifecycle (reuses `RequestStatus`); the
  /// approved resolution is applied to the parent `attendance/{id}` record — and
  /// the audit event written — **server-side** by `onAttendanceCorrectionWritten`.
  static const String attendanceCorrectionsCollection =
      'attendance_corrections';

  /// A manager's statement that they reviewed a branch-week ([ADR-019]) —
  /// `attendance_week_reviews/{branchId}_{weekStartKey}`.
  ///
  /// **An assertion, not a lock.** Nothing is restricted by a review existing;
  /// changes made afterwards are surfaced by comparing timestamps, never
  /// rejected. Deliberately carries no `locked` field.
  static const String attendanceWeekReviewsCollection =
      'attendance_week_reviews';

  /// Immutable Event Tracking + Audit Log. One append-only document per important
  /// business action (`audit_logs/{id}`) — who did what, to which entity, when,
  /// from where. Never edited; never hard-deleted (admin soft-delete only). All
  /// writes flow through the central `EventTrackingService`.
  static const String auditLogsCollection = 'audit_logs';

  // ─── Communications Center — Phase 2 ──────────────────────────
  static const String broadcastTemplatesCollection = 'broadcastTemplates';
  static const String broadcastSchedulesCollection = 'broadcastSchedules';
  static const String reminderConfigCollection = 'reminderConfig';
  static const String taskRemindersCollection = 'taskReminders';
}
