import 'package:opshub/core/enums/audit_entity_type.dart';
import 'package:opshub/core/enums/audit_event_type.dart';
import 'package:opshub/core/utils/app_logger.dart';
import 'package:opshub/features/audit/domain/entities/audit_actor.dart';
import 'package:opshub/features/audit/domain/entities/audit_log_entry.dart';
import 'package:opshub/features/audit/domain/repositories/audit_repository.dart';

/// The **one seam** through which every feature records an audit event. A
/// business action calls [trackEvent] and nothing else — the service owns the
/// timestamp (server-stamped downstream), the schema version, actor capture,
/// validation, and the repository write. No feature ever touches Firestore or the
/// [AuditRepository] directly.
///
/// ## Best-effort by contract
/// Tracking is **observability, never business logic**: a failed or invalid audit
/// write must never break, block, or slow the action that triggered it. So every
/// public method is fire-and-forget-safe — it **never throws** and never returns
/// an error to the caller. Producers may `await` it (it completes fast) or drop
/// the future; either way the business path is unaffected. Invalid input is
/// dropped with a 🟠 warning; a repository failure is swallowed with a 🔴 log.
///
/// ## Adding an event type
/// Add one value to [AuditEventType], then call `trackEvent(type: …)` at the
/// business site. Nothing else in this class, the model, the datasource, or the
/// rules changes. See `docs/design/AUDIT_LOG.md`.
class EventTrackingService {
  EventTrackingService(this._repository);

  final AuditRepository _repository;

  static const String _scope = 'EventTracking';

  /// Records [type], performed by [actor], on the entity identified by
  /// [entityId]. [entityType] defaults to the event's `defaultEntityType`;
  /// [branchId] defaults to the actor's branch. [metadata] is the event-specific
  /// payload (kept small — an audit record is a fact, not a document snapshot).
  ///
  /// Returns normally in all cases (see the best-effort contract above).
  Future<void> trackEvent({
    required AuditEventType type,
    required AuditActor actor,
    required String entityId,
    AuditEntityType? entityType,
    String? branchId,
    Map<String, dynamic> metadata = const <String, dynamic>{},
    int schemaVersion = kAuditSchemaVersion,
  }) async {
    // ── Validation (drop, don't throw) ──────────────────────────
    // An unattributed user-action or a target-less event is a producer bug, not a
    // runtime error — record nothing rather than persisting a meaningless entry
    // (which the security rules would reject anyway: actorId must equal the
    // caller's uid). System events (empty actor id via [AuditActor.system]) are
    // allowed through deliberately.
    if (entityId.isEmpty) {
      AppLog.warning(_scope, 'Dropped ${type.value}: empty entityId');
      return;
    }
    if (schemaVersion < 1) {
      AppLog.warning(_scope, 'Dropped ${type.value}: invalid schemaVersion');
      return;
    }

    final entry = AuditLogEntry.record(
      eventType: type,
      actor: actor,
      entityId: entityId,
      entityType: entityType,
      branchId: branchId,
      metadata: _sanitize(metadata),
      schemaVersion: schemaVersion,
    );

    try {
      await _repository.record(entry);
    } catch (e, st) {
      // Never surface an audit failure to the business flow.
      AppLog.error(_scope, 'record ${type.value} failed', e, st);
    }
  }

  /// Admin soft-delete of a single audit record — retained, just hidden. Never a
  /// hard delete. Best-effort like [trackEvent]; returns normally on failure.
  Future<void> softDelete(String id, {required AuditActor actor}) async {
    if (id.isEmpty) return;
    try {
      await _repository.softDelete(id, deletedBy: actor.id);
    } catch (e, st) {
      AppLog.error(_scope, 'softDelete failed', e, st);
    }
  }

  /// Strips null values so the persisted metadata stays tight, and drops any
  /// non-serializable value defensively (a producer should only pass primitives /
  /// DateTime / nested maps+lists of the same; anything else is skipped rather
  /// than blowing up the write).
  Map<String, dynamic> _sanitize(Map<String, dynamic> raw) {
    if (raw.isEmpty) return const <String, dynamic>{};
    final out = <String, dynamic>{};
    raw.forEach((key, value) {
      if (value == null) return;
      if (_isSerializable(value)) out[key] = value;
    });
    return out;
  }

  bool _isSerializable(Object value) {
    if (value is num || value is String || value is bool || value is DateTime) {
      return true;
    }
    if (value is Map) {
      return value.values.every((v) => v == null || _isSerializable(v));
    }
    if (value is Iterable) {
      return value.every((v) => v == null || _isSerializable(v));
    }
    return false;
  }
}
