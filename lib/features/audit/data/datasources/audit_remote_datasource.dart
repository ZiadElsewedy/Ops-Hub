import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:opshub/core/constants/app_constants.dart';
import 'package:opshub/core/errors/exceptions.dart';
import 'package:opshub/features/audit/data/models/audit_log_model.dart';

/// Firestore access for the immutable audit trail (`audit_logs/{id}`).
///
/// **Writes are lightweight** — a single `add` with a server timestamp; no read,
/// no transaction. **Reads are always bounded** — every query is `limit`-capped
/// and ordered by `timestamp` descending, with an optional `before` keyset cursor
/// (`timestamp <` the last row) for pagination, so a history of tens of thousands
/// of records never loads at once.
///
/// Soft-deleted records are NOT filtered in the query (that would multiply the
/// composite indexes); the repository drops them client-side. Soft-deletes are
/// rare and per-scope read volume is small + `limit`-bounded.
abstract class AuditRemoteDataSource {
  Future<void> record(AuditLogModel model);

  Stream<List<AuditLogModel>> watchRecent({int limit = 50});

  Future<List<AuditLogModel>> recent({int limit = 50, DateTime? before});

  Future<List<AuditLogModel>> forEntity(
    String entityType,
    String entityId, {
    int limit = 50,
    DateTime? before,
  });

  Future<List<AuditLogModel>> forActor(
    String actorId, {
    int limit = 50,
    DateTime? before,
  });

  Future<List<AuditLogModel>> forBranch(
    String branchId, {
    int limit = 50,
    DateTime? before,
  });

  Future<List<AuditLogModel>> inDateRange(
    DateTime from,
    DateTime to, {
    int limit = 100,
  });

  Future<void> softDelete(String id, {required String deletedBy});
}

class AuditRemoteDataSourceImpl implements AuditRemoteDataSource {
  AuditRemoteDataSourceImpl(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(AppConstants.auditLogsCollection);

  List<AuditLogModel> _map(QuerySnapshot<Map<String, dynamic>> snap) =>
      snap.docs.map((d) => AuditLogModel.fromMap(d.data(), id: d.id)).toList();

  /// Applies the shared ordering + keyset pagination + cap to a base query.
  Query<Map<String, dynamic>> _paged(
    Query<Map<String, dynamic>> base, {
    required int limit,
    DateTime? before,
  }) {
    var q = base.orderBy('timestamp', descending: true);
    if (before != null) {
      q = q.where('timestamp', isLessThan: Timestamp.fromDate(before));
    }
    return q.limit(limit);
  }

  Future<List<AuditLogModel>> _run(Query<Map<String, dynamic>> query) async {
    try {
      return _map(await query.get());
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load audit log.');
    }
  }

  @override
  Future<void> record(AuditLogModel model) async {
    try {
      // Append-only: one `add`, server-stamped time. Fire-and-forget upstream —
      // the service swallows any failure so the business write is never affected.
      await _col.add({
        ...model.toCreateMap(),
        'timestamp': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to record audit event.');
    }
  }

  @override
  Stream<List<AuditLogModel>> watchRecent({int limit = 50}) => _col
      .orderBy('timestamp', descending: true)
      .limit(limit)
      .snapshots()
      .map(_map);

  @override
  Future<List<AuditLogModel>> recent({int limit = 50, DateTime? before}) =>
      _run(_paged(_col, limit: limit, before: before));

  @override
  Future<List<AuditLogModel>> forEntity(
    String entityType,
    String entityId, {
    int limit = 50,
    DateTime? before,
  }) =>
      _run(_paged(
        _col
            .where('entityType', isEqualTo: entityType)
            .where('entityId', isEqualTo: entityId),
        limit: limit,
        before: before,
      ));

  @override
  Future<List<AuditLogModel>> forActor(
    String actorId, {
    int limit = 50,
    DateTime? before,
  }) =>
      _run(_paged(
        _col.where('actorId', isEqualTo: actorId),
        limit: limit,
        before: before,
      ));

  @override
  Future<List<AuditLogModel>> forBranch(
    String branchId, {
    int limit = 50,
    DateTime? before,
  }) =>
      _run(_paged(
        _col.where('branchId', isEqualTo: branchId),
        limit: limit,
        before: before,
      ));

  @override
  Future<List<AuditLogModel>> inDateRange(
    DateTime from,
    DateTime to, {
    int limit = 100,
  }) =>
      _run(_col
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(to))
          .orderBy('timestamp', descending: true)
          .limit(limit));

  @override
  Future<void> softDelete(String id, {required String deletedBy}) async {
    try {
      // Soft delete ONLY — flip the three delete fields and nothing else (the
      // rules enforce this exact diff). Never a hard `delete()`.
      await _col.doc(id).update({
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedBy': deletedBy,
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to delete audit record.');
    }
  }
}
