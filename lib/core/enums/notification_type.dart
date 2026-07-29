/// The operational push-notification events DROP sends.
/// These are the agreed `type` values for the FCM **data** payload and the
/// `notifications/{id}.type` field — the contract shared by the client triggers
/// (`NotifyTaskEvent`), the `sendBroadcast` / `runTaskReminders` Cloud Functions,
/// and the in-app inbox.
///
/// **Every value here has a live producer.** Earlier revisions carried ~16
/// "reserved" schedule / swap / admin types that nothing ever wrote; they were
/// trimmed (2026-06-23 stabilization pass) to keep the surface honest. When a
/// later phase wires a real producer (a client trigger or a Cloud Function),
/// add the value back here **and** mirror it in the producer — not before.
///
/// Inbox grouping is by name prefix (`task*` → Tasks, `broadcast*` → Broadcasts),
/// so a new type should keep that naming convention.
enum NotificationType {
  // ── Task lifecycle (client `NotifyTaskEvent` via TaskCubit) ──
  taskAssigned,
  taskRework,
  taskSubmitted,
  taskApproved,
  taskRejected,
  /// A manager/admin cancelled the task — **targeted at the assignee(s)**, never
  /// branch-wide (Automated Tasks spec §9.2). Someone expected to do that work
  /// and must be told it is void. A shift-broadcast cancel with no named
  /// assignee goes to the rostered crew instead; nobody rostered means no
  /// recipients, which is valid and must never break the send.
  taskCancelled,
  /// An employee flagged a task as wrong — routed to their branch's managers,
  /// who decide (spec §5.2). This is the release valve that makes manager-only
  /// cancellation workable, so it is deliberately a *client* notification: the
  /// employee is the sender.
  taskReportedIncorrect,
  // ── Task reminders (`runTaskReminders` Cloud Function) ──
  taskReminder,
  taskOverdue,
  /// A generated shift task hit its deadline unfinished and was auto-closed as
  /// Missed — routed to the branch's manager(s) (spec §9.1). Produced
  /// SERVER-SIDE by `autoEndRecurringShiftTasks` (the sweep is the only writer,
  /// and manager routing needs a role lookup), so it is deliberately NOT in the
  /// client `sendNotification` whitelist. Without it an automatic failure is
  /// silent, which is the gap this closes.
  taskMissed,
  // ── Broadcast events (`sendBroadcast` / `dispatchBroadcast` Cloud Function) ──
  broadcastAnnouncement,
  broadcastReminder,
  broadcastEmergency,
  // ── Shift-swap workflow (client `NotifySwapEvent` via ShiftSwapCubit) ──
  swapRequested, // → the target coworker
  swapAccepted, // → the branch manager/admin (needs review)
  swapApproved, // → both employees (schedule exchanged)
  swapRejected, // → both employees (declined)
  // ── Case Management (server-side `onCaseCreated` / `onCaseUpdated` /
  //    `onCaseMessageCreated`) ──
  // Produced SERVER-SIDE via the Admin SDK (a manager can't read a confidential
  // reporter's identity to notify them client-side), so these are deliberately
  // NOT in the client `sendNotification` whitelist.
  caseOpened, // → the routed recipients (branch manager / admin)
  caseUpdated, // → the reporter (status moved: in discussion / waiting response)
  caseClosed, // → the reporter (closed)
  caseReplied, // → the other party (a new reply in the conversation)
  // ── Operations Requests (server-side `onRequestCreated` / `onRequestUpdated`
  //    / `onRequestEventCreated`) ──
  // Produced SERVER-SIDE via the Admin SDK (routing depends on branch/role/policy
  // lookups), so these are deliberately NOT in the client `sendNotification`
  // whitelist.
  requestSubmitted, // → the routed approvers (branch manager / admin)
  requestApproved, // → the requester
  requestRejected, // → the requester
  requestCompleted, // → the requester
  requestCancelled, // → the routed approvers (requester withdrew it)
  requestCommented, // → the other party (a new comment on the request)
  // ── Attendance (server-side `onAttendanceCorrectionWritten` /
  //    `autoCloseAttendance`) ──
  // Produced SERVER-SIDE via the Admin SDK (routing depends on branch/role
  // lookups; the audit trail is server-authored), so these are deliberately NOT
  // in the client `sendNotification` whitelist.
  attendanceCorrectionFiled, // → the routed reviewers (branch manager / admin)
  attendanceCorrectionApproved, // → the employee (record corrected)
  attendanceCorrectionRejected, // → the employee (correction declined)
  attendanceAutoClosed; // → the employee (session auto-closed → needs a fix)

  String get value => name;

  static NotificationType? fromString(String? raw) {
    for (final t in NotificationType.values) {
      if (t.name == raw) return t;
    }
    return null;
  }

  /// Maps a broadcast [BroadcastCategory] string (announcement / alert /
  /// reminder / emergency) to its notification type. Unknown / missing →
  /// [broadcastAnnouncement] (the neutral default). Mirrored by the
  /// `sendBroadcast` Cloud Function's `categoryToType`.
  static NotificationType fromBroadcastCategory(String? category) {
    switch (category) {
      case 'reminder':
        return broadcastReminder;
      case 'emergency':
        return broadcastEmergency;
      case 'announcement':
      default:
        return broadcastAnnouncement;
    }
  }
}
