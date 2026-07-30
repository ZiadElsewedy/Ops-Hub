import 'package:drop/features/attendance/domain/attendance_id.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_ledger_row.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_period.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_report.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_weekly_report.dart';

/// A calendar month of the `attendance_expectations` ledger, folded into the
/// facts a payroll/accounting handoff needs.
///
/// Monthly is deliberately **not** "weekly with more days"
/// (`docs/design/ATTENDANCE_REPORTS_IA.md` §7.1): the month is partitioned into
/// the Schedule weeks (Sunday→Saturday) that overlap it, so a change can be
/// located inside the month without scanning 31 day rows.
///
/// **Aggregation is client-side today, by design of the value object rather
/// than by accident.** Every aggregate is computed by
/// [MonthlyAttendanceReport.fromLedger] and handed to the private constructor
/// already folded; the constructor itself scans nothing. When the rollup
/// Function of ADR-017 lands, a `MonthlyAttendanceReport.fromRollup(...)`
/// factory reads the same aggregates off the server document and calls the same
/// constructor — additively, with no change to the UI layer, because the UI only
/// ever sees the finished fields. That split is the whole mechanism; there is
/// deliberately no interface, strategy, or provider seam with one
/// implementation.
class MonthlyAttendanceReport {
  const MonthlyAttendanceReport._({
    required this.window,
    required this.rows,
    required this.summary,
    required this.weekBuckets,
    required this.employees,
    required this.exceptionGroups,
    required this.coverage,
    required this.version,
  });

  /// The only row-scanning entry point.
  factory MonthlyAttendanceReport.fromLedger({
    required List<AttendanceLedgerRow> rows,
    required AttendancePeriodWindow window,
    Map<String, String> namesByUid = const {},
  }) {
    final scopedRows =
        rows.where((row) => _dayKeyInWindow(row.dayKey, window)).toList()
          ..sort(_compareRows);

    final dayKeys = _monthDayKeys(window);
    final buckets = _weekBuckets(window: window, rows: scopedRows);

    return MonthlyAttendanceReport._(
      window: window,
      rows: List.unmodifiable(scopedRows),
      summary: AttendanceReportSummary.fromLedger(scopedRows),
      weekBuckets: List.unmodifiable(buckets),
      employees: List.unmodifiable(_employeeAggregates(scopedRows, namesByUid)),
      exceptionGroups: List.unmodifiable(_exceptionGroups(scopedRows)),
      coverage: MonthlyAttendanceCoverage.fromMonth(
        dayKeys: dayKeys,
        rows: scopedRows,
      ),
      version: _version(scopedRows),
    );
  }

  final AttendancePeriodWindow window;
  final List<AttendanceLedgerRow> rows;
  final AttendanceReportSummary summary;

  /// Every Schedule week (Sunday→Saturday) that overlaps the month, in order.
  final List<MonthlyAttendanceWeekBucket> weekBuckets;

  /// Alphabetical per-person facts. Reuses the weekly aggregate shape so both
  /// reports speak the same employee vocabulary — no ranking, no score.
  final List<WeeklyAttendanceEmployeeAggregate> employees;
  final List<WeeklyAttendanceExceptionGroup> exceptionGroups;
  final MonthlyAttendanceCoverage coverage;
  final int version;

  int get exceptionCount =>
      exceptionGroups.fold(0, (total, group) => total + group.count);

  /// Schedule weeks that only partly overlap the month. A partial bucket is
  /// never presented as a full week.
  int get partialWeekCount =>
      weekBuckets.where((bucket) => bucket.isPartial).length;
}

/// Month coverage. Semantics are **identical** to [WeeklyAttendanceCoverage] —
/// the only additions are month-sized day counts.
class MonthlyAttendanceCoverage {
  const MonthlyAttendanceCoverage({
    required this.ledgerCoverage,
    required this.closedDayCount,
    required this.totalDayCount,
    required this.notClosedDayKeys,
  });

  factory MonthlyAttendanceCoverage.fromMonth({
    required List<String> dayKeys,
    required List<AttendanceLedgerRow> rows,
  }) {
    final withRows = rows.map((row) => row.dayKey).toSet();
    final notClosed = [
      for (final key in dayKeys)
        if (!withRows.contains(key)) key,
    ];
    return MonthlyAttendanceCoverage(
      ledgerCoverage: LedgerCoverage.fromRows(rows),
      closedDayCount: dayKeys.length - notClosed.length,
      totalDayCount: dayKeys.length,
      notClosedDayKeys: List.unmodifiable(notClosed),
    );
  }

