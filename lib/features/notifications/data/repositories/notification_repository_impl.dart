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

  /// **Deliberately unguarded** — the one exemption from the
  /// `NetworkGuard.ensureWritable()` rule in PROJECT_CONTEXT §5, now stated
  /// rather than left to look like an oversight.
  ///
  /// The guard exists because an offline write is cached, reported as success,
  /// and replayed silently later. All three happen here; none of them costs
  /// anything. `readAt` is a set-once, idempotent receipt whose only consumer is
  /// the null check behind `isUnread` — no screen renders its value, no rule
  /// keys off it, and replaying it can never conflict with another device
  /// (marking read twice is marking read). Against that, guarding it would make
  /// **opening a notification fail while offline**, on a screen the offline
  /// policy explicitly keeps readable ("gate the writes, never the app").
  ///
  /// [markAllRead] and [deleteArchived] are guarded: both are deliberate bulk
  /// actions that read pages of documents to decide what to touch, and offline
  /// those pages are served from a partial cache — so they would silently act on
  /// a subset while telling the user they had acted on everything.
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
    NetworkGuard.ensureWritable();
    try {
      await _remote.markAllRead(uid);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> deleteArchived(String uid) async {
    NetworkGuard.ensureWritable();
    try {
      await _remote.deleteArchived(uid);
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
