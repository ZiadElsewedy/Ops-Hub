import 'package:opshub/core/enums/attachment_type.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/core/utils/app_date_formatter.dart';
import 'package:opshub/features/task/domain/entities/activity_entry.dart';
import 'package:opshub/features/task/domain/entities/task_attachment.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';

/// Presentation helpers for task media (Phase 10). Resolve which attachments a
/// timeline event should show — including a back-compat path that surfaces a
/// **legacy** single `proofImageUrl` as one synthesized image attachment for
/// tasks submitted before media moved onto events.

/// True when any event on the task carries real (Phase 10) media — used to avoid
/// double-rendering the legacy proof alongside new event attachments.
bool _hasEventAttachments(TaskEntity task) =>
    task.activityLog.any((e) => e.attachments.isNotEmpty);

/// Attachments to render for [entry]. Returns the event's own media when present;
/// otherwise, for a truly legacy task, synthesizes the single `proofImageUrl` on
/// the "submitted for review" event so old submissions still show their proof.
List<TaskAttachment> attachmentsForEvent(ActivityEntry entry, TaskEntity task) {
  if (entry.attachments.isNotEmpty) return entry.attachments;
  final proof = task.proofImageUrl ?? '';
  if (proof.isNotEmpty &&
      entry.status == 'waitingReview' &&
      !_hasEventAttachments(task)) {
    return [_legacy(proof, entry.at, entry.actorId, entry.actorName)];
  }
  return const [];
}

/// The most recent submission's media — for the "Submitted work" quick view and
/// the review sheet. Falls back to the legacy proof image.
List<TaskAttachment> latestAttachments(TaskEntity task) {
  for (final e in task.activityLog.reversed) {
    if (e.attachments.isNotEmpty) return e.attachments;
  }
  final proof = task.proofImageUrl ?? '';
  if (proof.isNotEmpty) {
    return [_legacy(proof, task.submittedAt ?? DateTime.now(), '', null)];
  }
  return const [];
}

TaskAttachment _legacy(String url, DateTime at, String by, String? byName) =>
    TaskAttachment(
      id: 'legacy',
      url: url,
      type: AttachmentType.image,
      uploadedAt: at,
      uploadedBy: by,
      uploadedByName: byName,
    );

/// Full upload timestamp, e.g. `20 Jun 2026 • 4:32 PM`.
String attachmentTimestamp(DateTime d) => AppDateFormatter.dayMonthYearTime(d);

/// Video length as `mm:ss` (e.g. `00:28`, `01:05`), or null when unknown.
String? formatVideoDuration(Duration? d) {
  if (d == null) return null;
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// Compact summary like `4 photos`, `1 video`, `3 photos · 1 video`.
String attachmentSummary(List<TaskAttachment> items) {
  final images = items.where((a) => a.type.isImage).length;
  final videos = items.where((a) => a.type.isVideo).length;
  final parts = <String>[];
  if (images > 0) parts.add('$images photo${images == 1 ? '' : 's'}');
  if (videos > 0) parts.add('$videos video${videos == 1 ? '' : 's'}');
  return parts.join(' · ');
}

/// One resolved submission cycle, derived from a task's activity log — the input
/// to the Submission Details surface.
class TaskSubmission {
  const TaskSubmission({
    required this.content,
    required this.attachments,
    required this.feedback,
    required this.awaiting,
  });

  /// The event carrying the work (the `completed` event, normally).
  final ActivityEntry content;
  final List<TaskAttachment> attachments;

  /// The `approved` / `rejected` event that resolved this cycle, if any.
  final ActivityEntry? feedback;

  /// True when this submission is still awaiting a review decision.
  final bool awaiting;
}

/// Resolves the submission cycle around the event at [index]: its content (note
/// + media live on the `completed` event), and the manager decision that
/// followed it (the next `approved` / `rejected` before the next submission).
/// Tapping either the "Completed" or "Submitted for review" card resolves to the
/// same cycle.
TaskSubmission resolveSubmission(TaskEntity task, int index) {
  final log = task.activityLog;
  final tapped = log[index];

  var contentIdx = index;
  if (tapped.status != 'completed') {
    // Tapped "Submitted for review" → walk back to this cycle's completed event.
    for (var j = index - 1; j >= 0; j--) {
      final s = log[j].status;
      if (s == 'completed') {
        contentIdx = j;
        break;
      }
      if (s == 'started' ||
          s == 'pending' ||
          s == 'approved' ||
          s == 'rejected') {
        break;
      }
    }
  }
  final content = log[contentIdx];

  ActivityEntry? feedback;
  for (var j = contentIdx + 1; j < log.length; j++) {
    final s = log[j].status;
    if (s == 'approved' || s == 'rejected') {
      feedback = log[j];
      break;
    }
    if (s == 'completed') break; // a later cycle — stop
  }

  return TaskSubmission(
    content: content,
    attachments: attachmentsForEvent(content, task),
    feedback: feedback,
    awaiting: feedback == null && task.status == TaskStatus.waitingReview,
  );
}
