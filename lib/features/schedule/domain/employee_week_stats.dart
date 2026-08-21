import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/features/schedule/domain/entities/weekly_schedule_entity.dart';

/// One person's week at a glance — the facts the inspector drawer shows when a
/// manager selects an employee. Pure and cheap (one pass over 7 days): worked
/// hours (from the week's resolved [ShiftHours], overnight-aware), days worked,
/// the longest run of consecutive days, and which days are off.
/// **Read-only derivation — no persistence, no policy.**
///
/// Deliberately does **not** expose a morning/night split or a per-day shift
/// pattern: an owner ruling (2026-07-15) is that *how many days* someone works
/// is an operational fact, while *which shift types they string together* is
/// noise the roster grid already shows.
class EmployeeWeekStats {
  const EmployeeWeekStats({
    required this.workedDays,
    required this.weekendCount,
    required this.totalMinutes,
    required this.longestRun,
    required this.offDays,
  });

  /// Number of days with at least one shift.
  final int workedDays;

  /// Weekend **days** worked (Thu/Fri/Sat — [ScheduleDay.isWeekend]), not shifts.
  final int weekendCount;

  /// Total scheduled minutes across the week (each shift's resolved duration,
  /// so an overnight close counts its real length).
  final int totalMinutes;

  /// Longest run of consecutive worked days (any shift).
  final int longestRun;

  /// The days with no shift, in week order.
  final List<ScheduleDay> offDays;

  /// `"40h"` / `"40h 30m"` — the whole-week total in a compact label.
  String get hoursLabel {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  bool get isEmpty => workedDays == 0;
}

/// Computes [EmployeeWeekStats] for [uid] in one pass over the week, using the
/// schedule's resolved per-slot hours (`hoursFor`, override ?? standard).
EmployeeWeekStats computeEmployeeWeekStats(
  WeeklyScheduleEntity schedule,
  String uid,
) {
  var worked = 0;
  var weekend = 0;
  var minutes = 0;
  var run = 0;
  var longestRun = 0;
  final offDays = <ScheduleDay>[];

  for (final day in ScheduleDay.values) {
    final shifts = schedule.shiftsFor(uid, day);
    if (shifts.isEmpty) {
      offDays.add(day);
      run = 0;
      continue;
    }
    worked++;
    run++;
    if (run > longestRun) longestRun = run;
    for (final shift in shifts) {
      minutes += schedule.hoursFor(day, shift).durationMinutes;
    }
    if (day.isWeekend) weekend++;
  }

  return EmployeeWeekStats(
    workedDays: worked,
    weekendCount: weekend,
    totalMinutes: minutes,
    longestRun: longestRun,
    offDays: offDays,
  );
}
