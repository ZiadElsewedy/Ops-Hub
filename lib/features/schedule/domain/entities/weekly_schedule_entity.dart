import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:opshub/core/enums/leave_type.dart';
import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/schedule/domain/shift_hours.dart';
import 'package:opshub/features/schedule/domain/shift_plan.dart';

part 'weekly_schedule_entity.freezed.dart';

/// A branch's weekly shift schedule (Phase 7) — the in-app replacement for the
/// Excel / WhatsApp roster. One document per (branch, week): the [weekStart] is
/// the Sunday at 00:00 that begins the week.
///
/// The roster is a nested map — `day → shift → [employee uids]` — so the same
/// employee can appear on any mix of morning / night slots across the week
/// (3 mornings, 3 nights, mixed, …). A manager owns their branch's schedule; an
/// admin can edit any. Access is enforced server-side in `firestore.rules`
/// (`weekly_schedules/{id}`): admin = all branches · manager = own branch ·
/// employee = read-only on their own branch.
@freezed
class WeeklyScheduleEntity with _$WeeklyScheduleEntity {
  const WeeklyScheduleEntity._();

  const factory WeeklyScheduleEntity({
    required String id,
    required String branchId,

    /// The Sunday (00:00) that starts this week.
    required DateTime weekStart,

    /// Roster: `day → shift → list of employee uids`.
    @Default(<ScheduleDay, Map<ScheduleShift, List<String>>>{})
    Map<ScheduleDay, Map<ScheduleShift, List<String>>> assignments,

    /// Manager note pinned to a day (Inventory · Big delivery · …); at most
    /// one short note per day — days without a note simply have no entry.
    @Default(<ScheduleDay, String>{}) Map<ScheduleDay, String> dayNotes,

    /// Day-level absences: `day → uid → leave type`. Leave is per **day**, not
    /// per shift — a person on leave is away for the whole day.
    @Default(<ScheduleDay, Map<String, LeaveType>>{})
    Map<ScheduleDay, Map<String, LeaveType>> leave,

    /// Per-week **shift-hours overrides**: `day → shift → hours`. Only slots
    /// that differ from [ShiftHours.standard] are stored — an empty map means
    /// the whole week runs standard hours. This is where configurable end times
    /// live (weekend lateness, Ramadan, holidays…): read through [hoursFor],
    /// never from a hardcoded weekend rule.
    @Default(<ScheduleDay, Map<ScheduleShift, ShiftHours>>{})
    Map<ScheduleDay, Map<ScheduleShift, ShiftHours>> shiftHours,

    /// The week's **frozen shift-hours snapshot** (Schedule V2 · Pillar 5),
    /// captured from the branch's shift templates when the week was created.
    /// Resolves *between* the per-slot [shiftHours] override and the hardcoded
    /// [ShiftHours.standard] fallback — see [hoursFor]. **Null on every legacy
    /// week**, which therefore resolves exactly as before (standard hours).
    ShiftPlan? shiftPlan,

    /// uid of the manager/admin who created the schedule.
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _WeeklyScheduleEntity;

  /// Employee uids assigned to a given [day] + [shift] (never null).
  List<String> employeesFor(ScheduleDay day, ScheduleShift shift) =>
      assignments[day]?[shift] ?? const [];

  /// Whether [uid] is assigned to [day] + [shift].
  bool isAssigned(String uid, ScheduleDay day, ScheduleShift shift) =>
      employeesFor(day, shift).contains(uid);

  /// All shifts [uid] works on [day] (may be empty, one, or both).
  List<ScheduleShift> shiftsFor(String uid, ScheduleDay day) => [
        for (final shift in ScheduleShift.values)
          if (isAssigned(uid, day, shift)) shift,
      ];

  /// Distinct employee uids scheduled anywhere on [day] (both shifts).
  Set<String> employeesOn(ScheduleDay day) => {
        for (final shift in ScheduleShift.values) ...employeesFor(day, shift),
      };

  /// The manager's note for [day], or null when there is none.
  String? noteFor(ScheduleDay day) {
    final note = dayNotes[day];
    return (note == null || note.trim().isEmpty) ? null : note;
  }

  /// The day note split into its individual instruction lines (trimmed, blanks
  /// dropped) — one bullet each. A note is a single stored string; managers
  /// write one instruction per line and each becomes a bullet. Empty when
  /// there is no note.
  List<String> noteLinesFor(ScheduleDay day) {
    final note = noteFor(day);
    if (note == null) return const [];
    return [
      for (final line in note.split('\n'))
        if (line.trim().isNotEmpty) line.trim(),
    ];
  }

  /// Everyone away on [day] (`uid → leave type`; never null).
  Map<String, LeaveType> leaveOn(ScheduleDay day) =>
      leave[day] ?? const <String, LeaveType>{};

  /// [uid]'s leave on [day], or null when they're available.
  LeaveType? leaveTypeOf(String uid, ScheduleDay day) => leaveOn(day)[uid];

  /// The **configured hours** for [day] + [shift] — the single entry point for
  /// every time display, countdown and midnight computation; nothing should read
  /// a hardcoded weekend end time. Resolution order (Schedule V2 · Pillar 5):
  ///  1. the per-slot [shiftHours] override the manager set this week;
  ///  2. else the week's frozen [shiftPlan] snapshot (from the branch templates
  ///     when the week was created);
  ///  3. else the hardcoded [ShiftHours.standard].
  ///
  /// A legacy week (null [shiftPlan], no override) skips step 2 → identical to
  /// the pre-template behaviour.
  ShiftHours hoursFor(ScheduleDay day, ScheduleShift shift) =>
      shiftHours[day]?[shift] ??
      shiftPlan?.forSlot(day, shift) ??
      ShiftHours.standard(day, shift);

  /// Whether [day]/[shift] carries a custom override (vs. the standing default).
  bool hasHoursOverride(ScheduleDay day, ScheduleShift shift) =>
      shiftHours[day]?[shift] != null;

  /// [uid]'s next assigned slot strictly **after** [day] within this week, or
  /// null when the week holds no further shifts. Drives the "Next shift · …"
  /// line on off/leave days.
  (ScheduleDay, ScheduleShift)? nextShiftAfter(String uid, ScheduleDay day) {
    for (final d in ScheduleDay.values) {
      if (d.index <= day.index) continue;
      final shifts = shiftsFor(uid, d);
      if (shifts.isNotEmpty) return (d, shifts.first);
    }
    return null;
  }
}
