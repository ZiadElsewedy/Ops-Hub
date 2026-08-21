import 'package:opshub/core/enums/schedule_day.dart';

/// Week-math helpers for the weekly schedule (Phase 7). A "week" is identified by
/// its **start date** — the Sunday at 00:00 — so a branch has exactly one
/// schedule document per week, addressed by a deterministic id
/// (`<branchId>_<yyyy-MM-dd>`). This avoids duplicate weekly docs and lets the
/// app read a week directly without a query.
class ScheduleWeek {
  ScheduleWeek._();

  /// The Sunday (00:00) that starts the week containing [date]. `DateTime.weekday`
  /// is Mon=1…Sun=7, so `weekday % 7` is the number of days since Sunday.
  static DateTime startOf(DateTime date) {
    final midnight = DateTime(date.year, date.month, date.day);
    return midnight.subtract(Duration(days: date.weekday % 7));
  }

  /// The start (Sunday) of the current week.
  static DateTime currentWeekStart() => startOf(DateTime.now());

  /// Deterministic document id for a branch's schedule in a given week.
  static String docId(String branchId, DateTime weekStart) {
    final w = startOf(weekStart);
    return '${branchId}_${_iso(w)}';
  }

  /// `Sun dd/MM – Sat dd/MM` label for the week selector.
  static String rangeLabel(DateTime weekStart) {
    final start = startOf(weekStart);
    final end = start.add(const Duration(days: 6));
    return '${_two(start.day)}/${_two(start.month)} – '
        '${_two(end.day)}/${_two(end.month)}';
  }

  static bool isSameWeek(DateTime a, DateTime b) =>
      startOf(a) == startOf(b);

  /// Whether the [day] column of the week beginning [weekStart] is the real
  /// calendar **today** — an exact year/month/day match, never a weekday-only
  /// one. Returns `false` for every day when a *different* week is displayed, so
  /// the schedule only ever highlights "Today" on the week that actually
  /// contains it. [now] is injectable for tests.
  static bool isToday(DateTime weekStart, ScheduleDay day, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final date = startOf(weekStart).add(Duration(days: day.index));
    return date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
  }

  static String _iso(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
  static String _two(int n) => n.toString().padLeft(2, '0');
}
