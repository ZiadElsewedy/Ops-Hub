import 'package:drop/core/enums/attendance_status.dart';
import 'package:drop/core/enums/attendance_status_filter.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/features/attendance/domain/attendance_id.dart';
import 'package:drop/features/attendance/domain/entities/attendance_entity.dart';

/// The date window a history view is scoped to. `custom` carries an explicit
/// start/end; the presets are resolved against `now` in [AttendanceHistoryQuery].
enum AttendanceDateRange {
  last7Days,
  last30Days,
  thisWeek,
  thisMonth,
  lastMonth,
  custom;

  String get label => switch (this) {
    AttendanceDateRange.last7Days => 'Last 7 days',
    AttendanceDateRange.last30Days => 'Last 30 days',
    AttendanceDateRange.thisWeek => 'This week',
    AttendanceDateRange.thisMonth => 'This month',
    AttendanceDateRange.lastMonth => 'Last month',
    AttendanceDateRange.custom => 'Custom',
  };
}

/// An inclusive day window `[start, end]` (local calendar days). `start` is that
/// day's midnight; `end` is the last instant of its day.
typedef DateWindow = ({DateTime start, DateTime end});

/// A **pure, composable** description of what the Attendance History ledger
/// should show — a date window plus status / shift / name facets. No Flutter, no
/// Firestore, so it is unit-tested directly and reused unchanged by both the
/// employee self-history and the manager/admin branch-review surfaces.
///
/// The screen owns *where the records come from* (the employee's own history vs.
/// a branch range); this owns *which of them survive* and *how to bound a server
/// range query* ([startKey] / [endKey]). Facets are additive — an empty
/// [shifts] means "any shift", [AttendanceStatusFilter.all] means "any status",
/// an empty [text] means "any name".
class AttendanceHistoryQuery {
  final AttendanceDateRange range;

  /// Explicit bounds for [AttendanceDateRange.custom] (ignored otherwise). When
  /// custom is selected but a bound is missing, the resolver falls back to the
  /// current month so the UI never queries an unbounded window.
  final DateTime? customStart;
  final DateTime? customEnd;

  final AttendanceStatusFilter status;

  /// Empty = every shift. Otherwise the record's [ScheduleShift] must be in the set.
  final Set<ScheduleShift> shifts;

  /// Case-insensitive substring match against the record's denormalized
  /// `userName` (the reviewer's employee search). Empty = every employee.
  final String text;

  const AttendanceHistoryQuery({
    this.range = AttendanceDateRange.thisMonth,
    this.customStart,
    this.customEnd,
    this.status = AttendanceStatusFilter.all,
    this.shifts = const <ScheduleShift>{},
    this.text = '',
  });

  AttendanceHistoryQuery copyWith({
    AttendanceDateRange? range,
    DateTime? customStart,
    DateTime? customEnd,
    AttendanceStatusFilter? status,
    Set<ScheduleShift>? shifts,
    String? text,
  }) => AttendanceHistoryQuery(
    range: range ?? this.range,
    customStart: customStart ?? this.customStart,
    customEnd: customEnd ?? this.customEnd,
    status: status ?? this.status,
    shifts: shifts ?? this.shifts,
    text: text ?? this.text,
  );

  /// True when nothing narrows the ledger — used to pick an "all clear" vs. a
  /// "no matches" empty state.
  bool get hasFacets =>
      status != AttendanceStatusFilter.all ||
      shifts.isNotEmpty ||
      text.trim().isNotEmpty;

  /// Resolve the date [range] to an inclusive `[start, end]` day window against
  /// [now]. Weeks start Monday; month presets span the whole calendar month.
  DateWindow resolveRange(DateTime now) {
    switch (range) {
      case AttendanceDateRange.last7Days:
        final end = _startOfDay(now);
        return (
          start: end.subtract(const Duration(days: 6)),
          end: _endOfDay(end),
        );
      case AttendanceDateRange.last30Days:
        final end = _startOfDay(now);
        return (
          start: end.subtract(const Duration(days: 29)),
          end: _endOfDay(end),
        );
      case AttendanceDateRange.thisWeek:
        final monday = _startOfDay(
          now,
        ).subtract(Duration(days: now.weekday - 1));
        return (
          start: monday,
          end: _endOfDay(monday.add(const Duration(days: 6))),
        );
      case AttendanceDateRange.thisMonth:
        return _monthWindow(now.year, now.month);
      case AttendanceDateRange.lastMonth:
        final m = now.month == 1 ? 12 : now.month - 1;
        final y = now.month == 1 ? now.year - 1 : now.year;
        return _monthWindow(y, m);
      case AttendanceDateRange.custom:
        final start = customStart ?? _monthWindow(now.year, now.month).start;
        final end = customEnd ?? now;
        // Tolerate reversed bounds so a half-picked custom range never inverts.
        final lo = start.isAfter(end) ? end : start;
        final hi = start.isAfter(end) ? start : end;
        return (start: _startOfDay(lo), end: _endOfDay(hi));
    }
  }

  /// The `yyyyMMdd` lower bound for a `watchBranchRange` server query.
  String startKey(DateTime now) => attendanceDayKey(resolveRange(now).start);

  /// The `yyyyMMdd` upper bound for a `watchBranchRange` server query.
  String endKey(DateTime now) => attendanceDayKey(resolveRange(now).end);

  /// Apply every facet to [records] and return the survivors, newest day first.
  /// Soft-deleted records are always dropped.
  List<AttendanceEntity> apply(
    List<AttendanceEntity> records, {
    required DateTime now,
  }) {
    final window = resolveRange(now);
    final needle = text.trim().toLowerCase();
    final out = <AttendanceEntity>[
      for (final r in records)
        if (!r.isDeleted &&
            !r.date.isBefore(window.start) &&
            !r.date.isAfter(window.end) &&
            (shifts.isEmpty || shifts.contains(r.shift)) &&
            matchesAttendanceStatusFilter(status, r) &&
            (needle.isEmpty ||
                (r.userName ?? '').toLowerCase().contains(needle)))
          r,
    ];
    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }

  static DateWindow _monthWindow(int year, int month) {
    final start = DateTime(year, month, 1);
    // Day 0 of the next month is the last day of this one.
    final lastDay = DateTime(year, month + 1, 0);
    return (start: start, end: _endOfDay(lastDay));
  }

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
}

/// Whether [r] matches the [filter] — the single predicate behind the status
/// chips. Pure and entity-aware (hence in the domain, not on the core enum).
bool matchesAttendanceStatusFilter(
  AttendanceStatusFilter filter,
  AttendanceEntity r,
) {
  switch (filter) {
    case AttendanceStatusFilter.all:
      return true;
    case AttendanceStatusFilter.onTime:
      // Showed up (or is on shift) and wasn't late.
      return r.status.isPresent && !r.isLate;
    case AttendanceStatusFilter.late:
      return r.isLate;
    case AttendanceStatusFilter.absent:
      return r.status.isAbsence;
    case AttendanceStatusFilter.excused:
      return r.isExcused;
    case AttendanceStatusFilter.leave:
      return r.status == AttendanceStatus.onLeave;
    case AttendanceStatusFilter.earlyLeave:
      return r.hasEarlyLeave;
    case AttendanceStatusFilter.overtime:
      return r.hasOvertime;
  }
}
