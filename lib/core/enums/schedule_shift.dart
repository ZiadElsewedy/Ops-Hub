import 'package:opshub/core/enums/schedule_day.dart';

/// The two daily shift slots a weekly schedule fills (Phase 7) — **Morning** and
/// **Night**, reusing the V1 shift names from Phase 2 (`morning` / `night`).
/// Stored lower-case in `weekly_schedules/{id}.assignments.<day>.<shift>`.
enum ScheduleShift {
  morning,
  night;

  /// The string persisted in Firestore (the lower-case name).
  String get value => name;

  /// Capitalized label for the UI (e.g. `Morning`).
  String get label => '${name[0].toUpperCase()}${name.substring(1)}';

  /// The other shift — there are only two, so a swap exchanges a slot for its
  /// opposite (morning ⇄ night). Drives the shift-swap exchange.
  ScheduleShift get opposite =>
      this == ScheduleShift.morning ? ScheduleShift.night : ScheduleShift.morning;

  /// Human-readable default hours (mirrors `ShiftHours.standard`, the single
  /// source of truth). Display only — the schedule itself stores who works, not
  /// the clock times; the generic night label reflects the weekday default.
  String get timeRange =>
      this == ScheduleShift.morning ? '08:30 – 16:30' : '15:00 – 23:00';

  /// Per-day hours: weekend nights (Thu/Fri/Sat — [ScheduleDay.isWeekend]) run
  /// **16:00–00:00** (till midnight); every other slot keeps [timeRange].
  /// Display only — mirrors `ShiftHours.standard`.
  String timeRangeOn(ScheduleDay day) =>
      this == ScheduleShift.night && day.isWeekend
          ? '16:00 – 00:00'
          : timeRange;

  /// Shift start as minutes past midnight (08:30 → 510 · 15:00 → 900) — the
  /// structured counterpart of [timeRange]. Keep in sync with `ShiftHours.standard`.
  int get startMinutes => this == ScheduleShift.morning ? 510 : 900;

  /// Shift end as minutes past the **slot day's** midnight. Weekend nights end
  /// 00:00 the next calendar day, so their value is 24h (1440) — callers adding
  /// it as a [Duration] roll into the next day automatically. Keep in sync with
  /// [timeRangeOn] and `ShiftHours.standard`.
  int endMinutesOn(ScheduleDay day) => this == ScheduleShift.morning
      ? 990
      : (day.isWeekend ? 1440 : 1380);

  /// Parses the stored string; unknown/missing → [morning].
  static ScheduleShift fromString(String? raw) =>
      raw == 'night' ? ScheduleShift.night : ScheduleShift.morning;

  /// Parses the stored string **preserving absence** — `morning`/`night` map to
  /// the shift, anything else (including null) → null. Used for an *optional*
  /// shift tag (e.g. a task that may not be shift-specific), where the lossy
  /// [fromString] default would wrongly coerce a missing value to morning.
  static ScheduleShift? fromStringOrNull(String? raw) => switch (raw) {
        'morning' => ScheduleShift.morning,
        'night' => ScheduleShift.night,
        _ => null,
      };
}
