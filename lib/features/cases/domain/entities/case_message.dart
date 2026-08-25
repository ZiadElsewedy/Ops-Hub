import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:opshub/features/task/domain/entities/task_attachment.dart';

part 'case_message.freezed.dart';

/// What produced a message in a case conversation.
///
/// [opening] — the first message (the case itself: subject context + the
///             reporter's description + any opening attachments). Written
///             server-side by `onCaseCreated`.
/// [message] — a normal chat reply from a participant (reporter or recipient).
/// [system]  — a lifecycle marker (status changed). Written server-side by
///             `onCaseUpdated`; rendered as a centered chip, never a bubble.
enum CaseMessageKind {
  opening,
  message,
  system;

  String get value => name;

  bool get isSystem => this == CaseMessageKind.system;
  bool get isOpening => this == CaseMessageKind.opening;

  static CaseMessageKind fromString(String? raw) {
    for (final k in CaseMessageKind.values) {
      if (k.name == raw) return k;
    }
    return CaseMessageKind.message;
  }
}

/// Who authored a message, independent of the raw uid (which is empty for a
/// de-identified confidential reporter). Drives bubble alignment without leaking
/// identity.
enum CaseAuthorRole {
  reporter,
  recipient,
  system;

  String get value => name;

  static CaseAuthorRole fromString(String? raw) {
    for (final r in CaseAuthorRole.values) {
      if (r.name == raw) return r;
    }
    return CaseAuthorRole.reporter;
  }
}

/// One message in a case conversation — a document in the `cases/{id}/messages`
/// subcollection. Append-only and immutable: a reply is a single `add`, so there
/// is no whole-array read-modify-write (the class of bug the old `activityLog`
/// array suffered). Reuses the task [TaskAttachment] pipeline for media.
@freezed
class CaseMessage with _$CaseMessage {
  const CaseMessage._();

  const factory CaseMessage({
    required String id,
    /// Author uid, or '' when de-identified (a confidential reporter, or a
    /// system message).
    @Default('') String authorId,
    /// Denormalized author name ("Confidential Sender" / "System" when hidden).
    String? authorName,
    @Default(CaseAuthorRole.reporter) CaseAuthorRole authorRole,
    @Default(CaseMessageKind.message) CaseMessageKind kind,
    String? text,
    @Default(<TaskAttachment>[]) List<TaskAttachment> attachments,
    /// For a [CaseMessageKind.system] message — the [CaseStatus.value] it marks.
    String? systemEvent,
    required DateTime createdAt,
  }) = _CaseMessage;

  bool get isSystem => kind == CaseMessageKind.system;
  bool get isOpening => kind == CaseMessageKind.opening;
  bool get hasAttachments => attachments.isNotEmpty;
  bool get hasText => (text ?? '').trim().isNotEmpty;
}
