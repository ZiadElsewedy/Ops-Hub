import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:opshub/core/enums/notification_type.dart';
import 'package:opshub/core/extensions/firestore_extensions.dart';
import 'package:opshub/features/notifications/domain/entities/notification_entity.dart';

/// Firestore (de)serialization for [NotificationEntity] — collection
/// `notifications/{id}`. Hand-written (not json_serializable) so Firestore
/// `Timestamp`s round-trip cleanly, matching the project's model convention
/// (`TaskModel`, `BroadcastModel`).
///
/// `createdAt` is written as a server timestamp on create (so it is excluded
/// from [toMap]); `readAt` is a nullable `Timestamp`. `type` persists as its
/// [NotificationType.value] (the enum name).
class NotificationModel {
  final String id;
  final String recipientUid;
  final String? senderUid;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime? createdAt;
  final DateTime? readAt;
  final DateTime? archivedAt;
  final DateTime? pinnedAt;
  final Map<String, dynamic> payload;

  const NotificationModel({
    required this.id,
    required this.recipientUid,
    this.senderUid,
    required this.type,
    required this.title,
    required this.body,
    this.createdAt,
    this.readAt,
    this.archivedAt,
    this.pinnedAt,
    this.payload = const {},
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, {String? id}) =>
      NotificationModel(
        id: id ?? map['id'] as String? ?? '',
        recipientUid: map['recipientUid'] as String? ?? '',
        senderUid: map['senderUid'] as String?,
        // An unrecognised type lands as `unknown`, NEVER as a real type. The
        // old `?? taskAssigned` made every type this build had not heard of
        // impersonate a task — wrong glyph, wrong category pill, `high`
        // priority above real overdue work. See [NotificationType.unknown].
        type: NotificationType.fromString(map['type'] as String?) ??
            NotificationType.unknown,
        title: map['title'] as String? ?? '',
        body: map['body'] as String? ?? '',
        createdAt: map.date('createdAt'),
        readAt: map.date('readAt'),
        archivedAt: map.date('archivedAt'),
        pinnedAt: map.date('pinnedAt'),
        payload: _payloadFromMap(map['payload']),
      );

  factory NotificationModel.fromEntity(NotificationEntity e) => NotificationModel(
        id: e.id,
        recipientUid: e.recipientUid,
        senderUid: e.senderUid,
        type: e.type,
        title: e.title,
        body: e.body,
        createdAt: e.createdAt,
        readAt: e.readAt,
        archivedAt: e.archivedAt,
        pinnedAt: e.pinnedAt,
        payload: e.payload,
      );

  /// Writable fields. `createdAt` is set server-side (excluded). `readAt` is
  /// written when present (a mark-read uses a dedicated `{readAt}` update).
  Map<String, dynamic> toMap() => {
        'id': id,
        'recipientUid': recipientUid,
        'senderUid': senderUid,
        'type': type.value,
        'title': title,
        'body': body,
        'readAt': readAt == null ? null : Timestamp.fromDate(readAt!),
        'archivedAt': archivedAt == null ? null : Timestamp.fromDate(archivedAt!),
        'pinnedAt': pinnedAt == null ? null : Timestamp.fromDate(pinnedAt!),
        'payload': payload,
      };

  NotificationEntity toEntity() => NotificationEntity(
        id: id,
        recipientUid: recipientUid,
        senderUid: senderUid,
        type: type,
        title: title,
        body: body,
        // A doc with a still-pending server timestamp reads as "just now".
        createdAt: createdAt ?? DateTime.now(),
        readAt: readAt,
        archivedAt: archivedAt,
        pinnedAt: pinnedAt,
        payload: payload,
      );

  static Map<String, dynamic> _payloadFromMap(dynamic raw) {
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    return const {};
  }
}
