import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:opshub/core/enums/attachment_type.dart';
import 'package:opshub/core/enums/case_category.dart';
import 'package:opshub/core/enums/case_privacy.dart';
import 'package:opshub/core/enums/case_recipient.dart';
import 'package:opshub/core/enums/case_status.dart';
import 'package:opshub/core/extensions/firestore_extensions.dart';
import 'package:opshub/features/cases/domain/entities/case_entity.dart';
import 'package:opshub/features/cases/domain/entities/case_identity.dart';
import 'package:opshub/features/cases/domain/entities/case_message.dart';
import 'package:opshub/features/task/domain/entities/task_attachment.dart';

/// Firestore (de)serialization for [CaseEntity] — collection `cases/{id}`.
///
/// The creator uid is deliberately **absent** from this doc (privacy split — it
/// lives in the private `reporter/identity` subdoc; see [identityToMap]).
/// `reporterDisplayName` is written only when the case's privacy is `normal`, so
/// a confidential sender is never exposed on the manager-readable doc.
/// `visibleToManager` is a denormalized bool derived from `recipient` for the
/// manager list query + Firestore rule. The conversation is NOT stored here — it
/// lives in the `cases/{id}/messages` subcollection ([messageFromMap]).
class CaseModel {
  final String id;
  final String? branchId;
  final String subject;
  final String? description;
  final CaseCategory category;
  final CaseRecipient recipient;
  final CasePrivacy privacy;
  final bool urgent;
  final CaseStatus status;
  final String? reporterDisplayName;
  final List<TaskAttachment> attachments;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;
  final int messageCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? closedAt;

  const CaseModel({
    required this.id,
    this.branchId,
    required this.subject,
    this.description,
    this.category = CaseCategory.operations,
    this.recipient = CaseRecipient.manager,
    this.privacy = CasePrivacy.normal,
    this.urgent = false,
    this.status = CaseStatus.open,
    this.reporterDisplayName,
    this.attachments = const [],
    this.lastMessagePreview,
    this.lastMessageAt,
    this.messageCount = 0,
    this.createdAt,
    this.updatedAt,
    this.closedAt,
  });

  factory CaseModel.fromMap(Map<String, dynamic> map, {String? id}) => CaseModel(
        id: id ?? map['id'] as String? ?? '',
        branchId: map['branchId'] as String?,
        subject: map['subject'] as String? ?? '',
        description: map['description'] as String?,
        category: CaseCategory.fromString(map['category'] as String?),
        recipient: CaseRecipient.fromString(map['recipient'] as String?),
        privacy: CasePrivacy.fromString(map['privacy'] as String?),
        urgent: map['urgent'] as bool? ?? false,
        status: CaseStatus.fromString(map['status'] as String?),
        reporterDisplayName: map['reporterDisplayName'] as String?,
        attachments: _attachmentsFromList(map['attachments']),
        lastMessagePreview: map['lastMessagePreview'] as String?,
        lastMessageAt: map.date('lastMessageAt'),
        messageCount: (map['messageCount'] as num?)?.toInt() ?? 0,
        createdAt: map.date('createdAt'),
        updatedAt: map.date('updatedAt'),
        closedAt: map.date('closedAt'),
      );

  factory CaseModel.fromEntity(CaseEntity e) => CaseModel(
        id: e.id,
        branchId: e.branchId,
        subject: e.subject,
        description: e.description,
        category: e.category,
        recipient: e.recipient,
        privacy: e.privacy,
        urgent: e.urgent,
        status: e.status,
        reporterDisplayName: e.reporterDisplayName,
        attachments: e.attachments,
        lastMessagePreview: e.lastMessagePreview,
        lastMessageAt: e.lastMessageAt,
        messageCount: e.messageCount,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
        closedAt: e.closedAt,
      );

  /// The **create** payload. `createdAt`/`updatedAt`/`lastMessageAt` are written
  /// as server timestamps by the datasource, so they're not included here. The
  /// opening message is written server-side (`onCaseCreated`), which reads
  /// `description` + `attachments` from here.
  Map<String, dynamic> toMap() => {
        'id': id,
        'branchId': branchId,
        'subject': subject,
        'description': description,
        'category': category.value,
        'recipient': recipient.value,
        'privacy': privacy.value,
        'urgent': urgent,
        'status': status.value,
        // Denormalized manager-visibility flag (drives the manager query + rule).
        'visibleToManager': recipient.includesManager,
        // Privacy split: the sender's name rides the manager-readable doc ONLY
        // for a `normal` case; confidential never exposes it here.
        'reporterDisplayName': privacy.exposesName ? reporterDisplayName : null,
        'attachments': _attachmentsToList(attachments),
        'lastMessagePreview': lastMessagePreview,
        'messageCount': messageCount,
        'closedAt': closedAt == null ? null : Timestamp.fromDate(closedAt!),
      };

