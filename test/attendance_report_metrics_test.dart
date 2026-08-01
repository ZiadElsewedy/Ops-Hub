import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_ledger_row.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_report.dart';
import 'package:drop/features/attendance/presentation/reporting/widgets/attendance_report_metrics.dart';

AttendanceLedgerRow _phantomAbsent(String id) => AttendanceLedgerRow(
  id: id,
  rowId: id,
  userId: 'u$id',
  userName: 'Employee $id',
  branchId: 'DDwedTHvI1sPHrMz06PI',
  dayKey: '20260729',
  businessDate: '2026-07-29',
  shift: ScheduleShift.morning,
  outcome: AttendanceLedgerOutcome.absent,
  expected: true,
  recordId: null,
  locked: false,
  version: 1,
  source: 'system',
  closedAt: DateTime(2026, 7, 29, 18),
);

void main() {
  testWidgets('metrics disclose denominators for phantom no-show ledger rows', (
    tester,
  ) async {
    final summary = AttendanceReportSummary.fromLedger([
      _phantomAbsent('1'),
      _phantomAbsent('2'),
      _phantomAbsent('3'),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 980,
            child: AttendanceReportMetrics(summary: summary),
          ),
        ),
      ),
    );

    expect(find.text('Scheduled shifts'), findsOneWidget);
    expect(find.text('Present'), findsOneWidget);
    expect(find.text('Absent'), findsOneWidget);
    expect(find.text('Show-up rate'), findsOneWidget);
    expect(find.text('Worked time'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('0 / 3 scheduled shifts'), findsWidgets);
    expect(find.text('3 / 3 scheduled shifts'), findsOneWidget);

    // Nobody worked, so punctuality has a zero denominator. A card reading
    // `--` over `0 / 0` is not a metric — it does not render at all.
    expect(find.text('Punctual arrivals'), findsNothing);
    expect(find.text('--'), findsNothing);
  });

  testWidgets('a computable rate still renders its card', (tester) async {
    final summary = AttendanceReportSummary.fromLedger([
      _phantomAbsent('1'),
      AttendanceLedgerRow(
        id: 'u9_20260729_morning',
        rowId: 'u9_20260729_morning',
        userId: 'u9',
        userName: 'Employee 9',
        branchId: 'DDwedTHvI1sPHrMz06PI',
        dayKey: '20260729',
        businessDate: '2026-07-29',
        shift: ScheduleShift.morning,
        outcome: AttendanceLedgerOutcome.worked,
        expected: true,
        recordId: 'u9_20260729_morning',
        workedMinutes: 480,
        locked: false,
        version: 1,
        source: 'system',
        closedAt: DateTime(2026, 7, 29, 18),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 980,
            child: AttendanceReportMetrics(summary: summary),
          ),
        ),
      ),
    );

    expect(find.text('Punctual arrivals'), findsOneWidget);
    expect(find.text('--'), findsNothing);
  });
}
