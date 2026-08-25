import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:opshub/features/schedule/domain/shift_hours.dart';
import 'package:opshub/features/schedule/domain/swap_policy.dart';

/// Pure, framework-free validation for the **shift-swap exchange** (2026-06-25
/// hardening). Given the current weekly schedule + a proposed exchange (the
/// requester trades their (day, shift) slot for the target's opposite-shift slot
/// on the same day), [SwapValidation.check] returns `null` when the swap is legal
/// or a **user-facing reason** when it isn't.
///
/// This is the single canonical definition of the swap rules. It is consumed by
/// the client at request time (instant feedback in the request sheet) and is
/// **mirrored in `functions/index.js` (`approveSwap`)**, which re-runs the same
/// checks authoritatively at approval time against the freshest schedule — the
/// TOCTOU backstop. Keep the two in sync (same contract as `SwapEligibility` ↔
/// `firestore.rules`'s `swapSlotInFuture`).
class SwapValidation {
  SwapValidation._();

  /// Shift start/end as minutes past the slot day's midnight, read from
  /// [ShiftHours.standard] (the single source of truth) so the rest-gap check
  /// tracks the real schedule: morning 08:30–16:30, weekday night 15:00–23:00,
  /// weekend night 16:00–00:00 (end `1440`, i.e. next-day midnight). Day-aware
  /// because weekday and weekend nights now differ.
  static (int start, int end) shiftMinutes(ScheduleDay day, ScheduleShift s) {
    final h = ShiftHours.standard(day, s);
    return (h.startMinutes, h.endMinutes);
  }

  /// Validates the proposed exchange. Returns `null` if legal, else the reason.
  ///
  /// [requesterShift] is the slot the requester is giving up; the target's slot is
  /// always the opposite shift on the same [day] (only two shifts exist).
  static String? check({
    required WeeklyScheduleEntity schedule,
    required ScheduleDay day,
    required ScheduleShift requesterShift,
    required String requesterId,
    required String targetId,
    String? requesterPosition,
    String? targetPosition,
    SwapPolicy policy = SwapPolicy.permissive,
  }) {
    final opposite = requesterShift.opposite;

    // 1) Slot integrity (TOCTOU): both employees must still hold the slots the
    //    swap was built on. A roster edit between request and approval lands here.
    if (!schedule.isAssigned(requesterId, day, requesterShift)) {
      return 'The schedule changed — you’re no longer on the '
          '${requesterShift.label.toLowerCase()} shift this day.';
    }
    if (!schedule.isAssigned(targetId, day, opposite)) {
      return 'The schedule changed — your coworker is no longer on the '
          '${opposite.label.toLowerCase()} shift this day.';
    }

    // 2) Role compatibility (branch policy).
    if (!policy.positionsCompatible(requesterPosition, targetPosition)) {
      return 'You can only swap with a coworker in a compatible role.';
    }

    // 3) Post-exchange checks for both employees: no double-booking, and (if the
    //    branch sets it) enough rest between shifts.
    for (final uid in {requesterId, targetId}) {
      final slots =
          _slotsAfter(schedule, day, requesterShift, requesterId, targetId, uid);
      if (_onBothShifts(slots, day)) {
        return 'This swap would double-book someone on the same day.';
      }
      final rest = policy.minRestHours;
      if (rest != null && _minGapMinutes(slots) < rest * 60) {
        return 'This swap would leave less than $rest hours of rest between shifts.';
      }
    }
    return null;
  }

  /// Every (day, shift) [uid] is assigned to across the week **after** applying
  /// the exchange. The exchange only mutates [day]: the requester moves
  /// [requesterShift] → opposite; the target moves opposite → [requesterShift].
  static List<(ScheduleDay, ScheduleShift)> _slotsAfter(
    WeeklyScheduleEntity schedule,
    ScheduleDay day,
    ScheduleShift requesterShift,
    String requesterId,
    String targetId,
    String uid,
  ) {
    final opposite = requesterShift.opposite;
    final slots = <(ScheduleDay, ScheduleShift)>[];
    for (final d in ScheduleDay.values) {
      for (final s in ScheduleShift.values) {
        var assigned = schedule.isAssigned(uid, d, s);
        if (d == day) {
          if (uid == requesterId) {
            if (s == requesterShift) assigned = false;
            if (s == opposite) assigned = true;
          } else if (uid == targetId) {
            if (s == opposite) assigned = false;
            if (s == requesterShift) assigned = true;
          }
        }
        if (assigned) slots.add((d, s));
      }
    }
    return slots;
  }

  static bool _onBothShifts(
          List<(ScheduleDay, ScheduleShift)> slots, ScheduleDay day) =>
      slots.contains((day, ScheduleShift.morning)) &&
      slots.contains((day, ScheduleShift.night));

  /// Smallest gap (minutes) between any two of the employee's shifts in the week
  /// (intervals can't overlap once double-booking is excluded). Fewer than two
  /// shifts → no constraint (a large sentinel). Week-bounded by design — rest
  /// across the Sat→next-Sun boundary isn't modelled (the adjacent week isn't
  /// loaded); this is the documented "lightweight" scope.
  static int _minGapMinutes(List<(ScheduleDay, ScheduleShift)> slots) {
    final intervals = <(int start, int end)>[];
    for (final (d, s) in slots) {
      final (sm, em) = shiftMinutes(d, s);
      intervals.add((d.index * 1440 + sm, d.index * 1440 + em));
    }
    if (intervals.length < 2) return 1 << 30;
    intervals.sort((a, b) => a.$1.compareTo(b.$1));
    var minGap = 1 << 30;
    for (var i = 1; i < intervals.length; i++) {
      final gap = intervals[i].$1 - intervals[i - 1].$2;
      if (gap < minGap) minGap = gap;
    }
    return minGap;
  }
}
