import 'package:opshub/core/enums/schedule_shift.dart';

/// The shift lens applied on the Branch Operations cockpit — `[ All ][ Morning ]
/// [ Night ]`. It is *not* a navigation step (no shift screen); it's a filter
/// held in cubit state and applied as a pure re-derivation over the same branch
/// data, so toggling is instant (no Firestore round-trip).
enum ShiftFilter {
  all,
  morning,
  night;

  /// The concrete [ScheduleShift] this filter targets, or null for [all].
  ScheduleShift? get shift => switch (this) {
        ShiftFilter.all => null,
        ShiftFilter.morning => ScheduleShift.morning,
        ShiftFilter.night => ScheduleShift.night,
      };

  /// Whether a task tagged with [taskShift] (null = "any", not shift-specific)
  /// is visible under this filter. [all] shows everything; a specific shift
  /// shows tasks for that shift **plus** shift-agnostic ("any") tasks.
  bool matchesTask(ScheduleShift? taskShift) =>
      this == ShiftFilter.all || taskShift == null || taskShift == shift;

  /// Whether an employee working [shiftsToday] is visible under this filter.
  /// [all] shows everyone; a specific shift shows only those rostered on it.
  bool matchesEmployee(List<ScheduleShift> shiftsToday) =>
      this == ShiftFilter.all || shiftsToday.contains(shift);

  String get label => switch (this) {
        ShiftFilter.all => 'All',
        ShiftFilter.morning => 'Morning',
        ShiftFilter.night => 'Night',
      };
}