  final LedgerCoverage ledgerCoverage;
  final int closedDayCount;
  final int totalDayCount;

  /// Business dates in the month with no ledger row at all, so the readiness
  /// panel can name the missing dates instead of implying zero attendance.
  final List<String> notClosedDayKeys;

  bool get awaitingClose => !ledgerCoverage.hasRows;

  /// Owner rule: every materialized expected shift is a real attendance
  /// denominator. Rows present with zero clock-ins report 0%, while a date with
  /// no rows is only a ledger data gap and has no attendance rate.
  ///
  /// Under that rule, fully closed means this month has ledger rows and none of
  /// them carries a blocking exception.
  bool get isFullyClosed =>
      ledgerCoverage.hasRows && ledgerCoverage.blockingExceptionRowCount == 0;

  bool get isPartiallyClosed => ledgerCoverage.hasRows && !isFullyClosed;

  String get statusLabel {
    if (awaitingClose) return 'Awaiting close';
    if (isFullyClosed) return 'Fully closed';
    return 'Partially closed';
  }
}

/// One Schedule week (Sunday→Saturday) inside a month.
///
/// [weekStart]/[weekEnd] are the real roster week, which may sit outside the
/// month at either edge. [coveredStart]/[coveredEnd] are that week clamped to
/// the month, and [isPartial] says the two differ — a short edge week is never
/// reported as if it were a full one.
class MonthlyAttendanceWeekBucket {
  const MonthlyAttendanceWeekBucket({
    required this.weekStart,
    required this.weekEnd,
    required this.coveredStart,
    required this.coveredEnd,
    required this.rows,
    required this.expected,
    required this.present,
    required this.absent,
    required this.lateMinutes,
    required this.exceptionCount,
    required this.blockingExceptionCount,
  });

  factory MonthlyAttendanceWeekBucket.fromRows({
    required DateTime weekStart,
    required DateTime monthStart,
    required DateTime monthEnd,
    required List<AttendanceLedgerRow> rows,
  }) {
    // Calendar arithmetic, never `Duration(days: 6)`: Egypt observes DST, so a
    // week that spans a transition is 167 or 169 real hours and a Duration walk
    // lands on 01:00 or 23:00 of the wrong date. `DateTime(y, m, d + 6)`
    // normalizes to the intended calendar date either way.
    final start = _dateOnly(weekStart);
    final end = DateTime(start.year, start.month, start.day + 6);
    final monthFirst = _dateOnly(monthStart);
    final monthLast = _dateOnly(monthEnd);

    var expected = 0;
    var present = 0;
    var absent = 0;
    var lateMinutes = 0;
    var exceptionCount = 0;
    var blocking = 0;

    for (final row in rows) {
      if (!row.isUnscheduledWork && row.expected) expected++;
      if (!row.isUnscheduledWork && row.outcome.countsAsPresent) present++;
      if (!row.isUnscheduledWork && row.outcome.countsAsAbsence) absent++;
      lateMinutes += row.lateMinutes;
      exceptionCount += row.exceptionCodes.length;
      exceptionCount += row.unknownExceptionCodes.length;
      if (row.hasBlockingException) blocking++;
    }

    return MonthlyAttendanceWeekBucket(
      weekStart: start,
      weekEnd: end,
      coveredStart: start.isBefore(monthFirst) ? monthFirst : start,
      coveredEnd: end.isAfter(monthLast) ? monthLast : end,
      rows: List.unmodifiable(rows),
      expected: expected,
      present: present,
      absent: absent,
      lateMinutes: lateMinutes,
      exceptionCount: exceptionCount,
      blockingExceptionCount: blocking,
    );
  }

  final DateTime weekStart;
  final DateTime weekEnd;
  final DateTime coveredStart;
  final DateTime coveredEnd;
  final List<AttendanceLedgerRow> rows;
  final int expected;
  final int present;
  final int absent;
  final int lateMinutes;
  final int exceptionCount;
  final int blockingExceptionCount;

  bool get hasRows => rows.isNotEmpty;

  /// True when the Schedule week is not entirely inside the month.
  bool get isPartial => coveredStart != weekStart || coveredEnd != weekEnd;

