import 'dart:io';

import 'package:drop/core/enums/attachment_type.dart';
import 'package:drop/core/enums/request_status.dart';
import 'package:drop/core/errors/exceptions.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/core/network/network_guard.dart';
import 'package:drop/features/requests/data/datasources/request_remote_datasource.dart';
import 'package:drop/features/requests/data/models/request_model.dart';
import 'package:drop/features/requests/domain/entities/request_entity.dart';
import 'package:drop/features/requests/domain/entities/request_event.dart';
import 'package:drop/features/requests/domain/repositories/request_repository.dart';
import 'package:drop/features/requests/domain/request_ordering.dart';
import 'package:drop/features/task/domain/entities/task_attachment.dart';

class RequestRepositoryImpl implements RequestRepository {
  final RequestRemoteDataSource _remote;

  RequestRepositoryImpl(this._remote);

  /// Maps models → entities, drops soft-deleted docs, and orders for the inbox
  /// (pending first by latest activity, then the decided archive). The deleted
  /// filter is client-side on purpose: a `where(deletedAt, isNull)` query would
  /// exclude every existing doc missing the field, and per-scope volume is small.
  List<RequestEntity> _ordered(List<RequestModel> models) =>
      sortRequestsForInbox([
        for (final m in models)
          if (m.deletedAt == null) m.toEntity(),
      ]);

  @override
  Stream<List<RequestEntity>> watchAllRequests() =>
      _remote.watchAllRequests().map(_ordered);

  @override
  Stream<List<RequestEntity>> watchBranchRequests(String branchId) =>
      _remote.watchBranchRequests(branchId).map(_ordered);

  @override
  Stream<List<RequestEntity>> watchMyRequests(String uid) =>
      _remote.watchMyRequests(uid).map(_ordered);

  @override
  Future<RequestEntity?> getRequest(String requestId) async {
    try {
      final model = await _remote.getRequest(requestId);
      return model?.toEntity();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Stream<RequestEntity?> watchRequest(String requestId) =>
      _remote.watchRequest(requestId).map((m) => m?.toEntity());

  @override
  Stream<List<RequestEvent>> watchEvents(String requestId) =>
      _remote.watchEvents(requestId);

  @override
  String newRequestId() => _remote.newRequestId();

  @override
  Future<RequestEntity> createRequest(RequestEntity request) async {
    NetworkGuard.ensureWritable();
    try {
      final created =
          await _remote.createRequest(RequestModel.fromEntity(request));
      return created.toEntity();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> changeStatus(
    String requestId,
    RequestStatus to, {
    String? decidedBy,
    String? decidedByName,
  }) async {
    try {
      await _remote.changeStatus(
        requestId,
        to,
        decidedBy: decidedBy,
        decidedByName: decidedByName,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> addEvent(String requestId, RequestEvent event) async {
    NetworkGuard.ensureWritable();
    try {
      await _remote.addEvent(requestId, event);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<TaskAttachment> uploadAttachment({
    required String requestId,
    required File file,
    required AttachmentType type,
    required String uploadedBy,
    String? uploadedByName,
    int? durationMs,
    void Function(int transferred, int total)? onProgress,
  }) async {
    try {
      return await _remote.uploadAttachment(
        requestId: requestId,
        file: file,
        type: type,
        uploadedBy: uploadedBy,
        uploadedByName: uploadedByName,
        durationMs: durationMs,
        onProgress: onProgress,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> deleteRequest(String requestId) async {
    NetworkGuard.ensureWritable();
    try {
      await _remote.deleteRequest(requestId);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }
}
