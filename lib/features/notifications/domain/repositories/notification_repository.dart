import 'package:drop/features/notifications/domain/entities/notification_entity.dart';

/// Contract for the in-app notification inbox (Notification System Phase 1).
/// Access is enforced server-side by `firestore.rules` (`notifications/{id}`):
/// a recipient reads/updates their own notifications; the creator stamps
/// themselves as `senderUid` on create.
abstract class NotificationRepository {
  /// Persists one notification document.
  Future<void> create(NotificationEntity notification);

  /// Persists many notifications in a single batched write (multi-recipient
  /// task events — one doc per assignee).
  Future<void> createMany(List<NotificationEntity> notifications);

  /// Realtime feed of [uid]'s most recent [limit] notifications, newest first
  /// (server-ordered via the `recipientUid + createdAt` index). Grow [limit] to
  /// paginate.
  Stream<List<NotificationEntity>> watch(String uid, {int limit = 30});

  /// Marks one notification read (sets `readAt`). **The one write in this
  /// contract that is allowed offline** — see the impl for why.
  Future<void> markRead(String id);

  /// Marks every unread notification for [uid] read — all of them, not just a
  /// loaded page.
  Future<void> markAllRead(String uid);

  /// Permanently deletes one notification.
  Future<void> delete(String id);

  /// Permanently deletes **every** archived notification for [uid].
  Future<void> deleteArchived(String uid);

  /// Archives / unarchives one notification.
  Future<void> setArchived(String id, bool archived);

  /// Pins / unpins one notification.
  Future<void> setPinned(String id, bool pinned);
}
