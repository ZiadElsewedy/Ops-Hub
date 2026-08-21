import 'dart:io';

import 'package:opshub/core/enums/attachment_type.dart';
import 'package:opshub/features/requests/domain/repositories/request_repository.dart';
import 'package:opshub/features/task/domain/entities/task_attachment.dart';

/// Uploads one media file (image / video) for a request and returns the resolved
/// [TaskAttachment] (id, download url, type, uploader, time).
class UploadRequestAttachment {
  final RequestRepository _repository;
  const UploadRequestAttachment(this._repository);

  Future<TaskAttachment> call({
    required String requestId,
    required File file,
    required AttachmentType type,
    required String uploadedBy,
    String? uploadedByName,
    int? durationMs,
    void Function(int transferred, int total)? onProgress,
  }) =>
      _repository.uploadAttachment(
        requestId: requestId,
        file: file,
        type: type,
        uploadedBy: uploadedBy,
        uploadedByName: uploadedByName,
        durationMs: durationMs,
        onProgress: onProgress,
      );
}
