import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_exception.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_ledger_row.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_period.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_week_review.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_weekly_pdf.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_weekly_report.dart';

void main() {
  final window = weeklyWindow(DateTime(2026, 7, 29));

  AttendanceLedgerRow row({
    String userId = 'u1',
    String? userName = 'Amal',
    AttendanceLedgerOutcome outcome = AttendanceLedgerOutcome.worked,
    int workedMinutes = 480,
    List<AttendanceExceptionCode> exceptionCodes = const [],
  }) => AttendanceLedgerRow(
    id: '${userId}_20260729_morning',
    rowId: '${userId}_20260729_morning',
    userId: userId,
    userName: userName,
    branchId: 'b1',
    dayKey: '20260729',
    businessDate: '2026-07-29',
    shift: ScheduleShift.morning,
    scheduledStartAt: DateTime(2026, 7, 29, 8, 30),
    scheduledEndAt: DateTime(2026, 7, 29, 16, 30),
    outcome: outcome,
    expected: true,
    recordId: '${userId}_20260729_morning',
    workedMinutes: workedMinutes,
    exceptionCodes: exceptionCodes,
    locked: false,
    version: 1,
    source: 'system',
  );

  WeeklyAttendanceReport reportOf(List<AttendanceLedgerRow> rows) =>
      WeeklyAttendanceReport.fromLedger(rows: rows, window: window);

  /// The PDF is a compressed binary, so this is a structural check rather than
  /// a text search: a valid header, a non-trivial size, and a clean EOF.
  void expectValidPdf(List<int> bytes) {
    expect(bytes.length, greaterThan(1000));
    expect(utf8.decode(bytes.take(5).toList()), '%PDF-');
    final tail = latin1.decode(bytes.sublist(bytes.length - 64));
    expect(tail, contains('%%EOF'));
  }

  test('an empty week still produces a valid document', () async {
    // A manager asking for last week's report before anything is recorded gets
    // a document that says so — not a crash and not a zero-filled table.
    final bytes = await buildWeeklyAttendancePdf(
      report: reportOf(const []),
      branchName: 'OpsHub',
      generatedAt: DateTime(2026, 8, 1, 9),
    );
    expectValidPdf(bytes);
  });

  test('a populated week produces a larger document', () async {
    final empty = await buildWeeklyAttendancePdf(
      report: reportOf(const []),
      branchName: 'OpsHub',
      generatedAt: DateTime(2026, 8, 1, 9),
    );
    final full = await buildWeeklyAttendancePdf(
      report: reportOf([
        row(),
        row(userId: 'u2', userName: 'Basma'),
        row(
          userId: 'u3',
          userName: 'Ziad',
          outcome: AttendanceLedgerOutcome.absent,
          workedMinutes: 0,
        ),
      ]),
      branchName: 'OpsHub',
      generatedAt: DateTime(2026, 8, 1, 9),
    );

    expectValidPdf(full);
    expect(full.length, greaterThan(empty.length));
  });

  test('a blocked week renders without failing', () async {
    final bytes = await buildWeeklyAttendancePdf(
      report: reportOf([
        row(exceptionCodes: const [AttendanceExceptionCode.missingPunch]),
      ]),
      branchName: 'OpsHub',
      generatedAt: DateTime(2026, 8, 1, 9),
    );
    expectValidPdf(bytes);
  });

  test('the review state travels into the document', () async {
    final reviewed = AttendanceWeekReviewState.resolve(
      review: AttendanceWeekReview(
        branchId: 'b1',
        weekStartKey: '20260726',
        reviewedBy: 'mgr1',
        reviewedByName: 'Manager One',
        reviewedAt: DateTime(2026, 8, 1, 18),
      ),
      rows: const [],
    );
    final bytes = await buildWeeklyAttendancePdf(
      report: reportOf([row()]),
      branchName: 'OpsHub',
      reviewState: reviewed,
      generatedAt: DateTime(2026, 8, 1, 9),
    );
    expectValidPdf(bytes);
  });

  test('a name that would break a CSV is harmless in a PDF', () async {
    final bytes = await buildWeeklyAttendancePdf(
      report: reportOf([row(userName: 'Amal, "A"')]),
      branchName: 'OpsHub | Arkan',
      generatedAt: DateTime(2026, 8, 1, 9),
    );
    expectValidPdf(bytes);
  });

  test('the filename sorts beside the timesheet', () {
    expect(
      attendanceWeeklyPdfFilename('OpsHub | Arkan', DateTime(2026, 7, 26)),
      'attendance-OpsHub-Arkan-20260726.pdf',
    );
    expect(
      attendanceWeeklyPdfFilename('  ', DateTime(2026, 7, 26)),
      'attendance-branch-20260726.pdf',
    );
  });
}
