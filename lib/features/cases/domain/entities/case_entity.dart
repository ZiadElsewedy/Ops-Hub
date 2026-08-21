import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:opshub/core/enums/case_category.dart';
import 'package:opshub/core/enums/case_privacy.dart';
import 'package:opshub/core/enums/case_recipient.dart';
import 'package:opshub/core/enums/case_status.dart';
import 'package:opshub/features/task/domain/entities/task_attachment.dart';

part 'case_entity.freezed.dart';

/// A single **Case** — a temporary, private conversation between an employee and
/// a manager/admin about a specific issue, kept open until resolution. This doc
/// (`cases/{id}`) carries only the case **metadata**; the conversation itself
/// lives in the `cases/{id}/messages` subcollection (streamed in realtime), and
/// the reporter's identity lives in the private `cases/{id}/reporter/identity`
/// subdoc — this doc **never carries the creator uid**.
///
/// **Privacy split:** [reporterDisplayName] is present only for a `normal` case;
/// a confidential case renders "Confidential Sender" and only an admin can
/// reveal the sender (via the identity subdoc).
///
/// [description] + [attachments] are the opening content the filer submits; on
/// create the `onCaseCreated` Cloud Function turns them into the first
/// ([CaseMessageKind.opening]) message so the conversation is self-contained.
@freezed
class CaseEntity with _$CaseEntity {
  const CaseEntity._();

  const factory CaseEntity({
    required String id,
    /// Owning branch (the reporter's branch). Scopes every read/query.
    String? branchId,
    required String subject,
    String? description,
    @Default(CaseCategory.operations) CaseCategory category,
    @Default(CaseRecipient.manager) CaseRecipient recipient,
    @Default(CasePrivacy.normal) CasePrivacy privacy,
    /// A single escalation signal (replaces the old 4-level severity). Urgent
    /// cases sort above normal ones in the inbox and show an urgent badge.
    @Default(false) bool urgent,
    @Default(CaseStatus.open) CaseStatus status,
    /// Denormalized sender name — set ONLY when [privacy] is normal; null
    /// otherwise (UI then shows "Confidential Sender").
    String? reporterDisplayName,
    /// Opening media the filer attached (consumed by `onCaseCreated` into the
    /// opening message; Storage `cases/{id}/attachments/{attId}.<ext>`).
    @Default(<TaskAttachment>[]) List<TaskAttachment> attachments,
    /// Denormalized last-message preview for the inbox row (bumped server-side).
    String? lastMessagePreview,
    /// Timestamp of the newest message — the inbox orders active cases by this.
    DateTime? lastMessageAt,
    @Default(0) int messageCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? closedAt,
  }) = _CaseEntity;

  /// Whether a branch manager may see this case — the denormalized flag the
  /// manager list query + Firestore rule key off. Derived from [recipient] so it
  /// can never drift (the model writes this to `visibleToManager`).
  bool get visibleToManager => recipient.includesManager;

  /// Still an open conversation (drives inbox placement + "active" counts).
  bool get isActive => status.isActive;
  bool get isClosed => status.isClosed;

  bool get hasAttachments => attachments.isNotEmpty;

  /// The label to show for the sender, honoring [privacy]. Presentation reuses
  /// this so the mapping lives in one place.
  String get senderLabel {
    if (privacy.isConfidential) return 'Confidential Sender';
    final name = reporterDisplayName?.trim();
    return (name != null && name.isNotEmpty) ? name : 'Reporter';
  }

  /// Timestamp used to order the inbox — latest message, falling back to create.
  DateTime? get lastActivityAt => lastMessageAt ?? createdAt;
}
