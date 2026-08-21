import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/leave_type.dart';
import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/branch/domain/entities/branch_entity.dart';
import 'package:opshub/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:opshub/features/schedule/presentation/pages/schedule_final_view.dart';
import 'package:opshub/features/schedule/presentation/widgets/final_schedule_mobile_view.dart';
import 'package:opshub/features/schedule/presentation/widgets/final_schedule_sheet.dart';

UserEntity _emp(String uid, String name, {String? position}) => UserEntity(
      uid: uid,
      email: '$uid@drop.test',
      authProvider: 'password',
      displayName: name,
      position: position,
    );

UserEntity _mgr(String uid, String name) => UserEntity(
      uid: uid,
      email: '$uid@drop.test',
      authProvider: 'password',
      displayName: name,
      role: UserRole.manager,
    );

const _branch = BranchEntity(id: 'b1', name: 'Drop The Shop | Arkan');

WeeklyScheduleEntity _schedule({
  Map<ScheduleDay, Map<ScheduleShift, List<String>>> assignments = const {},
  Map<ScheduleDay, Map<String, LeaveType>> leave = const {},
  Map<ScheduleDay, String> dayNotes = const {},
}) =>
    WeeklyScheduleEntity(
      id: 'b1_2026-07-05',
      branchId: 'b1',
      weekStart: DateTime(2026, 7, 5),
      assignments: assignments,
      leave: leave,
      dayNotes: dayNotes,
    );

/// A roster exercising every cell token: M · N · OFF · LEAVE · VAC.
WeeklyScheduleEntity _richSchedule({Map<ScheduleDay, String> notes = const {}}) =>
    _schedule(
      assignments: {
        ScheduleDay.sunday: {
          ScheduleShift.morning: ['u1'],
          ScheduleShift.night: ['u2'],
        },
        ScheduleDay.monday: {
          ScheduleShift.night: ['u1'],
        },
      },
      leave: {
        ScheduleDay.tuesday: {'u1': LeaveType.annual}, // VAC
        ScheduleDay.wednesday: {'u1': LeaveType.sick}, // LEAVE
        ScheduleDay.thursday: {'u1': LeaveType.dayOff}, // OFF
      },
      dayNotes: notes,
    );

