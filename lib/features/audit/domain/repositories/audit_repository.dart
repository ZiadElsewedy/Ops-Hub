import 'package:opshub/core/enums/audit_entity_type.dart';
import 'package:opshub/features/audit/domain/entities/audit_log_entry.dart';

/// The persistence contract for the immutable audit trail. Writes are a single
/// lightweight [record]; reads are **always bounded** (`limit`) and support
/// keyset pagination via a `before` timestamp cursor, so a history of tens of
/// thousands of records never loads at once.
///
/// **Soft-deleted records are excluded by default** from every read — pass
/// `includeDeleted: true` to include them (an admin audit-of-the-audit view).
///
/// Only [EventTrackingService] should call [record]; features never write to the
/// audit collection directly.
abstract class AuditRepository {
  /// Appends one immutable entry. The datasource assigns the id and stamps the
  /// trusted server timestamp.
  Future<void> record(AuditLogEntry entry);

  /// The most recent [limit] events, newest first. [before] pages older
  /// (`timestamp < before`).
  Future<List<AuditLogEntry>> recent({
    int limit = 50,
    DateTime? before,
    bool includeDeleted = false,
  });

  /// Realtime feed of the most recent [limit] events (newest first).
  Stream<List<AuditLogEntry>> watchRecent({int limit = 50});

  /// Everything that happened to one entity (a task, a request, …), newest first.
  Future<List<AuditLogEntry>> forEntity(
    AuditEntityType entityType,
    String entityId, {
    int limit = 50,
    DateTime? before,
    bool includeDeleted = false,
  });

  /// Everything a given user did, newest first.
  Future<List<AuditLogEntry>> forActor(
    String actorId, {
    int limit = 50,
    DateTime? before,
    bool includeDeleted = false,
  });

  /// Everything that happened in one branch, newest first.
  Future<List<AuditLogEntry>> forBranch(
    String branchId, {
    int limit = 50,
    DateTime? before,
    bool includeDeleted = false,
  });

  /// Events within an inclusive [from, to] window, newest first.
  Future<List<AuditLogEntry>> inDateRange(
    DateTime from,
    DateTime to, {
    int limit = 100,
    bool includeDeleted = false,
  });

  /// Soft-deletes one record — stamps [AuditLogEntry.isDeleted] /
  /// `deletedAt` / `deletedBy`. Never a hard Firestore delete. Admin-only
  /// (enforced by the security rules).
  Future<void> softDelete(String id, {required String deletedBy});
}
