import 'package:opshub/core/enums/audit_entity_type.dart';
import 'package:opshub/core/errors/exceptions.dart';
import 'package:opshub/core/errors/failures.dart';
import 'package:opshub/features/audit/data/datasources/audit_remote_datasource.dart';
import 'package:opshub/features/audit/data/models/audit_log_model.dart';
import 'package:opshub/features/audit/domain/entities/audit_log_entry.dart';
import 'package:opshub/features/audit/domain/repositories/audit_repository.dart';

class AuditRepositoryImpl implements AuditRepository {
  AuditRepositoryImpl(this._remote);

  final AuditRemoteDataSource _remote;

  /// Maps models → entities and drops soft-deleted records unless the caller
  /// explicitly asks for them. Filtering client-side (rather than a
  /// `where('isDeleted', ==, false)` query) keeps the composite indexes minimal —
  /// soft-deletes are rare and every read is already `limit`-bounded.
  List<AuditLogEntry> _entities(
    List<AuditLogModel> models, {
    required bool includeDeleted,
  }) =>
      [
        for (final m in models)
          if (includeDeleted || !m.isDeleted) m.toEntity(),
      ];

  @override
  Future<void> record(AuditLogEntry entry) async {
    try {
      await _remote.record(AuditLogModel.fromEntity(entry));
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<List<AuditLogEntry>> recent({
    int limit = 50,
    DateTime? before,
    bool includeDeleted = false,
  }) async {
    try {
      final models = await _remote.recent(limit: limit, before: before);
      return _entities(models, includeDeleted: includeDeleted);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Stream<List<AuditLogEntry>> watchRecent({int limit = 50}) => _remote
      .watchRecent(limit: limit)
      .map((models) => _entities(models, includeDeleted: false));

  @override
  Future<List<AuditLogEntry>> forEntity(
    AuditEntityType entityType,
    String entityId, {
    int limit = 50,
    DateTime? before,
    bool includeDeleted = false,
  }) async {
    try {
      final models = await _remote.forEntity(
        entityType.value,
        entityId,
        limit: limit,
        before: before,
      );
      return _entities(models, includeDeleted: includeDeleted);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<List<AuditLogEntry>> forActor(
    String actorId, {
    int limit = 50,
    DateTime? before,
    bool includeDeleted = false,
  }) async {
    try {
      final models = await _remote.forActor(actorId, limit: limit, before: before);
      return _entities(models, includeDeleted: includeDeleted);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<List<AuditLogEntry>> forBranch(
    String branchId, {
    int limit = 50,
    DateTime? before,
    bool includeDeleted = false,
  }) async {
    try {
      final models =
          await _remote.forBranch(branchId, limit: limit, before: before);
      return _entities(models, includeDeleted: includeDeleted);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<List<AuditLogEntry>> inDateRange(
    DateTime from,
    DateTime to, {
    int limit = 100,
    bool includeDeleted = false,
  }) async {
    try {
      final models = await _remote.inDateRange(from, to, limit: limit);
      return _entities(models, includeDeleted: includeDeleted);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> softDelete(String id, {required String deletedBy}) async {
    try {
      await _remote.softDelete(id, deletedBy: deletedBy);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }
}
