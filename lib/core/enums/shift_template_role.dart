import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';

/// The standing role a shift template plays in a branch's week (Schedule V2 ·
/// Pillar 5). The three non-[custom] roles map exactly onto the slots the old
/// hardcoded `ShiftHours.standard` distinguished — morning, weekday night, and
/// the later weekend night — so a template set can *replace* that branching
/// without changing any behaviour. [custom] is reserved for future named
/// templates that aren't tied to a standing slot (data-model-ready, not yet
/// assigned per slot).
enum ShiftTemplateRole {
  morning,
  weekdayNight,
  weekendNight,
  custom;

  String get value => name;

  String get label => switch (this) {
        ShiftTemplateRole.morning => 'Morning',
        ShiftTemplateRole.weekdayNight => 'Weekday night',
        ShiftTemplateRole.weekendNight => 'Weekend night',
        ShiftTemplateRole.custom => 'Custom',
      };

  /// Parses the stored string; unknown/null → [custom] (a safe, unassigned role).
  static ShiftTemplateRole fromString(String? raw) {
    for (final r in values) {
      if (r.name == raw) return r;
    }
    return ShiftTemplateRole.custom;
  }

  /// The standing role that governs a (day, shift) slot — the single mapping
  /// that replaces the old `if (shift == morning) … else if (day.isWeekend) …`
  /// branching. Night on the operational weekend (Thu/Fri/Sat) → [weekendNight];
  /// every other night → [weekdayNight]; any morning → [morning].
  static ShiftTemplateRole forSlot(ScheduleDay day, ScheduleShift shift) =>
      shift == ScheduleShift.morning
          ? ShiftTemplateRole.morning
          : (day.isWeekend
              ? ShiftTemplateRole.weekendNight
              : ShiftTemplateRole.weekdayNight);
}
