import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_exception.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_ledger_row.dart';

AttendanceLedgerRow _row({
  String id = 'u1_20260715_morning',
  AttendanceLedgerOutcome outcome = AttendanceLedgerOutcome.worked,
  List<AttendanceExceptionCode> exceptionCodes = const [],
  DateTime? closedAt,
}) => AttendanceLedgerRow(
  id: id,
  rowId: id,
  userId: 'u1',
  branchId: 'b1',
  dayKey: '20260715',
  businessDate: '2026-07-15',
  shift: ScheduleShift.morning,
  outcome: outcome,
  expected: true,
  exceptionCodes: exceptionCodes,
  closedAt: closedAt,
);

void main() {
  test('ledger coverage distinguishes no rows from closed rows', () {
    expect(LedgerCoverage.fromRows(const []).awaitingClose, isTrue);

    final coverage = LedgerCoverage.fromRows([
      _row(closedAt: DateTime(2026, 7, 16)),
      _row(
        id: 'u2_20260715_morning',
        closedAt: DateTime(2026, 7, 16),
        exceptionCodes: const [AttendanceExceptionCode.pendingCorrection],
      ),
    ]);

    expect(coverage.hasRows, isTrue);
    expect(coverage.awaitingClose, isFalse);
    expect(coverage.closedRowCount, 2);
    expect(coverage.blockingExceptionRowCount, 1);
  });

  test('unknown outcome is unresolved and does not count as present', () {
    final outcome = AttendanceLedgerOutcome.fromWire('futureOutcome');

    expect(outcome, AttendanceLedgerOutcome.unknown);
    expect(outcome.countsAsPresent, isFalse);
    expect(outcome.countsAsAbsence, isFalse);
    expect(outcome.isUnresolved, isTrue);
  });

  test('an unknown exception code is not relabelled as a known one', () {
    // It must NOT become `implausibleRecord`: that would show a manager a
    // specific, false claim about the record. Unknown stays unknown.
    expect(attendanceExceptionCodeFromWire('future_blocker'), isNull);
    expect(attendanceExceptionCodeFromWire('late'),
        AttendanceExceptionCode.late);
  });

  test('an unknown exception code still blocks close (fail-safe)', () {
    const row = AttendanceLedgerRow(
      id: 'u1_20260715_morning',
      rowId: 'u1_20260715_morning',
      userId: 'u1',
      branchId: 'b1',
      dayKey: '20260715',
      businessDate: '2026-07-15',
      shift: ScheduleShift.morning,
      outcome: AttendanceLedgerOutcome.worked,
      expected: true,
      unknownExceptionCodes: ['future_blocker'],
    );

    expect(row.exceptionCodes, isEmpty);
    expect(row.hasBlockingException, isTrue);
  });
}
