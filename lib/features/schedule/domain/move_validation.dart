import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:opshub/features/schedule/domain/swap_policy.dart';

/// Pure, framework-free validation for the manager/admin **direct roster
/// edits** (Schedule 4.0): drag-to-move, drag-to-switch, and the mobile
/// move/swap flows. Returns `null` when the edit is legal or a **user-facing
/// reason** when it isn't — the UI surfaces the reason, never fails silently.
///
/// Scope note (settled product rulings):
///   - Double-booking is the one hard conflict the one-slot-per-shift model
///     can express — it is **blocked**, matching the insight strip's red cue.
///   - Position compatibility applies only to an **exchange** (someone replaces
///     someone) and only when the branch's [SwapPolicy] restricts it — the same
///     policy already governing employee-initiated swaps, so manager edits and
///     employee swaps can never disagree about what "compatible" means.
///   - There is **no staffing quota**: emptying a shift is information for the
///     manager's judgment (see [wouldEmptySlot] — a confirm, not a block),
///     consistent with the facts-not-quotas insight design.
class MoveValidation {
  MoveValidation._();

  /// Validates moving [uid] from (fromDay, fromShift) to (toDay, toShift).
  /// [name] personalises the reason. Returns `null` when legal.
  static String? checkMove({
    required WeeklyScheduleEntity schedule,
    required String uid,
    required String name,
    required ScheduleDay fromDay,
    required ScheduleShift fromShift,
    required ScheduleDay toDay,
    required ScheduleShift toShift,
  }) {
    // Same slot — nothing to do (callers treat this as a quiet no-op, but a
    // reason keeps the "never silent" contract for explicit flows).
    if (fromDay == toDay && fromShift == toShift) {
      return '$name is already on this shift.';
    }
    if (schedule.isAssigned(uid, toDay, toShift)) {
      return '$name is already on the ${toShift.label.toLowerCase()} shift '
          'on ${toDay.label}.';
    }
    // Double-booking: after the move, would they hold BOTH shifts of the
    // target day? The source slot is vacated, so it never counts.
    final otherSlot = (toDay, toShift.opposite);
    final vacating = (fromDay, fromShift) == otherSlot;
    if (!vacating && schedule.isAssigned(uid, toDay, toShift.opposite)) {
      return 'That would put $name on both shifts on ${toDay.label} — '
          'move their ${toShift.opposite.label.toLowerCase()} shift first.';
    }
    return null;
  }

  /// Validates trading [uidA]'s (dayA, shiftA) with [uidB]'s (dayB, shiftB).
  /// Applies the branch [policy]'s position rule — the same rule employee
  /// swaps obey. Returns `null` when legal.
  static String? checkExchange({
    required WeeklyScheduleEntity schedule,
    required String uidA,
    required String nameA,
    required ScheduleDay dayA,
    required ScheduleShift shiftA,
    required String uidB,
    required String nameB,
    required ScheduleDay dayB,
    required ScheduleShift shiftB,
    String? positionA,
    String? positionB,
    SwapPolicy policy = SwapPolicy.permissive,
  }) {
    if (uidA == uidB) return null; // self-swap is a quiet no-op upstream
    if (dayA == dayB && shiftA == shiftB) {
      return '$nameA and $nameB are already on the same shift.';
    }
    if (!policy.positionsCompatible(positionA, positionB)) {
      final pa = (positionA ?? '').trim();
      final pb = (positionB ?? '').trim();
      return 'Branch policy allows same-position switches only '
          '($pa ↔ $pb isn\'t compatible).';
    }
    // Post-trade double-booking, either side. A side's OLD slot is vacated,
    // so it never counts against them.
    final a = _doubleBookAfterTrade(
        schedule, uidA, from: (dayA, shiftA), to: (dayB, shiftB));
    if (a != null) {
      return 'That would put $nameA on both shifts on ${a.label}.';
    }
    final b = _doubleBookAfterTrade(
        schedule, uidB, from: (dayB, shiftB), to: (dayA, shiftA));
    if (b != null) {
      return 'That would put $nameB on both shifts on ${b.label}.';
    }
    return null;
  }

  /// Whether removing [uid] from (day, shift) — by move, trade, or removal —
  /// leaves that slot with no one. A **fact for a confirm dialog**, not a
  /// blocking rule (facts, never quotas).
  static bool wouldEmptySlot({
    required WeeklyScheduleEntity schedule,
    required String uid,
    required ScheduleDay day,
    required ScheduleShift shift,
  }) {
    final assigned = schedule.employeesFor(day, shift);
    return assigned.length == 1 && assigned.contains(uid);
  }

  /// The day [uid] would be double-booked on after leaving [from] and taking
  /// [to], or null when clean.
  static ScheduleDay? _doubleBookAfterTrade(
    WeeklyScheduleEntity schedule,
    String uid, {
    required (ScheduleDay, ScheduleShift) from,
    required (ScheduleDay, ScheduleShift) to,
  }) {
    final (toDay, toShift) = to;
    final other = (toDay, toShift.opposite);
    if (other == from) return null; // vacated by this very trade
    if (schedule.isAssigned(uid, toDay, toShift.opposite)) return toDay;
    return null;
  }
}
