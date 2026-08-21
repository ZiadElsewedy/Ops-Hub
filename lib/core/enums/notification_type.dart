/// The operational push-notification events OpsHub sends.
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
  attendanceAutoClosed, // → the employee (session auto-closed → needs a fix)
  // ── Branch monthly sales target (server-side `writeSalesNotifications`) ──
  // ONE type for the whole sales workflow — target changed / achieved, a
  // submission filed, corrected, or decided — because that helper is the single
  // producer and it stamps exactly this string. Without the value here every
  // sales notification fell through `fromString` to the `taskAssigned` default
  // and arrived in the inbox wearing a task glyph, filed under the **Tasks**
  // pill, ranked HIGH above real work. Produced by the Admin SDK (recipients
  // come from a branch/role lookup), so it is deliberately NOT in the client
  // `sendNotification` whitelist.
  salesSubmission,

  /// **A `type` string this build does not recognise.** Not a producer — no
  /// server or client ever writes `"unknown"`; it is what
  /// [NotificationModel.fromMap] resolves an unrecognised value to.
  ///
  /// It exists because the previous fallback was [taskAssigned], and that is not
  /// a neutral default — it is a *lie with consequences*. `type` drives the
  /// glyph, the category pill and the priority ordering, so an unrecognised
  /// notification arrived wearing a clipboard, filed under **Tasks**, ranked
  /// `high` above genuinely overdue work. That is not hypothetical: it is
  /// exactly what happened to every branch-sales notification until
  /// `salesSubmission` was added on 2026-08-06, and adding that value fixed the
  /// symptom while leaving the mechanism intact for the next new type.
  ///
  /// A deploy order of "functions first, then the client build" (which is the
  /// CORRECT order — see the 2026-08-02 deploy note) guarantees a window where
  /// the server writes types this build has never heard of. Landing them as
  /// `unknown` makes that window honest: the row still renders, still says what
  /// it says, and still deep-links (routing keys off `payload.route`, never
  /// `type`) — it simply stops impersonating a task.
  ///
  /// Ranked [NotificationPriority.low] and shown only under **All**.
  unknown;

  String get value => name;

  /// The enum value for [raw], or `null` when this build does not know it.
  ///
  /// Deliberately still returns `null` rather than [unknown]: "I do not
  /// recognise this" is the honest answer, and it is the *caller* that decides
  /// what to do about it. `NotificationModel.fromMap` maps it to [unknown]; a
  /// producer validating its own output wants the null.
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
