import 'dart:io';

import 'package:opshub/core/enums/attachment_type.dart';
import 'package:opshub/core/enums/case_status.dart';
import 'package:opshub/core/errors/exceptions.dart';
import 'package:opshub/core/errors/failures.dart';
import 'package:opshub/core/network/network_guard.dart';
import 'package:opshub/features/cases/data/datasources/case_remote_datasource.dart';
import 'package:opshub/features/cases/data/models/case_model.dart';
import 'package:opshub/features/cases/domain/case_ordering.dart';
import 'package:opshub/features/cases/domain/entities/case_entity.dart';
import 'package:opshub/features/cases/domain/entities/case_identity.dart';
import 'package:opshub/features/cases/domain/entities/case_message.dart';
import 'package:opshub/features/cases/domain/repositories/case_repository.dart';
import 'package:opshub/features/task/domain/entities/task_attachment.dart';

class CaseRepositoryImpl implements CaseRepository {
  final CaseRemoteDataSource _remote;

  CaseRepositoryImpl(this._remote);

  /// Maps models → entities and orders them for the inbox (active first, urgent
  /// above normal, latest activity desc, closed archived last).
  List<CaseEntity> _ordered(List<CaseModel> models) =>
      sortCasesForInbox(models.map((m) => m.toEntity()).toList());

  @override
  Stream<List<CaseEntity>> watchAllCases() =>
      _remote.watchAllCases().map(_ordered);

  @override
  Stream<List<CaseEntity>> watchBranchCases(String branchId) =>
      _remote.watchBranchCases(branchId).map(_ordered);

  @override
  Future<List<CaseEntity>> getMyCases(String uid) async {
    try {
      return _ordered(await _remote.getMyCases(uid));
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<CaseEntity?> getCase(String caseId) async {
    try {
      final model = await _remote.getCase(caseId);
      return model?.toEntity();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Stream<CaseEntity?> watchCase(String caseId) =>
      _remote.watchCase(caseId).map((m) => m?.toEntity());

  @override
  Stream<List<CaseMessage>> watchMessages(String caseId) =>
      _remote.watchMessages(caseId);

  @override
  String newCaseId() => _remote.newCaseId();

  @override
  Future<CaseEntity> createCase(
    CaseEntity newCase,
    CaseIdentity identity,
  ) async {
    NetworkGuard.ensureWritable();
    try {
      final created =
          await _remote.createCase(CaseModel.fromEntity(newCase), identity);
      return created.toEntity();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> changeStatus(String caseId, CaseStatus to) async {
    try {
      await _remote.changeStatus(caseId, to);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> sendMessage(String caseId, CaseMessage message) async {
    NetworkGuard.ensureWritable();
    try {
      await _remote.sendMessage(caseId, message);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<CaseIdentity?> revealReporter(String caseId) async {
    try {
      return await _remote.revealReporter(caseId);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<TaskAttachment> uploadAttachment({
    required String caseId,
    required File file,
    required AttachmentType type,
    required String uploadedBy,
    String? uploadedByName,
    int? durationMs,
    void Function(int transferred, int total)? onProgress,
  }) async {
    try {
      return await _remote.uploadAttachment(
        caseId: caseId,
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
  Future<void> deleteCase(String caseId) async {
    NetworkGuard.ensureWritable();
    try {
      await _remote.deleteCase(caseId);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }
}
