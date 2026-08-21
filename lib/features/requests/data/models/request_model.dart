import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:opshub/core/enums/attachment_type.dart';
import 'package:opshub/core/enums/request_status.dart';
import 'package:opshub/core/enums/request_type.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/core/extensions/firestore_extensions.dart';
import 'package:opshub/features/requests/domain/entities/request_entity.dart';
import 'package:opshub/features/requests/domain/entities/request_event.dart';
import 'package:opshub/features/task/domain/entities/task_attachment.dart';

/// Firestore (de)serialization for [RequestEntity] — collection `requests/{id}`.
///
/// The free-text reason lives in `details` (`{'message': <reason>}`). Firestore
/// returns any nested date/time values as [Timestamp], so [_detailsFromMap] /
/// [_detailsToMap] normalize `Timestamp ⇄ DateTime` at this boundary.
///
/// Server-managed fields (`refCode`, `seq`, `createdAt`, `updatedAt`,
/// `lastEventAt`, `decided*`) are written by the datasource (server timestamps)
/// or the `onRequest*` Cloud Functions, so [toMap] (the create payload) omits
/// them. The timeline lives in `requests/{id}/events` ([eventFromMap]).
class RequestModel {
  final String id;
  final String? refCode;
  final int? seq;
  final String? branchId;
  final RequestType type;
  final RequestStatus status;
  final String requesterId;
  final String? requesterName;
  final UserRole requesterRole;
  final Map<String, dynamic> details;
  final List<TaskAttachment> attachments;
  final String? lastEventPreview;
  final DateTime? lastEventAt;
  final int eventCount;
  final String? decidedBy;
  final String? decidedByName;
  final DateTime? decidedAt;
  final DateTime? deletedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const RequestModel({
    required this.id,
    this.refCode,
    this.seq,
    this.branchId,
    required this.type,
    this.status = RequestStatus.pending,
    required this.requesterId,
    this.requesterName,
    this.requesterRole = UserRole.employee,
    this.details = const {},
    this.attachments = const [],
    this.lastEventPreview,
    this.lastEventAt,
    this.eventCount = 0,
    this.decidedBy,
    this.decidedByName,
    this.decidedAt,
    this.deletedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory RequestModel.fromMap(Map<String, dynamic> map, {String? id}) =>
      RequestModel(
        id: id ?? map['id'] as String? ?? '',
        refCode: map['refCode'] as String?,
        seq: (map['seq'] as num?)?.toInt(),
        branchId: map['branchId'] as String?,
        type: RequestType.fromString(map['type'] as String?),
        status: RequestStatus.fromString(map['status'] as String?),
        requesterId: map['requesterId'] as String? ?? '',
        requesterName: map['requesterName'] as String?,
        requesterRole: UserRole.fromString(map['requesterRole'] as String?),
        details: _detailsFromMap(map['details']),
        attachments: _attachmentsFromList(map['attachments']),
        lastEventPreview: map['lastEventPreview'] as String?,
        lastEventAt: map.date('lastEventAt'),
        eventCount: (map['eventCount'] as num?)?.toInt() ?? 0,
        decidedBy: map['decidedBy'] as String?,
        decidedByName: map['decidedByName'] as String?,
        decidedAt: map.date('decidedAt'),
        deletedAt: map.date('deletedAt'),
        createdAt: map.date('createdAt'),
        updatedAt: map.date('updatedAt'),
      );

  factory RequestModel.fromEntity(RequestEntity e) => RequestModel(
        id: e.id,
        refCode: e.refCode,
        seq: e.seq,
        branchId: e.branchId,
        type: e.type,
        status: e.status,
        requesterId: e.requesterId,
        requesterName: e.requesterName,
        requesterRole: e.requesterRole,
        details: e.details,
        attachments: e.attachments,
        lastEventPreview: e.lastEventPreview,
        lastEventAt: e.lastEventAt,
        eventCount: e.eventCount,
        decidedBy: e.decidedBy,
        decidedByName: e.decidedByName,
        decidedAt: e.decidedAt,
        deletedAt: e.deletedAt,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
      );

  /// The **create** payload. Server-managed fields are written by the datasource /
  /// Cloud Functions, so they're omitted. `lastEventPreview` is seeded with the
  /// message so the inbox row has content before `onRequestCreated` bumps it.
  Map<String, dynamic> toMap() => {
        'id': id,
        'branchId': branchId,
        'type': type.value,
        'status': status.value,
        'requesterId': requesterId,
        'requesterName': requesterName,
        'requesterRole': requesterRole.value,
        'details': _detailsToMap(details),
        'attachments': _attachmentsToList(attachments),
        'lastEventPreview': lastEventPreview,
        'eventCount': eventCount,
      };

  RequestModel copyWithId(String newId) => RequestModel(
        id: newId,
        refCode: refCode,
        seq: seq,
        branchId: branchId,
        type: type,
        status: status,
        requesterId: requesterId,
        requesterName: requesterName,
        requesterRole: requesterRole,
        details: details,
        attachments: attachments,
        lastEventPreview: lastEventPreview,
        lastEventAt: lastEventAt,
        eventCount: eventCount,
        decidedBy: decidedBy,
        decidedByName: decidedByName,
        decidedAt: decidedAt,
        deletedAt: deletedAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  RequestEntity toEntity() => RequestEntity(
        id: id,
        refCode: refCode,
        seq: seq,
        branchId: branchId,
        type: type,
        status: status,
        requesterId: requesterId,
        requesterName: requesterName,
        requesterRole: requesterRole,
        details: details,
        attachments: attachments,
        lastEventPreview: lastEventPreview,
        lastEventAt: lastEventAt,
        eventCount: eventCount,
        decidedBy: decidedBy,
        decidedByName: decidedByName,
        decidedAt: decidedAt,
        deletedAt: deletedAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  // ─── Timeline events (`requests/{id}/events/{id}`) ────────────────────
  /// The event payload for a client `add` (comment / attachment-added).
  /// `createdAt` is written as a server timestamp by the datasource.
  static Map<String, dynamic> eventToMap(RequestEvent e) => {
        'authorId': e.authorId,
        'authorName': e.authorName,
        'actor': e.actor.value,
        'kind': e.kind.value,
        'text': e.text,
        'attachments': _attachmentsToList(e.attachments),
      };

  static RequestEvent eventFromMap(Map<String, dynamic> map, {String? id}) =>
      RequestEvent(
        id: id ?? map['id'] as String? ?? '',
        authorId: map['authorId'] as String? ?? '',
        authorName: map['authorName'] as String?,
        actor: RequestEventActor.fromString(map['actor'] as String?),
        kind: RequestEventKind.fromString(map['kind'] as String?),
        text: map['text'] as String?,
        attachments: _attachmentsFromList(map['attachments']),
        createdAt: map.date('createdAt') ?? DateTime.now(),
      );

  // ─── details normalization (Timestamp ⇄ DateTime at the boundary) ─────
  static Map<String, dynamic> _detailsFromMap(dynamic raw) {
    if (raw is! Map) return const {};
    final out = <String, dynamic>{};
    raw.forEach((k, v) {
      out[k.toString()] = v is Timestamp ? v.toDate() : v;
    });
    return out;
  }

  static Map<String, dynamic> _detailsToMap(Map<String, dynamic> details) {
    final out = <String, dynamic>{};
    details.forEach((k, v) {
      out[k] = v is DateTime ? Timestamp.fromDate(v) : v;
    });
    return out;
  }

  // ─── Embedded attachment (de)serializers (mirror TaskModel / CaseModel) ─
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
