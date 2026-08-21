import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:opshub/core/enums/notification_type.dart';

part 'notification_entity.freezed.dart';

/// An in-app + push notification (Notification System Phase 1). One document per
/// recipient at `notifications/{id}`, written either by a client trigger
/// (`NotifyTaskEvent`, for task events) or by the `sendBroadcast` Cloud Function
/// (for broadcasts). The matching FCM push is delivered by the
/// `onNotificationCreated` Cloud Function (task events) or directly by
/// `sendBroadcast` (broadcasts).
///
/// The [payload] is an open string-keyed map carrying the deep-link target +
/// context (`taskId`, `broadcastId`, `category`, `revisionNumber`, `route`); the
/// typed getters below read it safely.
@freezed
class NotificationEntity with _$NotificationEntity {
  const NotificationEntity._();

  const factory NotificationEntity({
    required String id,
    required String recipientUid,
    /// Who triggered it (null for system-generated). For a task event this is
    /// the acting manager/employee; for a broadcast, the sender.
    String? senderUid,
    required NotificationType type,
    required String title,
    required String body,
    required DateTime createdAt,
    /// When the recipient read it; null while unread.
    DateTime? readAt,
    /// When the recipient archived it (hidden from the default inbox, kept for
    /// history); null = in the inbox.
    DateTime? archivedAt,
    /// When the recipient pinned it (kept at the top of the inbox); null = not
    /// pinned.
    DateTime? pinnedAt,
    @Default(<String, dynamic>{}) Map<String, dynamic> payload,
  }) = _NotificationEntity;

  bool get isRead => readAt != null;
  bool get isUnread => readAt == null;
  bool get isArchived => archivedAt != null;
  bool get isPinned => pinnedAt != null;

  // ─── Typed payload reads ───────────────────────────────────────
  String? get taskId => payload['taskId'] as String?;
  String? get caseId => payload['caseId'] as String?;
  String? get requestId => payload['requestId'] as String?;
  String? get broadcastId => payload['broadcastId'] as String?;
  String? get category => payload['category'] as String?;
  int? get revisionNumber => (payload['revisionNumber'] as num?)?.toInt();

  /// The deep-link target the tap handler routes on, e.g. `task_details` or
  /// `broadcast_detail`.
  String? get route => payload['route'] as String?;
}
