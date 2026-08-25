import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_exception.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_ledger_row.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_coverage_status.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_monthly_report.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_period.dart';

const _branchId = 'DDwedTHvI1sPHrMz06PI';

AttendanceLedgerRow _row({
  required String id,
  required String userId,
  String? userName,
  String dayKey = '20260715',
  String businessDate = '2026-07-15',
  AttendanceLedgerOutcome outcome = AttendanceLedgerOutcome.absent,
  bool expected = true,
  String? recordId,
  int workedMinutes = 0,
  int lateMinutes = 0,
  int overtimeMinutes = 0,
  int version = 1,
  List<AttendanceExceptionCode> exceptionCodes = const [],
  List<String> unknownExceptionCodes = const [],
}) => AttendanceLedgerRow(
  id: id,
  rowId: id,
  userId: userId,
  userName: userName,
  branchId: _branchId,
  dayKey: dayKey,
  businessDate: businessDate,
  shift: ScheduleShift.morning,
  outcome: outcome,
  expected: expected,
  recordId: recordId,
  workedMinutes: workedMinutes,
  lateMinutes: lateMinutes,
  overtimeMinutes: overtimeMinutes,
  exceptionCodes: exceptionCodes,
  unknownExceptionCodes: unknownExceptionCodes,
  locked: false,
  version: version,
  source: 'system',
  closedAt: DateTime(2026, 7, 15, 18),
);

