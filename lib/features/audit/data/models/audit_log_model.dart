import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:opshub/core/enums/audit_entity_type.dart';
import 'package:opshub/core/enums/audit_event_type.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/core/extensions/firestore_extensions.dart';
import 'package:opshub/features/audit/domain/entities/audit_log_entry.dart';

/// Firestore (de)serialization for [AuditLogEntry] — collection `audit_logs/{id}`.
///
/// The document id IS the record id (not duplicated into the body). `timestamp`
/// is written as a server timestamp by the datasource, so [toCreateMap] omits it.
/// [metadata] can hold nested date/time values; Firestore returns those as
/// [Timestamp], so [_metadataFromMap] / [_metadataToMap] normalize
/// `Timestamp ⇄ DateTime` recursively at this boundary (mirrors `RequestModel`).
class AuditLogModel {
  const AuditLogModel({
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

  final String id;
  final AuditEventType eventType;
  final AuditEntityType entityType;
  final String entityId;
  final String actorId;
  final String? actorName;
  final UserRole actorRole;
  final String? branchId;
  final DateTime? timestamp;
  final Map<String, dynamic> metadata;
  final int schemaVersion;
  final bool isDeleted;
  final DateTime? deletedAt;
  final String? deletedBy;

  factory AuditLogModel.fromMap(Map<String, dynamic> map, {String? id}) =>
      AuditLogModel(
        id: id ?? map['id'] as String? ?? '',
        eventType: AuditEventType.fromString(map['eventType'] as String?),
        entityType: AuditEntityType.fromString(map['entityType'] as String?),
        entityId: map['entityId'] as String? ?? '',
        actorId: map['actorId'] as String? ?? '',
        actorName: map['actorName'] as String?,
        actorRole: UserRole.fromString(map['actorRole'] as String?),
        branchId: map['branchId'] as String?,
        timestamp: map.date('timestamp'),
        metadata: _metadataFromMap(map['metadata']),
        schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
        isDeleted: map['isDeleted'] as bool? ?? false,
        deletedAt: map.date('deletedAt'),
        deletedBy: map['deletedBy'] as String?,
      );

  factory AuditLogModel.fromEntity(AuditLogEntry e) => AuditLogModel(
        id: e.id,
        eventType: e.eventType,
        entityType: e.entityType,
        entityId: e.entityId,
        actorId: e.actorId,
        actorName: e.actorName,
        actorRole: e.actorRole,
        branchId: e.branchId,
        timestamp: e.timestamp,
        metadata: e.metadata,
        schemaVersion: e.schemaVersion,
        isDeleted: e.isDeleted,
        deletedAt: e.deletedAt,
        deletedBy: e.deletedBy,
      );

  /// The **create** payload. `timestamp` is a server timestamp added by the
  /// datasource, so it is omitted here. `isDeleted` is always written `false`
  /// (an entry is born live); the soft-delete fields are omitted until deletion.
  Map<String, dynamic> toCreateMap() => {
        'eventType': eventType.value,
        'entityType': entityType.value,
        'entityId': entityId,
        'actorId': actorId,
        'actorName': actorName,
        'actorRole': actorRole.value,
        'branchId': branchId,
        'metadata': _metadataToMap(metadata),
        'schemaVersion': schemaVersion,
        'isDeleted': false,
      };

  AuditLogEntry toEntity() => AuditLogEntry(
        id: id,
        eventType: eventType,
        entityType: entityType,
        entityId: entityId,
        actorId: actorId,
        actorName: actorName,
        actorRole: actorRole,
        branchId: branchId,
        timestamp: timestamp,
        metadata: metadata,
        schemaVersion: schemaVersion,
        isDeleted: isDeleted,
        deletedAt: deletedAt,
        deletedBy: deletedBy,
      );

  // ─── metadata normalization (Timestamp ⇄ DateTime, recursive) ─────────
  static Map<String, dynamic> _metadataFromMap(dynamic raw) {
    if (raw is! Map) return const <String, dynamic>{};
    final out = <String, dynamic>{};
    raw.forEach((k, v) => out[k.toString()] = _decode(v));
    return out;
  }

  static Map<String, dynamic> _metadataToMap(Map<String, dynamic> metadata) {
    final out = <String, dynamic>{};
    metadata.forEach((k, v) => out[k] = _encode(v));
    return out;
  }

  static dynamic _decode(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is Map) {
      return {for (final e in v.entries) e.key.toString(): _decode(e.value)};
    }
    if (v is List) return [for (final e in v) _decode(e)];
    return v;
  }

  static dynamic _encode(dynamic v) {
    if (v is DateTime) return Timestamp.fromDate(v);
    if (v is Map) {
      return {for (final e in v.entries) e.key.toString(): _encode(e.value)};
    }
    if (v is List) return [for (final e in v) _encode(e)];
    return v;
  }
}
