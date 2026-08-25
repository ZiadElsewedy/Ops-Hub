import 'package:opshub/features/attendance/domain/attendance_id.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_ledger_row.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_period.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_coverage_status.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_report.dart';

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
    Map<String, String> namesByUid = const {},
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
      employees: List.unmodifiable(
        sortByAttention(_employeeAggregates(scopedRows, namesByUid)),
      ),
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

  /// People whose week needs the manager to do or check something.
  int get peopleNeedingAttention =>
      employees.where((e) => e.attentionBand.needsAttention).length;

  /// Shifts worked out of shifts scheduled — the numerator and denominator of
  /// the week's one-line summary. Counts, never a percentage: at store volumes a
  /// rate is the least reliable and most alarming figure available
  /// (`ATTENDANCE_REPORTS_IA` §6.5).
  int get shiftsWorked => summary.present;

  int get shiftsScheduled => summary.expectedWorkShifts;
}

/// Exceptions first, then alphabetical inside each band
/// (`ATTENDANCE_REPORTS_IA` §6.5.1).
///
/// This replaces a purely alphabetical order. Alphabetical was chosen as a
/// fairness measure, but it is not what stops the report ranking people —
/// refusing to compute a score is, and that refusal is unchanged. All
/// alphabetical order actually guaranteed was that the one person who did not
/// show up sat several rows down.
///
/// Weekly only. Monthly keeps the alphabetical list: it is read as a roll of the
/// month, not as a queue of things to act on this week.
List<WeeklyAttendanceEmployeeAggregate> sortByAttention(
  List<WeeklyAttendanceEmployeeAggregate> employees,
) {
  final sorted = [...employees];
  sorted.sort((a, b) {
    final byBand = a.attentionBand.index.compareTo(b.attentionBand.index);
    if (byBand != 0) return byBand;
    final byName = a.displayName.toLowerCase().compareTo(
      b.displayName.toLowerCase(),
    );
    if (byName != 0) return byName;
    return a.userId.compareTo(b.userId);
  });
  return sorted;
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

  /// Owner rule: every materialized expected shift is a real attendance
  /// denominator. Rows present with zero clock-ins report 0%, while a day with no
  /// rows is only a ledger data gap and has no attendance rate.
  ///
  /// Under that rule, fully closed means this period has ledger rows and none of
  /// them carries a blocking exception.
  ///
  /// **This is a pipeline fact, not a manager-facing one.** It stays true for a
  /// week with rows on a single day, which is why [status] — not this — decides
  /// the word a manager reads. See [AttendanceCoverageStatus].
  bool get isFullyClosed =>
      ledgerCoverage.hasRows && ledgerCoverage.blockingExceptionRowCount == 0;

  bool get isPartiallyClosed => ledgerCoverage.hasRows && !isFullyClosed;

  /// At least one business date in the window has no ledger row.
  bool get hasDayGaps => notClosedDayKeys.isNotEmpty;

  AttendanceCoverageStatus get status => AttendanceCoverageStatus.resolve(
    hasRows: ledgerCoverage.hasRows,
    blockingRowCount: ledgerCoverage.blockingExceptionRowCount,
    hasDayGaps: hasDayGaps,
  );

  String get statusLabel => status.label;
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

/// How much of a manager's attention a person's week needs.
///
/// Ordering, never scoring. The band is derived from facts already on the row —
/// it weights nothing, invents no denominator, and produces no number. ADR-017's
/// refusal of composite performance scores is untouched: this decides *what
/// order rows appear in*, which is a property of the list, not of the person.
enum AttendanceAttentionBand {
  /// Something on this person's week needs a decision before the week settles.
  needsDecision,

  /// A shift was expected and unworked.
  absent,

  /// Worked, but arrived late at least once.
  late,

  /// Nothing to look at.
  clean;

  /// The word in the person row's Status column.
  String get label => switch (this) {
    AttendanceAttentionBand.needsDecision => 'Needs a decision',
    AttendanceAttentionBand.absent => 'Absent',
    AttendanceAttentionBand.late => 'Late',
    AttendanceAttentionBand.clean => '—',
  };

  bool get needsAttention => this != AttendanceAttentionBand.clean;
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
    this.blockingExceptionCount = 0,
    this.lateArrivals = 0,
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

  /// Exceptions on this person's rows that stop the period settling.
  final int blockingExceptionCount;

  /// Shifts this person arrived late for. A **count**, because that is what a
  /// manager coaches to — summed minutes across a week is not actionable.
  final int lateArrivals;

  AttendanceAttentionBand get attentionBand {
    if (blockingExceptionCount > 0) return AttendanceAttentionBand.needsDecision;
    if (absent > 0) return AttendanceAttentionBand.absent;
    if (lateArrivals > 0) return AttendanceAttentionBand.late;
    return AttendanceAttentionBand.clean;
  }
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
  var blockingExceptionCount = 0;
  var lateArrivals = 0;

  void add(AttendanceLedgerRow row) {
    final name = row.userName?.trim();
    if (name != null && name.isNotEmpty) displayName = name;
    if (!row.isUnscheduledWork && row.expected) expected++;
    if (!row.isUnscheduledWork && row.outcome.countsAsPresent) present++;
    if (!row.isUnscheduledWork && row.outcome.countsAsAbsence) absent++;
    lateMinutes += row.lateMinutes;
    if (row.lateMinutes > 0) lateArrivals++;
    workedMinutes += row.workedMinutes;
    overtimeMinutes += row.overtimeMinutes;
    exceptionCount += row.exceptionCodes.length;
    exceptionCount += row.unknownExceptionCodes.length;
    if (row.hasBlockingException) blockingExceptionCount++;
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
        blockingExceptionCount: blockingExceptionCount,
        lateArrivals: lateArrivals,
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
