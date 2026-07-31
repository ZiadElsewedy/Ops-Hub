import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_exception.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_ledger_row.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_period.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_coverage_status.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_weekly_report.dart';

const _branchId = 'DDwedTHvI1sPHrMz06PI';

AttendanceLedgerRow _row({
  required String id,
  required String userId,
  String? userName,
  String dayKey = '20260729',
  String businessDate = '2026-07-29',
  AttendanceLedgerOutcome outcome = AttendanceLedgerOutcome.absent,
  bool expected = true,
  String? recordId,
  int workedMinutes = 0,
  int lateMinutes = 0,
  int overtimeMinutes = 0,
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
  version: 1,
  source: 'system',
  closedAt: DateTime(2026, 7, 29, 18),
);

void main() {
  final window = weeklyWindow(DateTime(2026, 7, 30));

  test('always carries seven Sunday through Saturday day buckets', () {
    final report = WeeklyAttendanceReport.fromLedger(
      rows: const [],
      window: window,
    );

    expect(report.days, hasLength(7));
    expect(report.days.map((day) => day.dayKey), [
      '20260726',
      '20260727',
      '20260728',
      '20260729',
      '20260730',
      '20260731',
      '20260801',
    ]);
    expect(report.coverage.awaitingClose, isTrue);
    expect(report.coverage.status, AttendanceCoverageStatus.noData);
    expect(report.coverage.statusLabel, 'No data yet');
    expect(report.summary.showUpRate.percent, isNull);
  });

  test('production-shape Wednesday phantom absences are a real 0% result', () {
    final report = WeeklyAttendanceReport.fromLedger(
      rows: [
        _row(id: 'u1_20260729_morning', userId: 'u1', userName: 'Amal'),
        _row(id: 'u2_20260729_morning', userId: 'u2', userName: 'Basma'),
        _row(id: 'u3_20260729_morning', userId: 'u3', userName: 'Youssef'),
      ],
      window: window,
    );

    // The honesty fix: rows on one day out of seven still satisfies the close
    // pipeline's `isFullyClosed`, but a week that is 6/7 empty is not something
    // a manager should be told is closed.
    expect(report.coverage.isFullyClosed, isTrue);
    expect(report.coverage.hasDayGaps, isTrue);
    expect(report.coverage.status, AttendanceCoverageStatus.dataGap);
    expect(report.coverage.statusLabel, 'In progress');
    expect(report.coverage.closedDayCount, 1);
    expect(report.coverage.notClosedDayKeys, [
      '20260726',
      '20260727',
      '20260728',
      '20260730',
      '20260731',
      '20260801',
    ]);
    expect(report.summary.expectedWorkShifts, 3);
    expect(report.summary.present, 0);
    expect(report.summary.absent, 3);
    expect(
      report.summary.showUpRate.describe(),
      '0% · 0 / 3 scheduled shifts',
    );
    expect(
      report.days.singleWhere((day) => day.dayKey == '20260729').absent,
      3,
    );
    expect(report.days.where((day) => !day.hasRows), hasLength(6));
  });

  test('blocking exception keeps a row-present period partially closed', () {
    final report = WeeklyAttendanceReport.fromLedger(
      rows: [
        _row(
          id: 'u1_20260729_morning',
          userId: 'u1',
          exceptionCodes: const [AttendanceExceptionCode.missingPunch],
        ),
      ],
      window: window,
    );

    expect(report.coverage.statusLabel, 'Needs attention');
    expect(report.coverage.status, AttendanceCoverageStatus.needsAttention);
    expect(report.coverage.isFullyClosed, isFalse);
    expect(report.coverage.ledgerCoverage.blockingExceptionRowCount, 1);
  });

  test(
    'employee aggregates are alphabetical facts without performance ranking',
    () {
      final report = WeeklyAttendanceReport.fromLedger(
        rows: [
          _row(
            id: 'z_20260729_morning',
            userId: 'z',
            userName: 'Ziad',
            outcome: AttendanceLedgerOutcome.workedLate,
            recordId: 'z_20260729_morning',
            workedMinutes: 460,
            lateMinutes: 20,
            overtimeMinutes: 5,
            exceptionCodes: const [AttendanceExceptionCode.late],
          ),
          _row(id: 'a_20260729_morning', userId: 'a', userName: 'Amal'),
        ],
        window: window,
      );

      expect(report.employees.map((employee) => employee.displayName), [
        'Amal',
        'Ziad',
      ]);
      final ziad = report.employees.last;
      expect(ziad.expected, 1);
      expect(ziad.present, 1);
      expect(ziad.lateMinutes, 20);
      expect(ziad.workedMinutes, 460);
      expect(ziad.overtimeMinutes, 5);
    },
  );

  test('unknown exception wire values remain explicit unrecognized groups', () {
    final report = WeeklyAttendanceReport.fromLedger(
      rows: [
        _row(
          id: 'u1_20260729_morning',
          userId: 'u1',
          unknownExceptionCodes: const ['newServerCode'],
        ),
      ],
      window: window,
    );

    expect(report.exceptionGroups, hasLength(1));
    expect(report.exceptionGroups.single.label, 'Unrecognized: newServerCode');
    expect(report.exceptionGroups.single.blocksClose, isTrue);
    expect(report.coverage.ledgerCoverage.blockingExceptionRowCount, 1);
  });
}
