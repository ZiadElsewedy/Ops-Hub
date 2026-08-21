import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:opshub/features/task/domain/entities/task_attachment.dart';

part 'activity_entry.freezed.dart';

/// Timeline-only [ActivityEntry.status] values — events that belong on the
/// record but are **not** lifecycle states, so they must never be confused with
/// a [TaskStatus]. (`assigned`, the note categories, and these live in the same
/// string space; the renderer in `activity_format.dart` maps them all.)
///
/// An employee's "this task is wrong" report and a manager's dismissal of it
/// both leave a line here, because the decision trail is the point: a task that
/// gets cancelled after a report should show *why* it was questioned, and a
/// report that was overruled should show that someone actually looked.
const String kActivityReportedIncorrect = 'reportedIncorrect';
const String kActivityReportDismissed = 'reportDismissed';

/// An admin returned a terminal task to `pending` (spec §6.4). Recorded as its
/// own timeline event rather than a plain `pending` entry, so the history shows
/// that a closed outcome was *corrected* and does not read as if the task had
/// simply been created again.
const String kActivityTerminalCorrected = 'terminalCorrected';

/// One line in a task's activity timeline. Appended on every status change so
/// managers and employees can see who moved the task and when.
///
/// Phase 10: an event can carry **media [attachments]** (images / videos) — e.g.
/// a submission with four photos, a rework with a video. Attachments belong to
/// the event, not the task, so each submission cycle keeps its own evidence.
@freezed
class ActivityEntry with _$ActivityEntry {
  const factory ActivityEntry({
    /// The [TaskStatus.value] string after the transition.
    required String status,
    /// uid of the person who triggered the change.
    required String actorId,
    /// Denormalised display name (best-effort; falls back to uid).
    String? actorName,
    required DateTime at,
    /// Optional note left with the action (review note, completion note, etc.).
    String? note,
    /// Media attached to this event (images / videos).
    @Default(<TaskAttachment>[]) List<TaskAttachment> attachments,
  }) = _ActivityEntry;
}
