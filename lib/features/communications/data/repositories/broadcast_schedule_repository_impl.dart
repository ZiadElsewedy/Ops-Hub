import 'package:drop/core/errors/exceptions.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/core/network/network_guard.dart';
import 'package:drop/features/communications/data/datasources/broadcast_schedule_remote_datasource.dart';
import 'package:drop/features/communications/data/models/broadcast_schedule_model.dart';
import 'package:drop/features/communications/domain/entities/broadcast_schedule_entity.dart';
import 'package:drop/features/communications/domain/repositories/broadcast_schedule_repository.dart';

class BroadcastScheduleRepositoryImpl implements BroadcastScheduleRepository {
  final BroadcastScheduleRemoteDataSource _remote;

  BroadcastScheduleRepositoryImpl(this._remote);

  @override
  Future<List<BroadcastScheduleEntity>> getSchedules({
    required String uid,
    required bool isAdmin,
  }) async {
    try {
      final models = await _remote.getSchedules(uid: uid, isAdmin: isAdmin);
      return models.map((m) => m.toEntity()).toList();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<BroadcastScheduleEntity> create(
    BroadcastScheduleEntity schedule, {
    List<String> targetUserIds = const [],
  }) async {
    NetworkGuard.ensureWritable();
    try {
      final created = await _remote.create(
        BroadcastScheduleModel.fromEntity(schedule, targetUserIds: targetUserIds),
      );
      return created.toEntity();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> update(BroadcastScheduleEntity schedule) async {
    NetworkGuard.ensureWritable();
    try {
      await _remote.update(BroadcastScheduleModel.fromEntity(schedule));
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> setEnabled(String id, bool enabled) async {
    NetworkGuard.ensureWritable();
    try {
      await _remote.setEnabled(id, enabled);
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
}
