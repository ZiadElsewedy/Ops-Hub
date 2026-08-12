import 'package:drop/core/enums/leave_type.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/enums/swap_status.dart';
import 'package:drop/features/schedule/domain/entities/shift_swap_entity.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:drop/features/schedule/domain/shift_hours.dart';
import 'package:drop/features/schedule/domain/shift_plan.dart';

/// Contract for weekly-schedule + shift-swap data access (Phase 7). Branch/role
/// access is enforced server-side by `firestore.rules` (admin: all branches;
/// manager: own branch; employee: read own branch + create/act on their swaps).
abstract class ScheduleRepository {
  /// The branch's schedule for the week containing [weekStart], or null if the
  /// manager hasn't created one yet.
  Future<WeeklyScheduleEntity?> getSchedule(
      String branchId, DateTime weekStart);

  /// [getSchedule] answered from the on-device cache when the week is already
  /// there, falling back to the server on a miss.
  ///
  /// Only for callers that need the roster immediately and reconcile against
  /// the server afterwards (today: binding an employee's shift task streams).
  /// Anything that shows or edits the roster must use [getSchedule].
  Future<WeeklyScheduleEntity?> getScheduleCacheFirst(
      String branchId, DateTime weekStart);

  /// All of a branch's weekly schedules (newest week first).
  Future<List<WeeklyScheduleEntity>> getBranchSchedules(String branchId);

  /// Every branch's schedules — admin only.
  Future<List<WeeklyScheduleEntity>> getAllSchedules();

  /// Creates an empty schedule for ([branchId], [weekStart]). [shiftPlan] is the
  /// branch's shift-hours snapshot captured at creation (Schedule V2 · Pillar 5);
  /// null keeps the week on standard hours (legacy behaviour).
  Future<WeeklyScheduleEntity> createSchedule({
    required String branchId,
    required DateTime weekStart,
    String? createdBy,
    ShiftPlan? shiftPlan,
  });

  /// **Global template change** (Schedule V2 · Pillar 5): re-stamps [plan] onto
  /// the frozen snapshot of every existing week for [branchId] with
  /// `weekStart >= fromWeek` (current + future already-created weeks). Past weeks
  /// are never touched, so history stays frozen.
  Future<void> restampShiftPlan({
    required String branchId,
    required DateTime fromWeek,
    required ShiftPlan plan,
  });

  /// Adds [employeeId] to a (day, shift) slot of the schedule [scheduleId].
  Future<void> assignEmployee({
    required String scheduleId,
    required ScheduleDay day,
    required ScheduleShift shift,
    required String employeeId,
  });

  /// Removes [employeeId] from a (day, shift) slot of the schedule [scheduleId].
  Future<void> removeEmployee({
    required String scheduleId,
    required ScheduleDay day,
    required ScheduleShift shift,
    required String employeeId,
  });

  /// Atomically reassigns [employeeId] from one slot to another (never in both,
  /// never in neither). Caller guarantees the slots differ.
  Future<void> moveEmployee({
    required String scheduleId,
    required ScheduleDay fromDay,
    required ScheduleShift fromShift,
    required ScheduleDay toDay,
    required ScheduleShift toShift,
    required String employeeId,
  });

  /// Atomically swaps [uidA] (slot A) and [uidB] (slot B) — all-or-nothing, so
  /// neither is ever double-booked. Caller guarantees the slots and uids differ.
  Future<void> exchangeEmployees({
    required String scheduleId,
    required ScheduleDay dayA,
    required ScheduleShift shiftA,
    required String uidA,
    required ScheduleDay dayB,
    required ScheduleShift shiftB,
    required String uidB,
  });

  /// Sets (or clears, when [note] is empty) the manager note pinned to [day].
  Future<void> setDayNote({
    required String scheduleId,
    required ScheduleDay day,
    required String note,
  });

  /// Marks [employeeId] on [type] leave for [day]; a null [type] clears the
  /// entry. Leave is a day-level fact (see [WeeklyScheduleEntity.leave]).
  Future<void> setLeave({
    required String scheduleId,
    required ScheduleDay day,
    required String employeeId,
    required LeaveType? type,
  });

  /// Overrides the [hours] for [day] + [shift] this week; a null [hours] clears
  /// the override (falls back to [ShiftHours.standard]). See
  /// [WeeklyScheduleEntity.shiftHours].
  Future<void> setShiftHours({
    required String scheduleId,
    required ScheduleDay day,
    required ScheduleShift shift,
    required ShiftHours? hours,
  });

  // ── Shift swaps ──
  /// Swap requests for a branch — the manager's approval queue.
  Future<List<ShiftSwapEntity>> getBranchSwaps(String branchId);

  /// Swap requests involving [uid] (as requester or target).
  Future<List<ShiftSwapEntity>> getEmployeeSwaps(String uid);

  /// Every branch's swap requests — admin only (powers the Admin Home overview).
  Future<List<ShiftSwapEntity>> getAllSwaps();

  /// Realtime swap streams (newest first) — the live source behind employee /
  /// manager / admin pending-swap surfaces, so an accept/reject/approve reflects
  /// instantly without a manual refresh.
  Stream<List<ShiftSwapEntity>> watchEmployeeSwaps(String uid);
  Stream<List<ShiftSwapEntity>> watchBranchSwaps(String branchId);
  Stream<List<ShiftSwapEntity>> watchAllSwaps();

  /// Creates a swap request (status pending).
  Future<ShiftSwapEntity> createSwap(ShiftSwapEntity swap);

  /// Sets a swap to [status] — used for coworker approval, and rejections by any
  /// party. (Manager approval also rewrites the schedule — see
  /// [managerApproveSwap].)
  Future<void> updateSwapStatus({
    required String swapId,
    required SwapStatus status,
  });

  /// Manager approval: finalizes the swap via the server-authoritative
  /// `approveSwap` Cloud Function, which re-validates against the freshest
  /// schedule and **atomically exchanges the two slots** — the requester and the
  /// target trade shifts on the same day (Ziad's Night ⇄ Ahmed's Morning), then
  /// the swap is marked [SwapStatus.managerApproved]. Either both move or nothing
  /// changes; a partial roster mutation is impossible.
  Future<void> managerApproveSwap(ShiftSwapEntity swap);
}
