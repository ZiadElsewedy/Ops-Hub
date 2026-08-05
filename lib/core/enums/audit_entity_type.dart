/// The kind of thing an [AuditEventType] acted on — the `entityType` dimension of
/// an audit record (`audit_logs/{id}.entityType`). Stored as a string so a future
/// app version can introduce a new entity kind without breaking older clients
/// (unknown / missing → [other]).
///
/// This answers the **"to WHICH ENTITY"** question of the audit trail, and it is
/// the query axis for "everything that happened to this task / request / user"
/// (see `AuditRepository.forEntity`).
enum AuditEntityType {
  task,
  shiftSwap,
  request,
  broadcast,
  caseRecord,
  event,
  user,
  profile,
  salesMonth,
  dailySalesSubmission,

  /// A recurring-task automation (`recurringTaskTemplates/{id}`) — the
  /// [entityId] is the template id. Used by the Cloud Function's automation
  /// audit events (`automation.*`, `task.auto_generated`).
  automation,

  /// A login / logout session event — there is no single document, so [entityId]
  /// carries the acting user's uid.
  session,

  /// Forward-compatible fallback for a value written by a newer client.
  other;

  String get label => switch (this) {
        AuditEntityType.task => 'Task',
        AuditEntityType.shiftSwap => 'Shift swap',
        AuditEntityType.request => 'Request',
        AuditEntityType.broadcast => 'Broadcast',
        AuditEntityType.caseRecord => 'Case',
        AuditEntityType.event => 'Event',
        AuditEntityType.user => 'User',
        AuditEntityType.profile => 'Profile',
        AuditEntityType.salesMonth => 'Sales month',
        AuditEntityType.dailySalesSubmission => 'Daily sales submission',
        AuditEntityType.automation => 'Automation',
        AuditEntityType.session => 'Session',
        AuditEntityType.other => 'Other',
      };

  /// Parses the stored string; unknown / missing → [other] (forward-compatible).
  String get value => switch (this) {
        AuditEntityType.salesMonth => 'sales_month',
        AuditEntityType.dailySalesSubmission => 'daily_sales_submission',
        _ => name,
      };

  static AuditEntityType fromString(String? raw) {
    for (final t in AuditEntityType.values) {
      if (t.value == raw) return t;
    }
    return AuditEntityType.other;
  }
}