  /// Business dates of this week that fall inside the month.
  ///
  /// Counted in UTC on purpose. `coveredStart`/`coveredEnd` are local calendar
  /// dates, and a local `difference().inDays` truncates to 6 across Egypt's
  /// spring-forward week (167 hours). UTC has no DST, so the day count is exact.
  int get coveredDayCount {
    final start = DateTime.utc(
      coveredStart.year,
      coveredStart.month,
      coveredStart.day,
    );
    final end = DateTime.utc(
      coveredEnd.year,
      coveredEnd.month,
      coveredEnd.day,
    );
    return end.difference(start).inDays + 1;
  }

  AttendanceRate get showUpRate => AttendanceRate(
    numerator: present,
    denominator: expected,
    denominatorLabel: 'expected work shifts',
  );
}

List<MonthlyAttendanceWeekBucket> _weekBuckets({
  required AttendancePeriodWindow window,
  required List<AttendanceLedgerRow> rows,
}) {
  final starts = <DateTime>[];
  final bucketOfDayKey = <String, DateTime>{};
  for (final date in _monthDates(window)) {
    final weekStart = _weekStartOf(date);
    if (starts.isEmpty || starts.last != weekStart) starts.add(weekStart);
    bucketOfDayKey[attendanceDayKey(date)] = weekStart;
  }

  final grouped = {for (final start in starts) start: <AttendanceLedgerRow>[]};
  for (final row in rows) {
    // A row belongs to the bucket of its own dayKey. Rows outside the month are
    // already filtered before this runs.
    final start = bucketOfDayKey[row.dayKey];
    if (start != null) grouped[start]!.add(row);
  }

  return [
    for (final start in starts)
      MonthlyAttendanceWeekBucket.fromRows(
        weekStart: start,
        monthStart: window.startDate,
        monthEnd: window.endDate,
        rows: grouped[start]!,
      ),
  ];
}

List<DateTime> _monthDates(AttendancePeriodWindow window) {
  final start = _dateOnly(window.startDate);
  return [
    for (var i = 0; i < window.dayCount; i++)
      DateTime(start.year, start.month, start.day + i),
  ];
}

List<String> _monthDayKeys(AttendancePeriodWindow window) => [
  for (final date in _monthDates(window)) attendanceDayKey(date),
];

// The aggregation below mirrors `attendance_weekly_report.dart` and produces the
// same public value types on purpose, so both reports describe an employee and
// an exception identically. The weekly file is left untouched.
List<WeeklyAttendanceEmployeeAggregate> _employeeAggregates(
  List<AttendanceLedgerRow> rows,
  Map<String, String> namesByUid,
) {
  final builders = <String, _EmployeeAggregateBuilder>{};
  for (final row in rows) {
    final builder = builders.putIfAbsent(
      row.userId,
      () => _EmployeeAggregateBuilder(
        userId: row.userId,
        displayName: _employeeName(row, namesByUid),
      ),
    );
    builder.add(row);
  }
  final employees = builders.values.map((builder) => builder.build()).toList();
  employees.sort((a, b) {
    final byName = a.displayName.toLowerCase().compareTo(
      b.displayName.toLowerCase(),
    );
    if (byName != 0) return byName;
    return a.userId.compareTo(b.userId);
  });
  return employees;
}

List<WeeklyAttendanceExceptionGroup> _exceptionGroups(
  List<AttendanceLedgerRow> rows,
) {
  final builders = <String, _ExceptionGroupBuilder>{};
  for (final row in rows) {
    for (final code in row.exceptionCodes) {
      final key = 'known:${code.name}';
      builders
          .putIfAbsent(
            key,
            () => _ExceptionGroupBuilder(
              key: key,
              label: code.label,
              blocksClose: code.blocksClose,
            ),
          )
          .add(row);
    }
    for (final rawCode in row.unknownExceptionCodes) {
      final key = 'unknown:$rawCode';
      builders
          .putIfAbsent(
            key,
            () => _ExceptionGroupBuilder(
              key: key,
              label: 'Unrecognized: $rawCode',
              blocksClose: true,
            ),
          )
          .add(row);
    }
  }
  final groups = builders.values.map((builder) => builder.build()).toList();
  groups.sort((a, b) {
    if (a.blocksClose != b.blocksClose) return a.blocksClose ? -1 : 1;
    return a.label.compareTo(b.label);
  });
  return groups;
}

