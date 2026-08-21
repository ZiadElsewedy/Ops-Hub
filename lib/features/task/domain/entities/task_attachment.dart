import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:opshub/core/enums/attachment_type.dart';

part 'task_attachment.freezed.dart';

/// A single piece of media (image or video) attached to a **task event**
/// (Phase 10 media upgrade). Attachments belong to an [ActivityEntry], not the
/// task globally — so a submission event can carry several photos, a rework
/// event a video, etc.
///
/// Stored in Firebase Storage at `tasks/{taskId}/attachments/{id}.<ext>` (one
/// unique [id] per upload — files are never overwritten). The [uploadedBy] /
/// [uploadedByName] are denormalised so the timeline can show "Uploaded by Ziad"
/// without a user lookup.
@freezed
class TaskAttachment with _$TaskAttachment {
  const TaskAttachment._();

  const factory TaskAttachment({
    /// Unique attachment id (also the Storage filename stem).
    required String id,

    /// Storage download URL.
    required AttachmentType type,
    required String url,
    required DateTime uploadedAt,

    /// uid of the uploader.
    required String uploadedBy,

    /// Denormalised uploader display name (best-effort).
    String? uploadedByName,

    /// Video length in milliseconds (best-effort, captured at pick). Null for
    /// images and for videos uploaded before duration capture existed.
    int? durationMs,
  }) = _TaskAttachment;

  /// Video length, or null when unknown.
  Duration? get duration =>
      durationMs == null ? null : Duration(milliseconds: durationMs!);
}

/// Submission media limits + pre-upload optimization knobs (Phase 10). Enforced
/// in the picker UI before upload. Images and videos have **separate** size
/// caps — a compressed photo is tiny, but operational videos are legitimately
/// large, so they get a much higher ceiling. Central so the numbers live in one
/// place.
class AttachmentLimits {
  AttachmentLimits._();

  // Count caps.
  static const int maxImages = 6;
  static const int maxVideos = 3;

  // Size caps — separate per type (post-optimization).
  static const int maxImageMb = 15;
  static const int maxVideoMb = 200;
  static const int maxImageBytes = maxImageMb * 1024 * 1024;
  static const int maxVideoBytes = maxVideoMb * 1024 * 1024;

  // Image optimization applied at pick time (image_picker resizes + recompresses
  // the file before it ever reaches us — cuts upload time and Storage cost).
  static const double imageMaxWidth = 1600;
  static const int imageQuality = 70;

  // Hard cap on recorded video length (also bounds size for camera capture).
  static const Duration maxVideoDuration = Duration(minutes: 3);

  /// Per-type size ceiling in bytes.
  static int maxBytesFor(AttachmentType type) =>
      type.isVideo ? maxVideoBytes : maxImageBytes;

  /// Per-type size ceiling in MB (for messages).
  static int maxMbFor(AttachmentType type) =>
      type.isVideo ? maxVideoMb : maxImageMb;
}