  CaseModel copyWithId(String newId) => CaseModel(
        id: newId,
        branchId: branchId,
        subject: subject,
        description: description,
        category: category,
        recipient: recipient,
        privacy: privacy,
        urgent: urgent,
        status: status,
        reporterDisplayName: reporterDisplayName,
        attachments: attachments,
        lastMessagePreview: lastMessagePreview,
        lastMessageAt: lastMessageAt,
        messageCount: messageCount,
        createdAt: createdAt,
        updatedAt: updatedAt,
        closedAt: closedAt,
      );

  CaseEntity toEntity() => CaseEntity(
        id: id,
        branchId: branchId,
        subject: subject,
        description: description,
        category: category,
        recipient: recipient,
        privacy: privacy,
        urgent: urgent,
        status: status,
        reporterDisplayName: reporterDisplayName,
        attachments: attachments,
        lastMessagePreview: lastMessagePreview,
        lastMessageAt: lastMessageAt,
        messageCount: messageCount,
        createdAt: createdAt,
        updatedAt: updatedAt,
        closedAt: closedAt,
      );

  // ─── Reporter identity subdoc (`cases/{id}/reporter/identity`) ────────
  /// The private identity payload. `createdAt` is written as a server timestamp
  /// by the datasource, so it's not included here.
  static Map<String, dynamic> identityToMap(CaseIdentity i) => {
        'caseId': i.caseId,
        'createdByUserId': i.createdByUserId,
        'createdByName': i.createdByName,
        'privacy': i.privacy.value,
        'branchId': i.branchId,
      };

  static CaseIdentity identityFromMap(
    Map<String, dynamic> map, {
    String? caseId,
  }) =>
      CaseIdentity(
        caseId: caseId ?? map['caseId'] as String? ?? '',
        createdByUserId: map['createdByUserId'] as String? ?? '',
        createdByName: map['createdByName'] as String?,
        privacy: CasePrivacy.fromString(map['privacy'] as String?),
        branchId: map['branchId'] as String?,
        createdAt: map.date('createdAt'),
      );

  // ─── Conversation messages (`cases/{id}/messages/{id}`) ───────────────
  /// The message payload for a client `add`. `createdAt` is written as a server
  /// timestamp by the datasource (the rule requires `createdAt == request.time`).
  static Map<String, dynamic> messageToMap(CaseMessage m) => {
        'authorId': m.authorId,
        'authorName': m.authorName,
        'authorRole': m.authorRole.value,
        'kind': m.kind.value,
        'text': m.text,
        'attachments': _attachmentsToList(m.attachments),
        'systemEvent': m.systemEvent,
      };

  static CaseMessage messageFromMap(Map<String, dynamic> map, {String? id}) =>
      CaseMessage(
        id: id ?? map['id'] as String? ?? '',
        authorId: map['authorId'] as String? ?? '',
        authorName: map['authorName'] as String?,
        authorRole: CaseAuthorRole.fromString(map['authorRole'] as String?),
        kind: CaseMessageKind.fromString(map['kind'] as String?),
        text: map['text'] as String?,
        attachments: _attachmentsFromList(map['attachments']),
        systemEvent: map['systemEvent'] as String?,
        createdAt: map.date('createdAt') ?? DateTime.now(),
      );

  // ─── Embedded (de)serializers (mirror TaskModel) ──────────────────────
  static List<TaskAttachment> _attachmentsFromList(dynamic raw) {
    if (raw is! List) return const [];
    final result = <TaskAttachment>[];
    for (final a in raw) {
      if (a is Map) {
        final url = a['url'] as String? ?? '';
        if (url.isEmpty) continue;
        result.add(TaskAttachment(
          id: a['id'] as String? ?? '',
          url: url,
          type: AttachmentType.fromString(a['type'] as String?),
          uploadedAt: (a['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          uploadedBy: a['uploadedBy'] as String? ?? '',
          uploadedByName: a['uploadedByName'] as String?,
          durationMs: (a['durationMs'] as num?)?.toInt(),
        ));
      }
    }
    return result;
  }

  static List<Map<String, dynamic>> _attachmentsToList(
          List<TaskAttachment> items) =>
      [
        for (final a in items)
          {
            'id': a.id,
            'url': a.url,
            'type': a.type.value,
            'uploadedAt': Timestamp.fromDate(a.uploadedAt),
            'uploadedBy': a.uploadedBy,
            'uploadedByName': a.uploadedByName,
            'durationMs': a.durationMs,
          },
      ];
}
