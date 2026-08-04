import 'package:drop/core/errors/exceptions.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/core/network/network_guard.dart';
import 'package:drop/features/schedule/data/datasources/shift_template_remote_datasource.dart';
import 'package:drop/features/schedule/data/models/shift_template_model.dart';
import 'package:drop/features/schedule/domain/repositories/shift_template_repository.dart';
import 'package:drop/features/schedule/domain/shift_template.dart';

class ShiftTemplateRepositoryImpl implements ShiftTemplateRepository {
  final ShiftTemplateRemoteDataSource _remote;

  ShiftTemplateRepositoryImpl(this._remote);

  @override
  Stream<List<ShiftTemplate>> watchTemplates(String branchId) => _remote
      .watchTemplates(branchId)
      .map((models) => [for (final m in models) m.toEntity()])
      .handleError((Object e) => throw ServerFailure(
          e is Failure ? e.message : 'Failed to load shift templates.'));

  @override
  Future<List<ShiftTemplate>> getTemplates(String branchId) async {
    try {
      final models = await _remote.getTemplates(branchId);
      return [for (final m in models) m.toEntity()];
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<ShiftTemplateSet> getSet(String branchId) async =>
      ShiftTemplateSet(await getTemplates(branchId));

  @override
  Future<void> upsertTemplate(ShiftTemplate template) async {
    try {
      await _remote.upsertTemplate(ShiftTemplateModel.fromEntity(template));
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> deleteTemplate(String id) async {
    NetworkGuard.ensureWritable();
    try {
      await _remote.deleteTemplate(id);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<ShiftTemplateSet> ensureDefaults(String branchId) async {
    try {
      final models = await _remote.ensureDefaults(branchId);
      return ShiftTemplateSet([for (final m in models) m.toEntity()]);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }
}
