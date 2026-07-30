import 'package:drop/features/attendance/domain/attendance_id.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_ledger_row.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_period.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_report.dart';

class WeeklyAttendanceReport {
  WeeklyAttendanceReport._({
    required this.window,
    required this.rows,
    required this.summary,
    required this.days,
    required this.employees,
    required this.exceptionGroups,
    required this.coverage,
    required this.version,
  });

  factory WeeklyAttendanceReport.fromLedger({
    required List<AttendanceLedgerRow> rows,
    required AttendancePeriodWindow window,
  }) {
    final scopedRows =
        rows.where((row) => _dayKeyInWindow(row.dayKey, window)).toList()
          ..sort(_compareRows);

    final days = List<WeeklyAttendanceDayBreakdown>.generate(7, (index) {
      final date = DateTime(
        window.startDate.year,
        window.startDate.month,
        window.startDate.day + index,
      );
      final key = attendanceDayKey(date);
      return WeeklyAttendanceDayBreakdown.fromRows(
        date: date,
        dayKey: key,
        rows: scopedRows.where((row) => row.dayKey == key).toList(),
      );
    });

    return WeeklyAttendanceReport._(
      window: window,
      rows: List.unmodifiable(scopedRows),
      summary: AttendanceReportSummary.fromLedger(scopedRows),
      days: List.unmodifiable(days),
      employees: List.unmodifiable(_employeeAggregates(scopedRows)),
      exceptionGroups: List.unmodifiable(_exceptionGroups(scopedRows)),
      coverage: WeeklyAttendanceCoverage.fromDays(days: days, rows: scopedRows),
      version: _version(scopedRows),
    );
  }

  final AttendancePeriodWindow window;
  final List<AttendanceLedgerRow> rows;
  final AttendanceReportSummary summary;
  final List<WeeklyAttendanceDayBreakdown> days;
  final List<WeeklyAttendanceEmployeeAggregate> employees;
  final List<WeeklyAttendanceExceptionGroup> exceptionGroups;
  final WeeklyAttendanceCoverage coverage;
  final int version;

  int get exceptionCount =>
      exceptionGroups.fold(0, (total, group) => total + group.count);
}

class WeeklyAttendanceCoverage {
  const WeeklyAttendanceCoverage({
    required this.ledgerCoverage,
    required this.closedDayCount,
    required this.totalDayCount,
    required this.notClosedDayKeys,
  });

  factory WeeklyAttendanceCoverage.fromDays({
    required List<WeeklyAttendanceDayBreakdown> days,
    required List<AttendanceLedgerRow> rows,
  }) {
    final notClosed = [
      for (final day in days)
        if (!day.hasRows) day.dayKey,
    ];
    return WeeklyAttendanceCoverage(
      ledgerCoverage: LedgerCoverage.fromRows(rows),
      closedDayCount: days.where((day) => day.hasRows).length,
      totalDayCount: days.length,
      notClosedDayKeys: List.unmodifiable(notClosed),
    );
  }

  final LedgerCoverage ledgerCoverage;
  final int closedDayCount;
  final int totalDayCount;
  final List<String> notClosedDayKeys;

  bool get awaitingClose => !ledgerCoverage.hasRows;

  /// **KNOWN LIMITATION — read before gating close/lock/export on this.**
  ///
  /// This requires all seven days to carry ledger rows, so a week with any day
  /// that has **no roster assignment** can never report `Fully closed`. That is
  /// the common case, not an edge case: the live roster routinely leaves
  /// Sunday/Friday/Saturday empty, so such a week reports `Partially closed`
  /// forever.
  ///
  /// It cannot be fixed from the ledger alone. Reporting reads
  /// `attendance_expectations` exclusively (ADR-017), and there "no shifts were
  /// scheduled" and "shifts were scheduled but not yet closed" are *both* zero
  /// rows — indistinguishable without reading the roster, which the ledger-only
  /// rule forbids.
  ///
  /// Deliberately NOT weakened to "every day that has rows is complete": that
  /// would report `Fully closed` on a week with a genuinely unclosed day, which
  /// is the more dangerous error — it would let a period lock or export while
  /// attendance facts were still missing.
  ///
  /// The fix belongs server-side: the close Function should emit a per-day
  /// closure marker (a "closed, zero expectations" fact) so the client can tell
  /// the two cases apart. That is a prerequisite for the close/lock/export
  /// slice, not for this read-only report.
  bool get isFullyClosed =>
      ledgerCoverage.hasRows &&
      closedDayCount == totalDayCount &&
      ledgerCoverage.closedRowCount > 0 &&
      ledgerCoverage.blockingExceptionRowCount == 0;

  bool get isPartiallyClosed => ledgerCoverage.hasRows && !isFullyClosed;

  String get statusLabel {
    if (awaitingClose) return 'Awaiting close';
    if (isFullyClosed) return 'Fully closed';
    return 'Partially closed';
  }
}

class WeeklyAttendanceDayBreakdown {
  const WeeklyAttendanceDayBreakdown({
    required this.date,
    required this.dayKey,
    required this.rows,
    required this.expected,
    required this.present,
    required this.absent,
    required this.lateMinutes,
    required this.exceptionCount,
    required this.blockingExceptionCount,
  });

  factory WeeklyAttendanceDayBreakdown.fromRows({
    required DateTime date,
    required String dayKey,
    required List<AttendanceLedgerRow> rows,
  }) {
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

    return WeeklyAttendanceDayBreakdown(
      date: DateTime(date.year, date.month, date.day),
      dayKey: dayKey,
      rows: List.unmodifiable(rows),
      expected: expected,
      present: present,
      absent: absent,
      lateMinutes: lateMinutes,
      exceptionCount: exceptionCount,
      blockingExceptionCount: blocking,
    );
  }

  final DateTime date;
  final String dayKey;
  final List<AttendanceLedgerRow> rows;
  final int expected;
  final int present;
  final int absent;
  final int lateMinutes;
  final int exceptionCount;
  final int blockingExceptionCount;

  bool get hasRows => rows.isNotEmpty;
}

class WeeklyAttendanceEmployeeAggregate {
  const WeeklyAttendanceEmployeeAggregate({
    required this.userId,
    required this.displayName,
    required this.expected,
    required this.present,
    required this.absent,
    required this.lateMinutes,
    required this.workedMinutes,
    required this.overtimeMinutes,
    required this.exceptionCount,
  });

  final String userId;
  final String displayName;
  final int expected;
  final int present;
  final int absent;
  final int lateMinutes;
  final int workedMinutes;
  final int overtimeMinutes;
  final int exceptionCount;
}

class WeeklyAttendanceExceptionGroup {
  const WeeklyAttendanceExceptionGroup({
    required this.key,
    required this.label,
    required this.blocksClose,
    required this.count,
    required this.rowIds,
  });

  final String key;
  final String label;
  final bool blocksClose;
  final int count;
  final List<String> rowIds;
}

List<WeeklyAttendanceEmployeeAggregate> _employeeAggregates(
  List<AttendanceLedgerRow> rows,
) {
  final builders = <String, _EmployeeAggregateBuilder>{};
  for (final row in rows) {
    final builder = builders.putIfAbsent(
      row.userId,
      () => _EmployeeAggregateBuilder(
        userId: row.userId,
        displayName: _employeeName(row),
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

String _employeeName(AttendanceLedgerRow row) {
  final name = row.userName?.trim();
  if (name != null && name.isNotEmpty) return name;
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
