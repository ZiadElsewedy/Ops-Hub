import 'package:opshub/features/attendance/domain/entities/attendance_entity.dart';

/// A snapshot of a user's attendance history **plus its Firestore sync state**.
///
/// The clock surface is driven optimistically off Firestore's offline cache: a
/// clock-in/out completes immediately from a local write and syncs to the backend
/// in the background (where the Cloud Functions then derive the audit trail). This
/// carries the snapshot's metadata so the cubit can surface an honest
/// **offline** / **syncing** hint without a second listener or a custom sync queue:
///   * [isOffline] — the snapshot was served purely from cache (no server round-trip
///     yet), i.e. the device is offline.
///   * [hasPendingWrites] — a local write hasn't been acknowledged by the backend
///     yet (the "syncing…" state).
class AttendanceFeed {
  final List<AttendanceEntity> records;
  final bool isOffline;
  final bool hasPendingWrites;

  const AttendanceFeed({
    this.records = const [],
    this.isOffline = false,
    this.hasPendingWrites = false,
  });

  static const AttendanceFeed empty = AttendanceFeed();
}
