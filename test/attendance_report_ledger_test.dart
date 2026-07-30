import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/features/attendance/domain/attendance_calculator.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_exception.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_expectation.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_ledger_row.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_report.dart';

AttendanceLedgerRow _ledger({
  required String id,
  required AttendanceLedgerOutcome outcome,
  bool expected = true,
  int worked = 0,
  int late = 0,
  int early = 0,
  int overtime = 0,
  List<AttendanceExceptionCode> exceptions = const [],
}) => AttendanceLedgerRow(
  id: id,
  rowId: id,
  userId: id.split('_').first,
  branchId: 'b1',
  dayKey: '20260715',
  businessDate: '2026-07-15',
  shift: ScheduleShift.morning,
  outcome: outcome,
  expected: expected,
  workedMinutes: worked,
  lateMinutes: late,
  earlyLeaveMinutes: early,
  overtimeMinutes: overtime,
  exceptionCodes: exceptions,
  closedAt: DateTime(2026, 7, 16),
);

ExpectedShiftRow _expected({
  required String uid,
  required ExpectedShiftOutcome outcome,
  int worked = 0,
  int late = 0,
  int early = 0,
  int overtime = 0,
  List<AttendanceExceptionCode> exceptions = const [],
}) => ExpectedShiftRow(
  uid: uid,
  branchId: 'b1',
  date: DateTime(2026, 7, 15),
  shift: ScheduleShift.morning,
  scheduledStart: DateTime(2026, 7, 15, 8, 30),
  scheduledEnd: DateTime(2026, 7, 15, 16, 30),
  outcome: outcome,
  recordId: '${uid}_20260715_morning',
  leaveType: null,
  totals: AttendanceTotals(
    workedMinutes: worked,
    lateMinutes: late,
    earlyLeaveMinutes: early,
    overtimeMinutes: overtime,
  ),
  exceptions: exceptions,
);

void main() {
  test('folds persisted ledger rows into explicit-denominator metrics', () {
    final summary = AttendanceReportSummary.fromLedger([
      _ledger(
        id: 'u1_20260715_morning',
        outcome: AttendanceLedgerOutcome.worked,
        worked: 480,
      ),
      _ledger(
        id: 'u2_20260715_morning',
        outcome: AttendanceLedgerOutcome.workedLate,
        worked: 450,
        late: 12,
        exceptions: const [AttendanceExceptionCode.late],
      ),
      _ledger(
        id: 'u3_20260715_morning',
        outcome: AttendanceLedgerOutcome.absent,
      ),
      _ledger(
        id: 'u4_20260715_morning',
        outcome: AttendanceLedgerOutcome.excused,
        expected: false,
      ),
      _ledger(
        id: 'u5_20260715_morning',
        outcome: AttendanceLedgerOutcome.onLeave,
        expected: false,
      ),
      _ledger(
        id: 'u6_20260715_morning',
        outcome: AttendanceLedgerOutcome.worked,
        expected: false,
        exceptions: const [AttendanceExceptionCode.unscheduledWork],
      ),
    ]);

    expect(summary.expectedWorkShifts, 3);
    expect(summary.present, 2);
    expect(summary.absent, 1);
    expect(summary.excused, 1);
    expect(summary.onLeave, 1);
    expect(summary.unscheduledWork, 1);
    expect(summary.lateArrivals, 1);
    expect(summary.workedMinutes, 930);
    expect(summary.showUpRate.describe(), '67% · 2 / 3 expected work shifts');
    expect(
      summary.punctualArrivalRate.describe(),
      '50% · 1 / 2 present scheduled arrivals',
    );
  });

  test(
    'ledger aggregation matches the parity row definitions for known rows',
    () {
      final fromLedger = AttendanceReportSummary.fromLedger([
        _ledger(
          id: 'u1_20260715_morning',
          outcome: AttendanceLedgerOutcome.workedLate,
          worked: 420,
          late: 15,
          early: 10,
          exceptions: const [
            AttendanceExceptionCode.late,
            AttendanceExceptionCode.earlyLeave,
          ],
        ),
        _ledger(
          id: 'u2_20260715_morning',
          outcome: AttendanceLedgerOutcome.absent,
        ),
      ]);

      final fromRows = AttendanceReportSummary.fromRows([
        _expected(
          uid: 'u1',
          outcome: ExpectedShiftOutcome.workedLate,
          worked: 420,
          late: 15,
          early: 10,
          exceptions: const [
            AttendanceExceptionCode.late,
            AttendanceExceptionCode.earlyLeave,
          ],
        ),
        _expected(uid: 'u2', outcome: ExpectedShiftOutcome.absent),
      ]);

      expect(fromLedger, fromRows);
    },
  );
}
