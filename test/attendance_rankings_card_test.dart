import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/theme/app_theme.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_exception.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_ledger_row.dart';
import 'package:opshub/features/attendance/presentation/reporting/widgets/attendance_rankings_card.dart';

AttendanceLedgerRow _row({
  required String userId,
  required String userName,
  int overtime = 0,
  int late = 0,
  List<AttendanceExceptionCode> exceptions = const [],
  String dayKey = '20260701',
}) => AttendanceLedgerRow(
  id: '${userId}_${dayKey}_morning',
  rowId: '${userId}_${dayKey}_morning',
  userId: userId,
  userName: userName,
  branchId: 'b1',
  dayKey: dayKey,
  businessDate: '2026-07-01',
  shift: ScheduleShift.morning,
  outcome: AttendanceLedgerOutcome.worked,
  expected: true,
  overtimeMinutes: overtime,
  lateMinutes: late,
  exceptionCodes: exceptions,
);

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('ranks the default (overtime) board highest-first', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        AttendanceRankingsCard(
          rows: [
            _row(userId: 'a', userName: 'Amal', overtime: 30),
            _row(userId: 'b', userName: 'Basma', overtime: 90),
          ],
        ),
      ),
    );

    expect(find.text('Rankings'), findsOneWidget);
    expect(find.text('Who worked the most overtime?'), findsOneWidget);
    // Basma (90m = 1h 30m) leads; Amal (30m) follows.
    expect(find.text('Basma'), findsOneWidget);
    expect(find.text('1h 30m'), findsOneWidget);
    expect(find.text('30m'), findsOneWidget);
  });

  testWidgets('switching the metric re-ranks the board', (tester) async {
    await tester.pumpWidget(
      _host(
        AttendanceRankingsCard(
          rows: [
            _row(userId: 'a', userName: 'Amal', overtime: 90, late: 5),
            _row(userId: 'b', userName: 'Basma', overtime: 10, late: 40),
          ],
        ),
      ),
    );

    // Overtime board leads with Amal.
    expect(find.text('Who worked the most overtime?'), findsOneWidget);

    await tester.tap(find.text('Lateness'));
    await tester.pumpAndSettle();

    // Now it's the lateness question, and Basma (40m late) is on the board.
    expect(find.text('Who was late the most?'), findsOneWidget);
    expect(find.text('40m'), findsOneWidget);
  });

  testWidgets('shows a calm empty line when nobody has the metric', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        AttendanceRankingsCard(
          rows: [_row(userId: 'a', userName: 'Amal', overtime: 0)],
        ),
      ),
    );

    expect(find.text('No overtime recorded this period.'), findsOneWidget);
  });
}
