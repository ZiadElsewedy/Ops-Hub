import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/leave_type.dart';
import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:opshub/features/schedule/presentation/widgets/schedule_grid.dart';

UserEntity _member(String uid, {String? name}) => UserEntity(
    uid: uid,
    email: '$uid@drop.test',
    displayName: name,
    authProvider: 'password');

WeeklyScheduleEntity _schedule(
  Map<ScheduleDay, Map<ScheduleShift, List<String>>> assignments, {
  Map<ScheduleDay, String> dayNotes = const {},
  Map<ScheduleDay, Map<String, LeaveType>> leave = const {},
}) {
  // Any Sunday works; the grid only uses weekStart for the date headers.
  return WeeklyScheduleEntity(
    id: 'b1_2026-06-14',
    branchId: 'b1',
    weekStart: DateTime(2026, 6, 14),
    assignments: assignments,
    dayNotes: dayNotes,
    leave: leave,
  );
}

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows assigned people and excludes broken references',
      (tester) async {
    final members = [
      _member('u1', name: 'Ahmed Maher'),
      _member('u2', name: 'Omar Ali'),
    ];
    final schedule = _schedule({
      ScheduleDay.sunday: {
        // Two real members + one orphan uid that no longer maps to a member.
        ScheduleShift.morning: ['u1', 'u2', 'ghost'],
      },
    });

    await tester.pumpWidget(host(ScheduleGrid(
      schedule: schedule,
      members: members,
      onCellTap: (_, _) {},
    )));

    // The cell names the two real, resolvable employees (compact form).
    expect(find.text('Ahmed M.'), findsOneWidget);
    expect(find.text('Omar A.'), findsOneWidget);
    // The orphan is excluded — never shown as a name/uid, only flagged.
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.textContaining('ghost'), findsNothing);
    // Two real people → no "+N more" overflow line.
    expect(find.textContaining('more'), findsNothing);
    // Staffing at a glance: the quiet corner count for the staffed cell.
    expect(find.text('2'), findsOneWidget);
    // No staffing target / quota is ever rendered.
    expect(find.textContaining('of '), findsNothing);
  });

  testWidgets('empty shifts read as "Open", not as a shortfall',
      (tester) async {
    await tester.pumpWidget(host(ScheduleGrid(
      schedule: _schedule(const {}),
      members: const [],
      onCellTap: (_, _) {},
    )));

    // 14 slots (7 days x 2 shifts), all empty.
    expect(find.text('Open'), findsNWidgets(14));
  });

  testWidgets('tapping a cell reports its day and shift', (tester) async {
    ScheduleDay? tappedDay;
    ScheduleShift? tappedShift;

    await tester.pumpWidget(host(ScheduleGrid(
      schedule: _schedule(const {}),
      members: const [],
      onCellTap: (d, s) {
        tappedDay = d;
        tappedShift = s;
      },
    )));

    // First cell (Sunday morning) is the first "Open" in document order.
    await tester.tap(find.text('Open').first);
    await tester.pump();

    expect(tappedDay, ScheduleDay.sunday);
    expect(tappedShift, ScheduleShift.morning);
  });

  testWidgets('shift filter hides the other shift row', (tester) async {
    await tester.pumpWidget(host(ScheduleGrid(
      schedule: _schedule(const {}),
      members: const [],
      filter: ScheduleShift.night,
      onCellTap: (_, _) {},
    )));

    // Only the night row renders → 7 cells, not 14.
    expect(find.text('Open'), findsNWidgets(7));
  });

  testWidgets('weekend day headers carry the late-closing tag',
      (tester) async {
    await tester.pumpWidget(host(ScheduleGrid(
      schedule: _schedule(const {}),
      members: const [],
      onCellTap: (_, _) {},
    )));

    // Thursday · Friday · Saturday nights run till 00:00 (midnight).
    expect(find.text('till 00:00'), findsNWidgets(3));
  });

  testWidgets('leave entries and day notes are visible without opening '
      'anything', (tester) async {
    final members = [_member('u1', name: 'Ahmed Maher')];
    final schedule = _schedule(
      const {},
      dayNotes: const {ScheduleDay.monday: 'Inventory'},
      leave: const {
        ScheduleDay.sunday: {'u1': LeaveType.sick},
        // Orphaned leave (no matching member) must never render a pill.
        ScheduleDay.tuesday: {'ghost': LeaveType.annual},
      },
    );

    ScheduleDay? tappedDay;
    await tester.pumpWidget(host(ScheduleGrid(
      schedule: schedule,
      members: members,
      canEdit: true,
      onDayTap: (d) => tappedDay = d,
      onCellTap: (_, _) {},
    )));

    expect(find.text('Ahmed · Sick'), findsOneWidget);
    expect(find.text('Inventory'), findsOneWidget);
    expect(find.textContaining('ghost'), findsNothing);

    // Tapping the leave/notes strip opens the day sheet for that day.
    await tester.tap(find.text('Ahmed · Sick'));
    await tester.pump();
    expect(tappedDay, ScheduleDay.sunday);
  });

  testWidgets('presentation mode renders a print-clean roster',
      (tester) async {
    final members = [_member('u1', name: 'Ahmed Maher')];
    final schedule = _schedule({
      ScheduleDay.sunday: {
        ScheduleShift.morning: ['u1'],
      },
    });

    await tester.pumpWidget(host(ScheduleGrid(
      schedule: schedule,
      members: members,
      presentation: true,
      onCellTap: (_, _) {},
    )));

    // No editing affordances: no "Open" placeholders, no drag targets exposed
    // as dashes — empty slots are quiet em-dashes.
    expect(find.text('Open'), findsNothing);
    expect(find.text('—'), findsNWidgets(13));
    expect(find.text('Ahmed M.'), findsOneWidget);
    // No leave/notes in this week → the day-info strip stays out of the print.
    expect(find.text('Leave &\nnotes'), findsNothing);
  });
}
