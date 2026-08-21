/// The seven days of a weekly schedule (Phase 7). OpsHub weeks start on
/// **Sunday** (matching the operations calendar), so the enum is ordered
/// Sunday → Saturday and that order is the canonical index used throughout the
/// schedule UI and serialization.
///
/// Stored lower-case in `weekly_schedules/{id}.assignments.<day>.<shift>`.
enum ScheduleDay {
  sunday,
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday;

  /// The string persisted in Firestore (the lower-case name).
  String get value => name;

  /// Capitalized day name for the UI (e.g. `Sunday`).
  String get label => '${name[0].toUpperCase()}${name.substring(1)}';

  /// Three-letter label for compact rows (e.g. `Sun`).
  String get shortLabel => label.substring(0, 3);

  /// The operations weekend — **Thursday · Friday · Saturday** — when the shop
  /// stays open later (night shift runs 16:00–00:00 instead of 15:00–23:00).
  bool get isWeekend =>
      this == ScheduleDay.thursday ||
      this == ScheduleDay.friday ||
      this == ScheduleDay.saturday;

  /// Parses the stored string; unknown/missing → [sunday].
  static ScheduleDay fromString(String? raw) {
    for (final d in values) {
      if (d.name == raw) return d;
    }
    return sunday;
  }

  /// Maps a date to its schedule day. `DateTime.weekday` is Mon=1…Sun=7, and
  /// `weekday % 7` gives Sun=0…Sat=6 — exactly this enum's index order.
  static ScheduleDay fromDate(DateTime date) => values[date.weekday % 7];

  /// The schedule day for the current date.
  static ScheduleDay today() => fromDate(DateTime.now());
}
