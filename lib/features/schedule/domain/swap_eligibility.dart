import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/schedule/domain/shift_hours.dart';

/// Pure, framework-free validation for **shift-swap requests** (spec §2).
///
/// A swap may only be requested for an **upcoming** shift — a past or already
/// in-progress shift can't be swapped. This is the single source of truth for
/// that rule, enforced in three layers: the request bottom sheet (immediate
/// feedback), [ShiftSwapCubit.requestSwap] (the authoritative client gate), and
/// `firestore.rules` (server backstop — see `swapSlotInFuture`).
///
/// A slot is addressed by (week, [ScheduleDay], [ScheduleShift]); its concrete
/// start instant is derived from the week's Sunday plus the day offset and the
/// **standing** shift start from [ShiftHours.standard] — so the swap gate tracks
/// the schedule's single source of truth (weekday night 15:00, weekend night
/// 16:00), never a hardcoded time. Per-week start overrides aren't reflected
/// here by design; this is a coarse "is the slot still in the future" gate.
class SwapEligibility {
  SwapEligibility._();

  /// The concrete start instant of the (week, [day], [shift]) slot. [weekStart]
  /// is the week's Sunday; [ScheduleDay] is ordered Sunday→Saturday, so its
  /// index is the day offset. The start minute comes from [ShiftHours.standard]
  /// (the same source attendance and the grid resolve through), keeping the
  /// gate in lockstep with the default schedule.
  static DateTime slotStart(
    DateTime weekStart,
    ScheduleDay day,
    ScheduleShift shift,
  ) {
    final base = DateTime(weekStart.year, weekStart.month, weekStart.day)
        .add(Duration(days: day.index));
    return base.add(
      Duration(minutes: ShiftHours.standard(day, shift).startMinutes),
    );
  }

  /// Whether a swap may be requested for this slot — true only when the shift's
  /// start is strictly in the future. Past shifts and a shift that has already
  /// started (or is exactly now) are rejected. [now] is injectable for tests.
  static bool isRequestable(
    DateTime weekStart,
    ScheduleDay day,
    ScheduleShift shift, {
    DateTime? now,
  }) =>
      slotStart(weekStart, day, shift).isAfter(now ?? DateTime.now());

  /// User-facing reason shown when [isRequestable] is false.
  static const String pastShiftMessage =
      'You can only request a swap for an upcoming shift — '
      'a past or in-progress shift can’t be swapped.';
}