void main() {
  // July 2026 starts on a Wednesday and ends on a Friday, so both edge weeks
  // are partial — the ordinary case, not a contrived one.
  final july = monthlyWindow(2026, 7);

  test('empty month is awaiting close with no percentages', () {
    final report = MonthlyAttendanceReport.fromLedger(
      rows: const [],
      window: july,
    );

    expect(report.coverage.awaitingClose, isTrue);
    expect(report.coverage.statusLabel, 'No data yet');
    expect(report.coverage.status, AttendanceCoverageStatus.noData);
    expect(report.coverage.isFullyClosed, isFalse);
    expect(report.coverage.isPartiallyClosed, isFalse);
    expect(report.coverage.totalDayCount, 31);
    expect(report.coverage.closedDayCount, 0);
    expect(report.coverage.notClosedDayKeys, hasLength(31));
    expect(report.summary.showUpRate.percent, isNull);
    expect(report.summary.expectedWorkShifts, 0);
    expect(report.rows, isEmpty);
    expect(report.weekBuckets.every((bucket) => !bucket.hasRows), isTrue);
    expect(
      report.weekBuckets.every((bucket) => bucket.showUpRate.percent == null),
      isTrue,
    );
  });

  test('rows present with zero clock-ins are a real 0% month', () {
    final report = MonthlyAttendanceReport.fromLedger(
      rows: [
        _row(id: 'u1_20260715_morning', userId: 'u1', userName: 'Amal'),
        _row(id: 'u2_20260715_morning', userId: 'u2', userName: 'Basma'),
        _row(id: 'u3_20260715_morning', userId: 'u3', userName: 'Youssef'),
      ],
      window: july,
    );

    expect(report.coverage.awaitingClose, isFalse);
    // 1 of 31 days carries rows, so the manager-facing word is a gap, not a
    // close claim — even though the close pipeline's isFullyClosed is true.
    expect(report.coverage.isFullyClosed, isTrue);
    expect(report.coverage.statusLabel, 'In progress');
    expect(report.summary.expectedWorkShifts, 3);
    expect(report.summary.present, 0);
    expect(report.summary.absent, 3);
    expect(report.summary.showUpRate.percent, 0);
    expect(
      report.summary.showUpRate.describe(),
      '0% · 0 / 3 scheduled shifts',
    );
    expect(report.coverage.closedDayCount, 1);
    expect(report.coverage.notClosedDayKeys, hasLength(30));
    expect(report.coverage.notClosedDayKeys.contains('20260715'), isFalse);
  });

  test('month is partitioned into Sunday-start Schedule weeks', () {
    final report = MonthlyAttendanceReport.fromLedger(
      rows: const [],
      window: july,
    );

    expect(report.weekBuckets.map((bucket) => bucket.weekStart), [
      DateTime(2026, 6, 28),
      DateTime(2026, 7, 5),
      DateTime(2026, 7, 12),
      DateTime(2026, 7, 19),
      DateTime(2026, 7, 26),
    ]);
    for (final bucket in report.weekBuckets) {
      expect(bucket.weekStart.weekday, DateTime.sunday);
      expect(bucket.weekEnd, bucket.weekStart.add(const Duration(days: 6)));
    }
  });

  test('both month-edge buckets are partial and clamped to the month', () {
    final report = MonthlyAttendanceReport.fromLedger(
      rows: const [],
      window: july,
    );

    final first = report.weekBuckets.first;
    expect(first.isPartial, isTrue);
    expect(first.weekStart, DateTime(2026, 6, 28));
    expect(first.coveredStart, DateTime(2026, 7, 1));
    expect(first.coveredEnd, DateTime(2026, 7, 4));
    expect(first.coveredDayCount, 4);

    final last = report.weekBuckets.last;
    expect(last.isPartial, isTrue);
    expect(last.weekEnd, DateTime(2026, 8, 1));
    expect(last.coveredStart, DateTime(2026, 7, 26));
    expect(last.coveredEnd, DateTime(2026, 7, 31));
    expect(last.coveredDayCount, 6);

    final middle = report.weekBuckets[2];
    expect(middle.isPartial, isFalse);
    expect(middle.coveredDayCount, 7);
    expect(report.partialWeekCount, 2);
  });

  test('a month starting mid-week gets a leading partial bucket', () {
    // April 2026 starts on a Wednesday, so its first Schedule week begins in
    // March and only four of its days belong to the month.
    final april = monthlyWindow(2026, 4);
    final report = MonthlyAttendanceReport.fromLedger(
      rows: const [],
      window: april,
    );

    expect(report.weekBuckets.first.weekStart, DateTime(2026, 3, 29));
    expect(report.weekBuckets.first.isPartial, isTrue);
    expect(report.weekBuckets.first.coveredStart, DateTime(2026, 4, 1));
    expect(report.weekBuckets.first.coveredDayCount, 4);
    expect(report.weekBuckets, hasLength(5));
  });

  test('a month that is exactly four Schedule weeks has no partial bucket', () {
    // February 2026 runs Sunday 1 Feb through Saturday 28 Feb.
    final report = MonthlyAttendanceReport.fromLedger(
      rows: const [],
      window: monthlyWindow(2026, 2),
    );

    expect(report.weekBuckets, hasLength(4));
    expect(report.weekBuckets.first.weekStart, DateTime(2026, 2, 1));
    expect(report.weekBuckets.last.weekEnd, DateTime(2026, 2, 28));
    expect(report.partialWeekCount, 0);
    expect(report.coverage.totalDayCount, 28);
  });

  test('rows land in the bucket of their own dayKey', () {
    final report = MonthlyAttendanceReport.fromLedger(
      rows: [
        // First (partial) bucket: 1-4 July.
        _row(
          id: 'u1_20260702_morning',
          userId: 'u1',
          dayKey: '20260702',
          businessDate: '2026-07-02',
          outcome: AttendanceLedgerOutcome.worked,
          recordId: 'u1_20260702_morning',
          workedMinutes: 480,
        ),
        // Third bucket: 12-18 July.
        _row(id: 'u2_20260715_morning', userId: 'u2', dayKey: '20260715'),
        // Outside the month entirely — must be dropped.
        _row(
          id: 'u3_20260805_morning',
          userId: 'u3',
          dayKey: '20260805',
          businessDate: '2026-08-05',
        ),
      ],
      window: july,
    );

    expect(report.rows, hasLength(2));
    expect(report.weekBuckets[0].rows.map((row) => row.dayKey), ['20260702']);
    expect(report.weekBuckets[0].present, 1);
    expect(
      report.weekBuckets[0].showUpRate.describe(),
      '100% · 1 / 1 scheduled shifts',
    );
    expect(report.weekBuckets[1].hasRows, isFalse);
    expect(report.weekBuckets[2].rows.map((row) => row.dayKey), ['20260715']);
    expect(report.weekBuckets[2].absent, 1);
    expect(
      report.weekBuckets[2].showUpRate.describe(),
      '0% · 0 / 1 scheduled shifts',
    );
  });

  test('blocking exceptions keep a row-present month partially closed', () {
    final report = MonthlyAttendanceReport.fromLedger(
      rows: [
        _row(
          id: 'u1_20260715_morning',
          userId: 'u1',
          exceptionCodes: const [AttendanceExceptionCode.missingPunch],
        ),
      ],
      window: july,
    );

    expect(report.coverage.statusLabel, 'Needs attention');
    expect(report.coverage.isFullyClosed, isFalse);
    expect(report.coverage.ledgerCoverage.blockingExceptionRowCount, 1);
    expect(report.weekBuckets[2].blockingExceptionCount, 1);
  });

  test('employees aggregate across the whole month, alphabetically', () {
    final report = MonthlyAttendanceReport.fromLedger(
      rows: [
        _row(
          id: 'z_20260702_morning',
          userId: 'z',
          userName: 'Ziad',
          dayKey: '20260702',
          businessDate: '2026-07-02',
          outcome: AttendanceLedgerOutcome.workedLate,
          recordId: 'z_20260702_morning',
          workedMinutes: 460,
          lateMinutes: 20,
          overtimeMinutes: 5,
          exceptionCodes: const [AttendanceExceptionCode.late],
        ),
        _row(
          id: 'z_20260722_morning',
          userId: 'z',
          userName: 'Ziad',
          dayKey: '20260722',
          businessDate: '2026-07-22',
          outcome: AttendanceLedgerOutcome.worked,
          recordId: 'z_20260722_morning',
          workedMinutes: 480,
        ),
        _row(id: 'a_20260715_morning', userId: 'a', userName: 'Amal'),
      ],
      window: july,
    );

    expect(report.employees.map((employee) => employee.displayName), [
      'Amal',
      'Ziad',
    ]);
    final ziad = report.employees.last;
    expect(ziad.expected, 2);
    expect(ziad.present, 2);
    expect(ziad.absent, 0);
    expect(ziad.workedMinutes, 940);
    expect(ziad.lateMinutes, 20);
    expect(ziad.overtimeMinutes, 5);
    expect(ziad.exceptionCount, 1);
    expect(report.employees.first.absent, 1);
  });

  test('exception groups list blocking first, then alphabetically', () {
    final report = MonthlyAttendanceReport.fromLedger(
      rows: [
        _row(
          id: 'u1_20260715_morning',
          userId: 'u1',
          outcome: AttendanceLedgerOutcome.workedLate,
          recordId: 'u1_20260715_morning',
          exceptionCodes: const [
            AttendanceExceptionCode.late,
            AttendanceExceptionCode.overtime,
          ],
        ),
        _row(
          id: 'u2_20260716_morning',
          userId: 'u2',
          dayKey: '20260716',
          businessDate: '2026-07-16',
          exceptionCodes: const [AttendanceExceptionCode.missingPunch],
        ),
        _row(
          id: 'u3_20260717_morning',
          userId: 'u3',
          dayKey: '20260717',
          businessDate: '2026-07-17',
          unknownExceptionCodes: const ['newServerCode'],
        ),
      ],
      window: july,
    );

    expect(report.exceptionGroups.map((group) => group.label), [
      'Missing punch',
      'Unrecognized: newServerCode',
      'Late',
      'Overtime',
    ]);
    expect(report.exceptionGroups.map((group) => group.blocksClose), [
      true,
      true,
      false,
      false,
    ]);
    expect(report.exceptionCount, 4);
    expect(report.coverage.ledgerCoverage.blockingExceptionRowCount, 2);
  });

  test('version resolves to the highest restated row version', () {
    final report = MonthlyAttendanceReport.fromLedger(
      rows: [
        _row(id: 'u1_20260715_morning', userId: 'u1'),
        _row(
          id: 'u2_20260716_morning',
          userId: 'u2',
          dayKey: '20260716',
          businessDate: '2026-07-16',
          version: 4,
        ),
        _row(
          id: 'u3_20260717_morning',
          userId: 'u3',
          dayKey: '20260717',
          businessDate: '2026-07-17',
          version: 2,
        ),
      ],
      window: july,
    );

    expect(report.version, 4);
    expect(
      MonthlyAttendanceReport.fromLedger(rows: const [], window: july).version,
      1,
    );
  });

  group('employee name resolution', _nameResolutionTests);

  // Egypt observes DST: clocks go forward on the last Friday of April and back
  // on the last Thursday of October. A month is the first reporting surface
  // that walks every date and groups by Schedule week, so it is the first place
  // a Duration-based week walk can go wrong. These two months are the regression
  // guard; both assertions failed before the date math was made calendar-safe.
  group('Africa/Cairo DST months', () {
    test('October back-transition keeps one Schedule week as one bucket', () {
      // Clocks go back on Thu 29 Oct 2026, so a Duration walk resolves the week
      // of Sun 25 Oct to both 00:00 and 01:00 and split Oct 30-31 into a
      // phantom sixth bucket.
      final report = MonthlyAttendanceReport.fromLedger(
        rows: const [],
        window: monthlyWindow(2026, 10),
      );

      expect(report.weekBuckets, hasLength(5));

      final last = report.weekBuckets.last;
      expect(last.weekStart, DateTime(2026, 10, 25));
      expect(last.weekEnd, DateTime(2026, 10, 31));
      expect(last.coveredEnd, DateTime(2026, 10, 31));
      expect(last.isPartial, isFalse);
      expect(last.coveredDayCount, 7);

      // Every date in the month lands in exactly one bucket.
      expect(
        report.weekBuckets.fold<int>(
          0,
          (total, bucket) => total + bucket.coveredDayCount,
        ),
        31,
      );
    });

    test('April spring-forward week still counts seven covered days', () {
      // Clocks go forward on Fri 24 Apr 2026, making that week 167 hours. A
      // local `difference().inDays` truncates it to 6.
      final report = MonthlyAttendanceReport.fromLedger(
        rows: const [],
        window: monthlyWindow(2026, 4),
      );

      final transitionWeek = report.weekBuckets.firstWhere(
        (bucket) => bucket.weekStart == DateTime(2026, 4, 19),
      );

      expect(transitionWeek.weekEnd, DateTime(2026, 4, 25));
      expect(transitionWeek.isPartial, isFalse);
      expect(transitionWeek.coveredDayCount, 7);

      expect(
        report.weekBuckets.fold<int>(
          0,
          (total, bucket) => total + bucket.coveredDayCount,
        ),
        30,
      );
    });
  });
}

