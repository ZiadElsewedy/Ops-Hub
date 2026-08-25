import 'package:opshub/features/communications/domain/entities/broadcast_schedule_entity.dart';

/// Contract for scheduled / recurring broadcasts (Communications Center — Phase 2
/// Commit 4). Access is enforced server-side by `firestore.rules`
/// (`broadcastSchedules/{id}`): admin any; an own-branch manager their own; the
/// scheduler Cloud Function advances runs via the Admin SDK.
abstract class BroadcastScheduleRepository {
  Future<List<BroadcastScheduleEntity>> getSchedules({
    required String uid,
    required bool isAdmin,
  });

  /// Creates a schedule. [targetUserIds] is the recipient list for a `custom`
  /// schedule (stored on the doc, not the entity).
  Future<BroadcastScheduleEntity> create(
    BroadcastScheduleEntity schedule, {
    List<String> targetUserIds,
  });

  Future<void> update(BroadcastScheduleEntity schedule);
  Future<void> setEnabled(String id, bool enabled);
  Future<void> delete(String id);
}
