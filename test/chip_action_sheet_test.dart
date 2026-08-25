import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:opshub/features/schedule/presentation/widgets/chip_action_sheet.dart';
import 'package:opshub/features/schedule/presentation/widgets/shift_cell.dart';

/// Schedule 4.0 — the mobile chip action sheet (move · switch · remove with
/// preview + confirm) and the crowded-cell "+N more" rule.

UserEntity _user(String uid, String name) => UserEntity(
      uid: uid,
      email: '$uid@drop.test',
      displayName: name,
      authProvider: 'password',
      branchId: 'b1',
    );

WeeklyScheduleEntity _schedule() => WeeklyScheduleEntity(
      id: 'b1_w',
      branchId: 'b1',
      weekStart: DateTime(2026, 6, 28),
      assignments: {
        ScheduleDay.monday: {
          ScheduleShift.morning: ['ziad'],
          ScheduleShift.night: ['richard'],
        },
      },
    );

Future<void> _openSheet(
  WidgetTester tester, {
  required void Function(ScheduleDay, ScheduleShift) onMove,
  required void Function(String, ScheduleDay, ScheduleShift) onExchange,
  required VoidCallback onRemove,
}) async {
  final members = [_user('ziad', 'Ziad Sewedy'), _user('richard', 'Richard M')];
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showChipActionSheet(
            context: context,
            schedule: _schedule(),
            members: members,
            user: members.first,
            day: ScheduleDay.monday,
            shift: ScheduleShift.morning,
            onMove: onMove,
            onExchange: onExchange,
            onRemove: onRemove,
          ),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('remove action fires the callback', (tester) async {
    var removed = false;
    await _openSheet(
      tester,
      onMove: (_, _) {},
      onExchange: (_, _, _) {},
      onRemove: () => removed = true,
    );

    await tester.tap(find.text('Remove from this shift'));
    await tester.pumpAndSettle();

    expect(removed, isTrue);
    expect(find.text('Remove from this shift'), findsNothing,
        reason: 'the sheet closes before the mutation runs');
  });

  testWidgets('move step picks a legal slot', (tester) async {
    ScheduleDay? day;
    ScheduleShift? shift;
    await _openSheet(
      tester,
      onMove: (d, s) {
        day = d;
        shift = s;
      },
      onExchange: (_, _, _) {},
      onRemove: () {},
    );

    await tester.tap(find.text('Move to another shift'));
    await tester.pumpAndSettle();
    expect(find.text('Pick the new shift'), findsOneWidget);
    expect(find.text('Current'), findsOneWidget);

    // Tuesday morning (second day row, first shift button).
    await tester.tap(find.text('Morning').at(1));
    await tester.pumpAndSettle();

    expect(day, ScheduleDay.tuesday);
    expect(shift, ScheduleShift.morning);
  });

  testWidgets('switch flow previews the trade before confirming',
      (tester) async {
    String? withUid;
    await _openSheet(
      tester,
      onMove: (_, _) {},
      onExchange: (uid, _, _) => withUid = uid,
      onRemove: () {},
    );

    await tester.tap(find.text('Switch shifts with…'));
    await tester.pumpAndSettle();
    expect(find.text('Pick who to switch with'), findsOneWidget);

    await tester.tap(find.text('Richard M'));
    await tester.pumpAndSettle();

    // Preview: both sides of the trade + the confirm CTA. Nothing has been
    // committed yet.
    expect(find.text('Review the switch'), findsOneWidget);
    expect(withUid, isNull);

    await tester.tap(find.textContaining('Switch Ziad'));
    await tester.pumpAndSettle();

    expect(withUid, 'richard');
  });

  testWidgets('cell shows all chips at 4 people and "+N more" beyond',
      (tester) async {
    Widget cell(List<UserEntity> users) => MaterialApp(
          home: Scaffold(
            body: ShiftCell(
              users: users,
              day: ScheduleDay.monday,
              shift: ScheduleShift.morning,
              isToday: false,
              hasOrphan: false,
              width: 128,
              height: 122,
              onTap: () {},
            ),
          ),
        );

    final four = [for (var i = 0; i < 4; i++) _user('u$i', 'User$i X')];
    await tester.pumpWidget(cell(four));
    expect(find.textContaining('more'), findsNothing,
        reason: 'four people all render — no overflow pill');

    final six = [for (var i = 0; i < 6; i++) _user('u$i', 'User$i X')];
    await tester.pumpWidget(cell(six));
    expect(find.text('+3 more'), findsOneWidget,
        reason: 'six people collapse to 3 chips + "+3 more"');
  });
}