// The ledger's own `userName` is frozen at close and must win, because a payroll
// artifact has to reproduce the name as of that close. The branch directory only
// fills the gap a phantom no-show leaves behind — it has no attendance record, so
// it has no frozen name, and a raw uid is unreadable to a manager.
void _nameResolutionTests() {
  final july = monthlyWindow(2026, 7);

  test('a phantom no-show takes its name from the branch directory', () {
    final report = MonthlyAttendanceReport.fromLedger(
      rows: [_row(id: 'u1_20260715_morning', userId: 'u1', recordId: null)],
      window: july,
      namesByUid: const {'u1': 'Dina Mostafa'},
    );

    expect(report.employees.single.displayName, 'Dina Mostafa');
  });

  test('the ledger name outranks the directory', () {
    final report = MonthlyAttendanceReport.fromLedger(
      rows: [
        _row(
          id: 'u1_20260715_morning',
          userId: 'u1',
          userName: 'Name At Close',
        ),
      ],
      window: july,
      namesByUid: const {'u1': 'Renamed Later'},
    );

    expect(report.employees.single.displayName, 'Name At Close');
  });

  test('an unknown uid still falls back to the uid, never a blank row', () {
    final report = MonthlyAttendanceReport.fromLedger(
      rows: [_row(id: 'u9_20260715_morning', userId: 'u9')],
      window: july,
      namesByUid: const {'someoneElse': 'Not This Person'},
    );

    expect(report.employees.single.displayName, 'u9');
  });
}
