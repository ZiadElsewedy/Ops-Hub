import 'dart:io';
import 'package:opshub/core/enums/attachment_type.dart';
import 'package:opshub/features/cases/domain/repositories/case_repository.dart';
import 'package:opshub/features/task/domain/entities/task_attachment.dart';

/// Uploads one media file (image / video) for a case and returns the resolved
/// [TaskAttachment] (id, download url, type, uploader, time).
class UploadCaseAttachment {
  final CaseRepository _repository;
  const UploadCaseAttachment(this._repository);

  Future<TaskAttachment> call({
    required String caseId,
    required File file,
    required AttachmentType type,
    required String uploadedBy,
    String? uploadedByName,
    int? durationMs,
    void Function(int transferred, int total)? onProgress,
  }) =>
      _repository.uploadAttachment(
        caseId: caseId,
        file: file,
        type: type,
        uploadedBy: uploadedBy,
        uploadedByName: uploadedByName,
        durationMs: durationMs,
        onProgress: onProgress,
      );
}
