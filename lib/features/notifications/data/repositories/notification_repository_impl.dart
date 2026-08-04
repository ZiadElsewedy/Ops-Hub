import 'package:drop/core/errors/exceptions.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/core/network/network_guard.dart';
import 'package:drop/features/notifications/data/datasources/notification_remote_datasource.dart';
import 'package:drop/features/notifications/data/models/notification_model.dart';
import 'package:drop/features/notifications/domain/entities/notification_entity.dart';
import 'package:drop/features/notifications/domain/repositories/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationRemoteDataSource _remote;

  NotificationRepositoryImpl(this._remote);

  @override
  Future<void> create(NotificationEntity notification) async {
    NetworkGuard.ensureWritable();
    try {
      await _remote.create(NotificationModel.fromEntity(notification));
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> createMany(List<NotificationEntity> notifications) async {
    NetworkGuard.ensureWritable();
    try {
      await _remote.createMany(
          notifications.map(NotificationModel.fromEntity).toList());
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Stream<List<NotificationEntity>> watch(String uid, {int limit = 30}) =>
      _remote.watch(uid, limit: limit).map((models) {
        // Server already orders newest-first; the defensive client sort keeps the
        // order correct when the offline cache serves an unordered partial.
        final list = models.map((m) => m.toEntity()).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });

  @override
  Future<void> markRead(String id) async {
    try {
      await _remote.markRead(id);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> markAllRead(String uid) async {
    try {
      await _remote.markAllRead(uid);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> delete(String id) async {
    NetworkGuard.ensureWritable();
    try {
      await _remote.delete(id);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> setArchived(String id, bool archived) async {
    NetworkGuard.ensureWritable();
    try {
      await _remote.setArchived(id, archived);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> setPinned(String id, bool pinned) async {
    NetworkGuard.ensureWritable();
    try {
      await _remote.setPinned(id, pinned);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }
}
