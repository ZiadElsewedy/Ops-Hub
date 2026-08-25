import 'package:opshub/core/errors/exceptions.dart';
import 'package:opshub/core/errors/failures.dart';
import 'package:opshub/core/network/network_guard.dart';
import 'package:opshub/features/communications/data/datasources/broadcast_remote_datasource.dart';
import 'package:opshub/features/communications/data/models/broadcast_model.dart';
import 'package:opshub/features/communications/domain/entities/broadcast_entity.dart';
import 'package:opshub/features/communications/domain/repositories/broadcast_repository.dart';

class BroadcastRepositoryImpl implements BroadcastRepository {
  final BroadcastRemoteDataSource _remote;

  BroadcastRepositoryImpl(this._remote);

  @override
  Future<BroadcastEntity> sendBroadcast(
    BroadcastEntity broadcast, {
    List<String> targetUserIds = const [],
    String roleFilter = '',
  }) async {
    NetworkGuard.ensureWritable();
    try {
      final created = await _remote.sendBroadcast(
        BroadcastModel.fromEntity(broadcast),
        targetUserIds: targetUserIds,
        roleFilter: roleFilter,
      );
      return created.toEntity();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Stream<List<BroadcastEntity>> watchBroadcasts({String? branchId}) =>
      _remote
          .watchBroadcasts(branchId: branchId)
          .map((models) => models.map((m) => m.toEntity()).toList());

  @override
  Future<BroadcastEntity?> getBroadcast(String id) async {
    final model = await _remote.getBroadcast(id);
    return model?.toEntity();
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
  Future<void> delete(String id) async {
    NetworkGuard.ensureWritable();
    try {
      await _remote.delete(id);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }
}
