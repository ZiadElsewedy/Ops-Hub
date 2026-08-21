import 'package:opshub/features/attendance/domain/entities/attendance_entity.dart';

/// Pure attendance analytics over a snapshot of records — no Flutter, no
/// Firestore, so it recomputes instantly with a stream and is fully unit-testable
/// (mirrors `RequestMetrics` / `task_metrics`). The cubits feed it a **bounded**
/// window of records (a day / week / month) to keep reads in check; sorting for
/// "top employees" / "problem branches" is left to the caller over [byUser] /
/// [byBranch].
class AttendanceStats {
  final int totalRecords;

  /// Showed up (in-progress, completed, approved, or pending review).
  final int presentCount;

  /// Rostered but didn't show.
  final int absentCount;

  /// Rostered no-shows a manager forgave (a materialized `excused` record) —
  /// distinct from [absentCount] and excluded from the attendance-rate
  /// denominator (a forgiven absence isn't held against the rate).
  final int excusedCount;
  final int lateCount;
  final int earlyLeaveCount;

  /// Records with a clock-out (worked minutes are final for these).
  final int completedCount;
  final int workedMinutes;
  final int overtimeMinutes;

  /// Average clock-in time as minutes-past-midnight (null when nobody clocked
  /// in). Note: for overnight shifts a post-midnight clock-out wraps to a small
  /// minute-of-day — [avgLeaveMinuteOfDay] is a rough indicator, not payroll.
  final double? avgArrivalMinuteOfDay;
  final double? avgLeaveMinuteOfDay;

  final int currentStreak;
  final int longestStreak;

  const AttendanceStats({
    this.totalRecords = 0,
    this.presentCount = 0,
    this.absentCount = 0,
    this.excusedCount = 0,
    this.lateCount = 0,
    this.earlyLeaveCount = 0,
    this.completedCount = 0,
    this.workedMinutes = 0,
    this.overtimeMinutes = 0,
    this.avgArrivalMinuteOfDay,
    this.avgLeaveMinuteOfDay,
    this.currentStreak = 0,
    this.longestStreak = 0,
  });

  static const AttendanceStats empty = AttendanceStats();

  /// Attendance rate — present of everyone expected (present + absent). Leave and
  /// not-yet-started days don't count against it. 0 when nobody was expected.
  double get attendancePercent {
    final expected = presentCount + absentCount;
    return expected == 0 ? 0 : (presentCount / expected) * 100;
  }

  /// Share of the people who showed up who were late.
  double get latePercent =>
      presentCount == 0 ? 0 : (lateCount / presentCount) * 100;

  /// Average worked minutes across completed (clocked-out) records.
  double get avgWorkedMinutes =>
      completedCount == 0 ? 0 : workedMinutes / completedCount;

  factory AttendanceStats.from(
    List<AttendanceEntity> records, {
    DateTime? asOf,
  }) {
    var present = 0,
        absent = 0,
        excused = 0,
        late = 0,
        early = 0,
        completed = 0,
        worked = 0,
        overtime = 0;
    var arrivalSum = 0, arrivalN = 0, leaveSum = 0, leaveN = 0;
    final presentDates = <DateTime>[];

    for (final r in records) {
      if (r.isDeleted) continue;
      if (r.status.isAbsence) absent++;
      if (r.isExcused) excused++;
      if (r.isPresent) {
        present++;
        presentDates.add(r.date);
      }
      if (r.isLate) late++;
      if (r.hasEarlyLeave) early++;
      if (r.hasClockedOut) {
        completed++;
        worked += r.workedMinutes;
      }
      overtime += r.overtimeMinutes;
      final ci = r.clockIn;
      if (ci != null) {
        arrivalSum += ci.hour * 60 + ci.minute;
        arrivalN++;
      }
      final co = r.clockOut;
      if (co != null) {
        leaveSum += co.hour * 60 + co.minute;
        leaveN++;
      }
    }

    final streaks = attendanceStreaks(presentDates, asOf: asOf);
    return AttendanceStats(
      totalRecords: records.where((r) => !r.isDeleted).length,
      presentCount: present,
      absentCount: absent,
      excusedCount: excused,
      lateCount: late,
      earlyLeaveCount: early,
      completedCount: completed,
      workedMinutes: worked,
      overtimeMinutes: overtime,
      avgArrivalMinuteOfDay: arrivalN == 0 ? null : arrivalSum / arrivalN,
      avgLeaveMinuteOfDay: leaveN == 0 ? null : leaveSum / leaveN,
      currentStreak: streaks.current,
      longestStreak: streaks.longest,
    );
  }

  /// Per-employee stats (`userId → stats`) — the basis for a "top employees"
  /// board (caller sorts by whatever metric it wants).
  static Map<String, AttendanceStats> byUser(
    List<AttendanceEntity> records, {
    DateTime? asOf,
  }) =>
      _groupBy(records, (r) => r.userId, asOf: asOf);

  /// Per-branch stats (`branchId → stats`) — the basis for a "problem branches"
  /// board.
  static Map<String, AttendanceStats> byBranch(
    List<AttendanceEntity> records, {
    DateTime? asOf,
  }) =>
      _groupBy(records, (r) => r.branchId ?? '', asOf: asOf);

  static Map<String, AttendanceStats> _groupBy(
    List<AttendanceEntity> records,
    String Function(AttendanceEntity) key, {
    DateTime? asOf,
  }) {
    final buckets = <String, List<AttendanceEntity>>{};
    for (final r in records) {
      if (r.isDeleted) continue;
      buckets.putIfAbsent(key(r), () => []).add(r);
    }
    return {
      for (final e in buckets.entries)
        e.key: AttendanceStats.from(e.value, asOf: asOf),
    };
  }
}

/// Consecutive-day attendance streaks over the calendar days in [dates].
///
/// * `longest` — the longest run of consecutive calendar days present, ever.
/// * `current` — the run ending on the most recent present day. When [asOf] is
///   given and the most recent present day is older than *yesterday*, the current
///   streak is considered broken (0).
///
/// Calendar-day math is done on UTC-normalized dates so a DST transition can't
/// make two adjacent local midnights read as 0 or 2 days apart.
({int current, int longest}) attendanceStreaks(
  Iterable<DateTime> dates, {
  DateTime? asOf,
}) {
  final days = <DateTime>{for (final d in dates) _utcDay(d)}.toList()..sort();
  if (days.isEmpty) return (current: 0, longest: 0);

  var longest = 1, run = 1;
  for (var i = 1; i < days.length; i++) {
    run = days[i].difference(days[i - 1]).inDays == 1 ? run + 1 : 1;
    if (run > longest) longest = run;
  }

  var current = 1;
  for (var i = days.length - 1; i > 0; i--) {
    if (days[i].difference(days[i - 1]).inDays == 1) {
      current++;
    } else {
      break;
    }
  }

  if (asOf != null && _utcDay(asOf).difference(days.last).inDays > 1) {
    current = 0;
  }
  return (current: current, longest: longest);
}

DateTime _utcDay(DateTime d) => DateTime.utc(d.year, d.month, d.day);
