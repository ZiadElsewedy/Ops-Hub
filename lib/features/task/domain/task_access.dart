import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/task_assignment_type.dart';
import 'package:opshub/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';

/// Whether [uid] may see/act on [task] — the single rule shared by the
/// employee task stream (`TaskCubit`) and any surface that needs to know
/// "is this mine".
///
/// - `individual` / `team` — unchanged: [uid] must be in
///   [TaskEntity.assigneeIds].
/// - `shift` — [uid] must be rostered on [TaskEntity.shift] *today* in
///   [schedule] (the branch's weekly roster). No [schedule] or no [TaskEntity.shift]
///   → not accessible (a shift task can never leak to someone we can't place on
///   a shift for).
///
/// Pure and deterministic — [now] is injectable so this is unit-testable
/// without a clock (mirrors `isTaskInActiveWindow`).
bool canUserAccessTask({
  required TaskEntity task,
  required String uid,
  WeeklyScheduleEntity? schedule,
  DateTime? now,
}) {
  if (task.assignmentType != TaskAssignmentType.shift) {
    return task.assigneeIds.contains(uid);
  }
  final shift = task.shift;
  if (shift == null || schedule == null) return false;
  final day = ScheduleDay.fromDate(now ?? DateTime.now());
  return schedule.isAssigned(uid, day, shift);
}
