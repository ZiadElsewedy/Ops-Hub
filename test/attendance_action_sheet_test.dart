import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/features/attendance/presentation/widgets/attendance_action_sheet.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('collects a reason and reports success through onSubmit',
      (tester) async {
    AttendanceActionResult? captured;
    await tester.pumpWidget(host(
      AttendanceActionSheet(
        title: 'Request a correction',
        subtitle: 'Propose the right times',
        submitLabel: 'Send request',
        askTimes: true,
        day: DateTime(2026, 7, 13),
        seedClockIn: DateTime(2026, 7, 13, 8, 30),
        seedClockOut: DateTime(2026, 7, 13, 16, 30),
        onSubmit: (r) async {
          captured = r;
          return true;
        },
      ),
    ));

    expect(find.text('Request a correction'), findsOneWidget);
    // Seeded times render on the two time fields.
    expect(find.text('08:30'), findsOneWidget);
    expect(find.text('16:30'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Left at 16:30');
    await tester.tap(find.text('Send request'));
    await tester.pump();

    expect(captured, isNotNull);
    expect(captured!.reason, 'Left at 16:30');
    expect(captured!.clockIn, DateTime(2026, 7, 13, 8, 30));
    expect(captured!.clockOut, DateTime(2026, 7, 13, 16, 30));
  });

  testWidgets('reason-only mode hides the time fields', (tester) async {
    await tester.pumpWidget(host(
      AttendanceActionSheet(
        title: 'Excuse absence',
        subtitle: 'Forgive the missed shift',
        submitLabel: 'Excuse',
        askTimes: false,
        day: DateTime(2026, 7, 13),
        onSubmit: (_) async => true,
      ),
    ));

    expect(find.text('Clock in'), findsNothing);
    expect(find.text('Clock out'), findsNothing);
    expect(find.byType(TextField), findsOneWidget); // just the reason
  });

  testWidgets('a failed submit re-enables the button (stays open)',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(host(
      AttendanceActionSheet(
        title: 'Add attendance record',
        subtitle: 'Record the shift',
        submitLabel: 'Add record',
        askTimes: false,
        day: DateTime(2026, 7, 13),
        onSubmit: (_) async {
          calls++;
          return false; // validation blocked
        },
      ),
    ));

    await tester.tap(find.text('Add record'));
    await tester.pump();
    await tester.pump();

    expect(calls, 1);
    // The action label is back (not stuck on "Saving…") so the user can retry.
    expect(find.text('Add record'), findsOneWidget);
    expect(find.text('Saving…'), findsNothing);
  });
}
