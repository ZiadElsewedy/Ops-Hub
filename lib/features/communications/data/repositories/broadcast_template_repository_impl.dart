import 'package:opshub/core/errors/exceptions.dart';
import 'package:opshub/core/errors/failures.dart';
import 'package:opshub/core/network/network_guard.dart';
import 'package:opshub/features/communications/data/datasources/broadcast_template_remote_datasource.dart';
import 'package:opshub/features/communications/data/models/broadcast_template_model.dart';
import 'package:opshub/features/communications/domain/entities/broadcast_template_entity.dart';
import 'package:opshub/features/communications/domain/repositories/broadcast_template_repository.dart';

class BroadcastTemplateRepositoryImpl implements BroadcastTemplateRepository {
  final BroadcastTemplateRemoteDataSource _remote;

  BroadcastTemplateRepositoryImpl(this._remote);

  // In-memory cache of the (tiny) broadcast-template collection — symmetric with
  // the task-template cache: 20-minute TTL + invalidate after every write.
  static const _templatesTtl = Duration(minutes: 20);
  List<BroadcastTemplateEntity>? _cachedTemplates;
  DateTime? _templatesFetchedAt;

  bool get _templatesFresh =>
      _cachedTemplates != null &&
      _templatesFetchedAt != null &&
      DateTime.now().difference(_templatesFetchedAt!) < _templatesTtl;

  @override
  Future<List<BroadcastTemplateEntity>> getTemplates({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _templatesFresh) return _cachedTemplates!;
    try {
      final models = await _remote.getTemplates();
      final list = models.map((m) => m.toEntity()).toList();
      _cachedTemplates = list;
      _templatesFetchedAt = DateTime.now();
      return list;
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  void _invalidateTemplates() {
    _cachedTemplates = null;
    _templatesFetchedAt = null;
  }

  @override
  Future<BroadcastTemplateEntity> create(BroadcastTemplateEntity template) async {
    NetworkGuard.ensureWritable();
    try {
      final created =
          await _remote.create(BroadcastTemplateModel.fromEntity(template));
      _invalidateTemplates();
      return created.toEntity();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> update(BroadcastTemplateEntity template) async {
    NetworkGuard.ensureWritable();
    try {
      await _remote.update(BroadcastTemplateModel.fromEntity(template));
      _invalidateTemplates();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> setFavorite(String id, bool favorite) async {
    NetworkGuard.ensureWritable();
    try {
      await _remote.setFavorite(id, favorite);
      _invalidateTemplates();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> incrementUsage(String id) async {
    try {
      await _remote.incrementUsage(id);
      _invalidateTemplates();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> delete(String id) async {
    NetworkGuard.ensureWritable();
    try {
      await _remote.delete(id);
      _invalidateTemplates();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }
}