/// Ledger-frozen name first, then the branch directory, then the uid.
///
/// The ledger value wins because it is the name as of close, which is what a
/// payroll artifact must reproduce. The directory only fills the gap a phantom
/// no-show leaves: it has no attendance record, so it has no frozen name, and
/// the uid alone is unreadable to a manager.
String _employeeName(
  AttendanceLedgerRow row, [
  Map<String, String> namesByUid = const {},
]) {
  final name = row.userName?.trim();
  if (name != null && name.isNotEmpty) return name;
  final fromDirectory = namesByUid[row.userId]?.trim();
  if (fromDirectory != null && fromDirectory.isNotEmpty) return fromDirectory;
  return row.userId;
}

int _version(List<AttendanceLedgerRow> rows) {
  var version = 1;
  for (final row in rows) {
    if (row.version > version) version = row.version;
  }
  return version;
}

bool _dayKeyInWindow(String dayKey, AttendancePeriodWindow window) {
  final startKey = attendanceDayKey(window.startDate);
  final endKey = attendanceDayKey(window.endDate);
  return dayKey.compareTo(startKey) >= 0 && dayKey.compareTo(endKey) <= 0;
}

int _compareRows(AttendanceLedgerRow a, AttendanceLedgerRow b) {
  final byDay = a.dayKey.compareTo(b.dayKey);
  if (byDay != 0) return byDay;
  final byName = _employeeName(
    a,
  ).toLowerCase().compareTo(_employeeName(b).toLowerCase());
  if (byName != 0) return byName;
  return a.id.compareTo(b.id);
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// The Sunday starting [date]'s Schedule week, by calendar arithmetic only.
///
/// This deliberately does **not** call `ScheduleWeek.startOf`, which subtracts a
/// `Duration`. Egypt observes DST, and a month is the first reporting surface
/// that walks every date and groups by week, so that drift becomes visible here
/// in a way a single call never exposed:
///
/// - Oct 2026 (clocks back Thu 29): the walk resolves the week of Sun 25 Oct to
///   both `00:00` and `01:00`, splitting one week into two buckets.
/// - Apr 2026 (clocks forward Fri 24, so `00:00` that day does not exist): the
///   walk lands on `Apr 18 23:00`, which floors to the *previous* day and forks
///   a sixth bucket out of a five-week month.
///
/// `weekday` is unaffected by DST and `DateTime(y, m, d - n)` normalizes across
/// month and year boundaries, so this is exact in both directions. The shared
/// `ScheduleWeek.startOf` is intentionally left untouched — repairing it is a
/// separate, wider change than this report.
DateTime _weekStartOf(DateTime date) {
  final day = _dateOnly(date);
  return DateTime(day.year, day.month, day.day - (day.weekday % 7));
}

class _EmployeeAggregateBuilder {
  _EmployeeAggregateBuilder({required this.userId, required this.displayName});

  final String userId;
  String displayName;
  var expected = 0;
  var present = 0;
  var absent = 0;
  var lateMinutes = 0;
  var workedMinutes = 0;
  var overtimeMinutes = 0;
  var exceptionCount = 0;

  void add(AttendanceLedgerRow row) {
    final name = row.userName?.trim();
    if (name != null && name.isNotEmpty) displayName = name;
    if (!row.isUnscheduledWork && row.expected) expected++;
    if (!row.isUnscheduledWork && row.outcome.countsAsPresent) present++;
    if (!row.isUnscheduledWork && row.outcome.countsAsAbsence) absent++;
    lateMinutes += row.lateMinutes;
    workedMinutes += row.workedMinutes;
    overtimeMinutes += row.overtimeMinutes;
    exceptionCount += row.exceptionCodes.length;
    exceptionCount += row.unknownExceptionCodes.length;
  }

  WeeklyAttendanceEmployeeAggregate build() =>
      WeeklyAttendanceEmployeeAggregate(
        userId: userId,
        displayName: displayName,
        expected: expected,
        present: present,
        absent: absent,
        lateMinutes: lateMinutes,
        workedMinutes: workedMinutes,
        overtimeMinutes: overtimeMinutes,
        exceptionCount: exceptionCount,
      );
}

class _ExceptionGroupBuilder {
  _ExceptionGroupBuilder({
    required this.key,
    required this.label,
    required this.blocksClose,
  });

  final String key;
  final String label;
  final bool blocksClose;
  final rowIds = <String>[];

  void add(AttendanceLedgerRow row) => rowIds.add(row.id);

  WeeklyAttendanceExceptionGroup build() => WeeklyAttendanceExceptionGroup(
    key: key,
    label: label,
    blocksClose: blocksClose,
    count: rowIds.length,
    rowIds: List.unmodifiable(rowIds),
  );
}