Future<void> _pumpSheet(
  WidgetTester tester,
  Widget sheet, {
  Size window = const Size(1800, 2200),
}) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Center(child: sheet))),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('FinalScheduleSheet', () {
    testWidgets('renders a shift-row × day-column roster with names in cells',
        (tester) async {
      await _pumpSheet(
        tester,
        FinalScheduleSheet(
          schedule: _richSchedule(notes: {ScheduleDay.sunday: 'Inventory delivery'}),
          members: [_emp('u1', 'Salah Ahmed', position: 'Cashier'), _emp('u2', 'Mona Adel')],
          branch: _branch,
          managerName: 'Rana Fouad',
          generatedAt: DateTime(2026, 7, 9),
        ),
      );

      // Document header: brand · branch · week · generated · manager.
      // The brand mark appears twice: the header wordmark and the footer byline.
      expect(find.text('Drop Operations'), findsNWidgets(2));
      expect(find.text('Drop The Shop | Arkan'), findsOneWidget);
      expect(find.text('05/07 – 11/07'), findsOneWidget);
      expect(find.text('MANAGER'), findsOneWidget);
      expect(find.text('Rana Fouad'), findsOneWidget);

      // The grid is keyed by SHIFT down the side, days across the top.
      expect(find.text('SHIFT'), findsOneWidget);
      expect(find.text('Morning'), findsWidgets);
      expect(find.text('Night'), findsWidgets);
      expect(find.text('Off'), findsWidgets);

      // Day columns Sun→Sat.
      for (final d in ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT']) {
        expect(find.text(d), findsOneWidget);
      }

      // People are named inside the cells (u1 works Sun morning / Mon night, and
      // is off on the other days, so appears repeatedly).
      expect(find.text('Salah Ahmed'), findsWidgets);
      expect(find.text('Mona Adel'), findsWidgets);

      // The Off row tags vacation (V) and leave (L) inline.
      expect(find.textContaining('Salah Ahmed (V)'), findsWidgets); // Tue = annual
      expect(find.textContaining('Salah Ahmed (L)'), findsWidgets); // Wed = sick

      // Notes row present with the day note.
      expect(find.text('NOTES'), findsOneWidget);
      expect(find.textContaining('Inventory delivery'), findsOneWidget);

      // Read-only: no editing affordances.
      expect(find.byType(Draggable), findsNothing);
    });

    testWidgets('lists only people actually on the schedule, not every member',
        (tester) async {
      await _pumpSheet(
        tester,
        FinalScheduleSheet(
          // u1 works Sun morning / Mon night; u2 works Sun night. u3 belongs to
          // the branch but is never assigned this week.
          schedule: _richSchedule(),
          members: [
            _emp('u1', 'Salah Ahmed'),
            _emp('u2', 'Mona Adel'),
            _emp('u3', 'Unscheduled Person'),
          ],
          branch: _branch,
        ),
      );
      // The scheduled people are on the sheet…
      expect(find.text('Salah Ahmed'), findsWidgets);
      expect(find.text('Mona Adel'), findsWidgets);
      // …but a member with no shift this week is not a phantom row/cell.
      expect(find.text('Unscheduled Person'), findsNothing);
    });

    testWidgets('empty notes → no notes row', (tester) async {
      await _pumpSheet(
        tester,
        FinalScheduleSheet(
          schedule: _richSchedule(), // no dayNotes
          members: [_emp('u1', 'Salah Ahmed')],
          branch: _branch,
        ),
      );
      expect(find.text('NOTES'), findsNothing);
      // The roster itself still renders (the shift rows are present).
      expect(find.text('Morning'), findsWidgets);
      expect(find.text('Salah Ahmed'), findsWidgets);
    });

    testWidgets('handles a large roster without overflowing', (tester) async {
      final many = [for (var i = 0; i < 22; i++) _emp('u$i', 'Employee Number $i')];
      final assignments = {
        for (final d in ScheduleDay.values)
          d: {
            ScheduleShift.morning: [for (var i = 0; i < 11; i++) 'u$i'],
            ScheduleShift.night: [for (var i = 11; i < 22; i++) 'u$i'],
          },
      };
      await _pumpSheet(
        tester,
        FinalScheduleSheet(
          schedule: _schedule(assignments: assignments),
          members: many,
          branch: _branch,
        ),
        window: const Size(1800, 3200),
      );
      // No layout exception, and names render inside the shift-row cells.
      expect(tester.takeException(), isNull);
      expect(find.text('Employee Number 0'), findsWidgets);
      expect(find.text('Employee Number 21'), findsWidgets);
    });

    testWidgets('is a fixed-width landscape export document', (tester) async {
      await _pumpSheet(
        tester,
        FinalScheduleSheet(
          schedule: _richSchedule(),
          members: [_emp('u1', 'Salah Ahmed'), _emp('u2', 'Mona Adel')],
          branch: _branch,
        ),
      );
      final size = tester.getSize(find.byType(FinalScheduleSheet));
      expect(size.width, 1600);
      // Landscape: for a small roster the document is wider than it is tall.
      expect(size.width, greaterThan(size.height));
    });
  });

  group('ScheduleFinalView page', () {
    testWidgets('shows the sheet + read-only export toolbar', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: ScheduleFinalView(
            schedule: _richSchedule(),
            members: [_emp('u1', 'Salah Ahmed'), _mgr('u2', 'Mona Adel')],
            branch: _branch,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FinalScheduleSheet), findsOneWidget);
      expect(find.text('Drop The Shop | Arkan'), findsOneWidget);
      // The manager is derived from the members for the header (they also appear
      // as a roster row, so the name shows in both places).
      expect(find.text('MANAGER'), findsOneWidget);
      expect(find.text('Mona Adel'), findsWidgets);
      // Navigation + export chrome (not captured in the export file).
      expect(find.text('Back to schedule'), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);
      // Still read-only.
      expect(find.byType(Draggable), findsNothing);
    });

    testWidgets('desktop shows the print sheet; a phone shows the day list',
        (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      tester.view.devicePixelRatio = 1.0;

      // Wide (desktop): the landscape print sheet is the on-screen view.
      tester.view.physicalSize = const Size(1680, 1050);
      await tester.pumpWidget(
        MaterialApp(
          home: ScheduleFinalView(
            schedule: _richSchedule(),
            members: [_emp('u1', 'Salah Ahmed'), _mgr('u2', 'Mona Adel')],
            branch: _branch,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(FinalScheduleSheet), findsOneWidget);
      expect(find.byType(FinalScheduleMobileView), findsNothing);

      // Narrow (phone): the readable day-by-day list shows instead, while the
      // print sheet is still rendered off-screen for the PNG export.
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpWidget(
        MaterialApp(
          home: ScheduleFinalView(
            schedule: _richSchedule(),
            members: [_emp('u1', 'Salah Ahmed'), _mgr('u2', 'Mona Adel')],
            branch: _branch,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(FinalScheduleMobileView), findsOneWidget);
      expect(find.byType(FinalScheduleSheet), findsOneWidget); // off-screen
    });
  });

  test('export filename is stable and filesystem-safe', () {
    expect(
      scheduleExportFilename('Drop The Shop | Arkan', DateTime(2026, 7, 5)),
      'drop_the_shop_arkan_schedule_2026-07-05.png',
    );
  });
}
