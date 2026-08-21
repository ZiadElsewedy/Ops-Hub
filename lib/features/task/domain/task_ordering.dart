import 'package:opshub/features/task/domain/entities/task_entity.dart';

/// Orders tasks **newest-first** by [TaskEntity.createdAt].
///
/// Firestore already returns tasks `createdAt` descending, but a task just
/// created on this device has a *pending* server timestamp — `createdAt` is null
/// locally until the server confirms it, which Firestore would sort to the
/// bottom. We treat a null (pending) timestamp as the newest so the brand-new
/// task stays on top immediately, then settles once the real timestamp arrives.
List<TaskEntity> sortTasksNewestFirst(List<TaskEntity> tasks) {
  final sorted = [...tasks];
  sorted.sort((a, b) {
    final ad = a.createdAt;
    final bd = b.createdAt;
    if (ad == null && bd == null) return 0;
    if (ad == null) return -1; // a is pending → newest
    if (bd == null) return 1; // b is pending → newest
    return bd.compareTo(ad); // both real → descending
  });
  return sorted;
}
