import 'package:opshub/core/enums/audit_entity_type.dart';
import 'package:opshub/core/enums/audit_event_type.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/features/audit/domain/entities/audit_actor.dart';

/// The current audit **schema version**. Bump this only when the *meaning* of the
/// record's shape changes (e.g. a metadata key is renamed or a field's semantics
/// shift). Old records keep their stored version, so readers can branch on it and
/// **multiple versions coexist forever** — an audit log is never migrated in
/// place (that would rewrite history).
const int kAuditSchemaVersion = 1;

/// One immutable entry in the DROP audit trail. Answers, for a single business
/// action: **WHO** ([actorId] / [actorName] / [actorRole]) did **WHAT**
/// ([eventType]) to **WHICH ENTITY** ([entityType] / [entityId]) **WHEN**
/// ([timestamp]) and **FROM WHERE** ([branchId] + [metadata]).
///
/// **Immutable & append-only.** An entry is written once and never edited. The
/// only permitted mutation is an admin **soft delete** ([isDeleted] / [deletedAt]
/// / [deletedBy]) — the record is retained, just hidden from normal reads. There
/// is no hard-delete path anywhere in the stack.
///
/// **Plain immutable class (not freezed) by design** — the same deliberate choice
/// made for `EventEntity` / `BroadcastScheduleEntity`: a serialization-heavy value
/// object reads cleaner without generated-file churn, while still honouring the
/// domain contract (pure Dart, no Flutter/Firebase imports). Serialization lives
/// in `AuditLogModel`; construction is centralised in `EventTrackingService`.
class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.eventType,
    required this.entityType,
    required this.entityId,
    required this.actorId,
    this.actorName,
    this.actorRole = UserRole.employee,
    this.branchId,
    this.timestamp,
    this.metadata = const <String, dynamic>{},
    this.schemaVersion = kAuditSchemaVersion,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
  });

  /// Firestore document id. Empty for an entry not yet persisted (the datasource
  /// assigns it on write).
  final String id;

  final AuditEventType eventType;
  final AuditEntityType entityType;

  /// The affected document's id (a task id, request id, …) or the acting uid for
  /// a document-less [AuditEntityType.session] event.
  final String entityId;

  // ── WHO (denormalized at event time) ──
  final String actorId;
  final String? actorName;
  final UserRole actorRole;

  /// The branch the action belongs to — the primary scoping axis for reads
  /// (`AuditRepository.forBranch`) and the manager read rule.
  final String? branchId;

  /// **WHEN** — server-stamped on write, so it reflects a trusted clock. Null
  /// only for an entry that hasn't been persisted yet.
  final DateTime? timestamp;

  /// Event-specific detail — the one generic, extensible payload (a Task Assigned
  /// carries `{assignedTo, priority, shift}`, a Photo Upload carries
  /// `{storagePath, mimeType, fileSize}`, …). One record shape serves every event
  /// type; this map is where the differences live.
  final Map<String, dynamic> metadata;

  /// Schema version of THIS record (see [kAuditSchemaVersion]).
  final int schemaVersion;

  // ── Soft delete (admin only; never a hard delete) ──
  final bool isDeleted;
  final DateTime? deletedAt;
  final String? deletedBy;

  /// Whether a real user (not [AuditActor.system]) performed the action.
  bool get isAttributed => actorId.isNotEmpty;

  /// Builds an entry for [eventType] performed by [actor]. Central factory used by
  /// `EventTrackingService` — [timestamp] stays null so the datasource can stamp
  /// the trusted server time; [entityType] falls back to the event's default.
  factory AuditLogEntry.record({
    required AuditEventType eventType,
    required AuditActor actor,
    required String entityId,
    AuditEntityType? entityType,
    String? branchId,
    Map<String, dynamic> metadata = const <String, dynamic>{},
    int schemaVersion = kAuditSchemaVersion,
  }) =>
      AuditLogEntry(
        id: '',
        eventType: eventType,
        entityType: entityType ?? eventType.defaultEntityType,
        entityId: entityId,
        actorId: actor.id,
        actorName: actor.name,
        actorRole: actor.role,
        branchId: branchId ?? actor.branchId,
        metadata: metadata,
        schemaVersion: schemaVersion,
      );

  AuditLogEntry copyWith({
    String? id,
    DateTime? timestamp,
    bool? isDeleted,
    DateTime? deletedAt,
    String? deletedBy,
  }) =>
      AuditLogEntry(
        id: id ?? this.id,
        eventType: eventType,
        entityType: entityType,
        entityId: entityId,
        actorId: actorId,
        actorName: actorName,
        actorRole: actorRole,
        branchId: branchId,
        timestamp: timestamp ?? this.timestamp,
        metadata: metadata,
        schemaVersion: schemaVersion,
        isDeleted: isDeleted ?? this.isDeleted,
        deletedAt: deletedAt ?? this.deletedAt,
        deletedBy: deletedBy ?? this.deletedBy,
      );
}
