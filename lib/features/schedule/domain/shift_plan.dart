import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/enums/shift_template_role.dart';
import 'package:opshub/features/schedule/domain/shift_hours.dart';

/// A week's **frozen snapshot** of the three standing shift hours — morning,
/// weekday night and weekend night (Schedule V2 · Pillar 5). Captured onto a
/// `weekly_schedules/{id}` doc **at creation** from the branch's current shift
/// templates, so a later template edit can never rewrite that week's history.
///
/// It is the resolution layer *between* the sparse per-slot override
/// (`shiftHours[day][shift]`) and the hardcoded `ShiftHours.standard` fallback —
/// a week with no plan (every legacy schedule) resolves exactly as before.
class ShiftPlan {
  const ShiftPlan({
    required this.morning,
    required this.weekdayNight,
    required this.weekendNight,
  });

  final ShiftHours morning;
  final ShiftHours weekdayNight;
  final ShiftHours weekendNight;

  /// The plan matching the historical hardcoded [ShiftHours.standard], so a
  /// branch that adopts templates begins byte-identical to before.
  factory ShiftPlan.standard() => ShiftPlan(
        morning:
            ShiftHours.standard(ScheduleDay.sunday, ScheduleShift.morning),
        weekdayNight:
            ShiftHours.standard(ScheduleDay.sunday, ScheduleShift.night),
        weekendNight:
            ShiftHours.standard(ScheduleDay.thursday, ScheduleShift.night),
      );

  /// The hours this plan gives a (day, shift) slot — the same weekday/weekend
  /// night split `ShiftHours.standard` used, now data-driven.
  ShiftHours forSlot(ScheduleDay day, ScheduleShift shift) =>
      forRole(ShiftTemplateRole.forSlot(day, shift));

  ShiftHours forRole(ShiftTemplateRole role) => switch (role) {
        ShiftTemplateRole.morning => morning,
        ShiftTemplateRole.weekendNight => weekendNight,
        // A custom role has no standing slot; fall back to weekday night.
        ShiftTemplateRole.weekdayNight ||
        ShiftTemplateRole.custom =>
          weekdayNight,
      };

  ShiftPlan withRole(ShiftTemplateRole role, ShiftHours hours) => switch (role) {
        ShiftTemplateRole.morning => ShiftPlan(
            morning: hours,
            weekdayNight: weekdayNight,
            weekendNight: weekendNight),
        ShiftTemplateRole.weekdayNight => ShiftPlan(
            morning: morning, weekdayNight: hours, weekendNight: weekendNight),
        ShiftTemplateRole.weekendNight => ShiftPlan(
            morning: morning, weekdayNight: weekdayNight, weekendNight: hours),
        ShiftTemplateRole.custom => this,
      };

  Map<String, dynamic> toMap() => {
        'morning': morning.toMap(),
        'weekdayNight': weekdayNight.toMap(),
        'weekendNight': weekendNight.toMap(),
      };

  /// Parses `{morning, weekdayNight, weekendNight}`; any missing/malformed slot
  /// falls back to its [ShiftPlan.standard] value (never invents nonsense). A
  /// non-map (absent field on a legacy doc) → null, so the week resolves as
  /// before.
  static ShiftPlan? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final std = ShiftPlan.standard();
    return ShiftPlan(
      morning: ShiftHours.fromMap(raw['morning']) ?? std.morning,
      weekdayNight: ShiftHours.fromMap(raw['weekdayNight']) ?? std.weekdayNight,
      weekendNight: ShiftHours.fromMap(raw['weekendNight']) ?? std.weekendNight,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ShiftPlan &&
      other.morning == morning &&
      other.weekdayNight == weekdayNight &&
      other.weekendNight == weekendNight;

  @override
  int get hashCode => Object.hash(morning, weekdayNight, weekendNight);

  @override
  String toString() =>
      'ShiftPlan(M $morning · WkN $weekdayNight · WkndN $weekendNight)';
}
