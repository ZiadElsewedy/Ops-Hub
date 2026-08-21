import 'dart:io';
import 'package:opshub/core/enums/attachment_type.dart';
import 'package:opshub/core/media/media_upload_service.dart';
import 'package:opshub/features/task/domain/entities/task_attachment.dart';
import 'package:opshub/features/task/domain/repositories/task_repository.dart';

/// Uploads one media file (image / video) for a task and returns the resolved
/// [TaskAttachment] (id, download url, type, uploader, time). Pass an
/// [UploadCanceller] to make the upload abortable (the submission overlay's
/// Cancel button); it throws [UploadCancelledException] when cancelled.
class UploadTaskAttachment {
  final TaskRepository _repository;
  const UploadTaskAttachment(this._repository);

  Future<TaskAttachment> call({
    required String taskId,
    required File file,
    required AttachmentType type,
    required String uploadedBy,
    String? uploadedByName,
    int? durationMs,
    UploadCanceller? canceller,
    void Function(int transferred, int total)? onProgress,
  }) =>
      _repository.uploadAttachment(
        taskId: taskId,
        file: file,
        type: type,
        uploadedBy: uploadedBy,
        uploadedByName: uploadedByName,
        durationMs: durationMs,
        canceller: canceller,
        onProgress: onProgress,
      );
}
