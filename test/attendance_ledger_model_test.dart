import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/leave_type.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/attendance/data/models/attendance_ledger_model.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_exception.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_ledger_row.dart';

void main() {
  test('parses the Cloud Function row shape defensively', () {
    final closedAt = DateTime.utc(2026, 7, 16, 1);
    final model = AttendanceLedgerModel.fromMap({
      'rowId': 'u1_20260715_morning',
      'userId': 'u1',
      'userName': 'Alice',
      'branchId': 'b1',
      'dayKey': '20260715',
      'businessDate': '2026-07-15',
      'shift': 'night',
      'scheduledStartAt': Timestamp.fromDate(DateTime.utc(2026, 7, 15, 15)),
      'scheduledEndAt': Timestamp.fromDate(DateTime.utc(2026, 7, 15, 23)),
      'outcome': 'workedLate',
      'expected': true,
      'recordId': 'u1_20260715_morning',
      'leaveType': 'sick',
      'workedMinutes': 440,
      'lateMinutes': 20,
      'earlyLeaveMinutes': 5,
      'overtimeMinutes': 0,
      'breakMinutes': 15,
      'exceptionCodes': ['late', 'earlyLeave'],
      'locked': true,
      'version': 3,
      'closedAt': Timestamp.fromDate(closedAt),
      'restatedAt': null,
      'source': 'system',
      'schemaVersion': 1,
    }, id: 'doc-id');

    expect(model.id, 'doc-id');
    expect(model.rowId, 'u1_20260715_morning');
    expect(model.shift, ScheduleShift.night);
    expect(model.outcome, AttendanceLedgerOutcome.workedLate);
    expect(model.leaveType, LeaveType.sick);
    expect(model.exceptionCodes, [
      AttendanceExceptionCode.late,
      AttendanceExceptionCode.earlyLeave,
    ]);
    // Compare the INSTANT, not the wall-clock representation: Firestore's
    // `Timestamp.toDate()` returns a local-time DateTime, so asserting a UTC
    // literal here would only pass on a UTC+0 machine.
    expect(model.closedAt!.isAtSameMomentAs(closedAt), isTrue);
    expect(model.toEntity().workedMinutes, 440);
  });

  test('missing optional fields and unknown wires do not throw', () {
    final model = AttendanceLedgerModel.fromMap({
      'outcome': 'futureOutcome',
      'exceptionCodes': ['late', 'futureException'],
    });

    expect(model.id, '');
    expect(model.userId, '');
    expect(model.shift, ScheduleShift.morning);
    expect(model.outcome, AttendanceLedgerOutcome.unknown);
    expect(model.expected, isFalse);
    // The unknown code is retained verbatim and NOT coerced into a known code,
    // so nothing false is ever shown to a manager...
    expect(model.exceptionCodes, [AttendanceExceptionCode.late]);
    expect(model.unknownExceptionCodes, ['futureException']);
    // ...while still failing safe: an unrecognized exception blocks the close.
    expect(model.toEntity().hasBlockingException, isTrue);
  });
}
