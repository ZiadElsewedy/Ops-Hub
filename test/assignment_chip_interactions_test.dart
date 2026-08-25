import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:opshub/features/schedule/presentation/widgets/schedule_grid.dart';

/// Schedule V2 · Pillar 2 — Assignment Craft. The new chip interactions all
/// reuse the ONE validated move seam (`onMoveChip`): cross-day drag and
/// keyboard move both land there, exactly like drag-to-move. Touch is untouched.

UserEntity _user(String uid, String name, {String? position}) => UserEntity(
      uid: uid,
      email: '$uid@drop.test',
      displayName: name,
      authProvider: 'password',
      branchId: 'b1',
      position: position,
    );

WeeklyScheduleEntity _sched(
  Map<ScheduleDay, Map<ScheduleShift, List<String>>> assignments,
) =>
    WeeklyScheduleEntity(
      id: 'b1_week',
      branchId: 'b1',
      // Any Sunday; the grid only reads weekStart for the date headers.
      weekStart: DateTime(2026, 6, 14),
      assignments: assignments,
    );

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  Future<void> pumpGrid(
    WidgetTester tester, {
    required WeeklyScheduleEntity schedule,
    required List<UserEntity> members,
    required List<String> moves,
    List<String>? actions,
    Size size = const Size(1600, 1000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(ScheduleGrid(
      schedule: schedule,
      members: members,
      canEdit: true,
      onCellTap: (_, _) {},
      onMoveChip: (data, toDay, toShift) => moves.add(
          '${data.uid}:${data.day.name}/${data.shift.name}'
          '->${toDay.name}/${toShift.name}'),
      onChipActions: actions == null
          ? null
          : (day, shift, uid) => actions.add('$uid:${day.name}/${shift.name}'),
    )));
    await tester.pumpAndSettle();
  }

  // Focus the chip via a context inside it (its own Focus is the nearest
  // enclosing one), then drive the keyboard.
  void focusChip(WidgetTester tester, String shortName) {
    FocusScope.of(tester.element(find.text(shortName))).requestFocus(
        Focus.of(tester.element(find.text(shortName))));
  }

  testWidgets('cross-day drag lands on onMoveChip with the target slot',
      (tester) async {
    final moves = <String>[];
    await pumpGrid(
      tester,
      schedule: _sched({
        ScheduleDay.monday: {
          ScheduleShift.morning: ['u1'],
        },
      }),
      members: [_user('u1', 'Ziad Elsewedy')],
      moves: moves,
    );

    final from = tester.getCenter(find.text('Ziad E.'));
    final to = tester.getCenter(
        find.byKey(const ValueKey('cell-thursday-night')));

    final g = await tester.startGesture(from);
    await g.moveTo(from + const Offset(20, 0)); // claim the pan
    await tester.pump();
    await g.moveTo(to);
    await tester.pump();
    await g.up();
    await tester.pump();

    // Cross-day + cross-shift move routed through the validated seam.
    expect(moves, ['u1:monday/morning->thursday/night']);
  });

  testWidgets('ArrowRight moves to the next day, same shift', (tester) async {
    final moves = <String>[];
    await pumpGrid(
      tester,
      schedule: _sched({
        ScheduleDay.monday: {
          ScheduleShift.morning: ['u1'],
        },
      }),
      members: [_user('u1', 'Ziad Elsewedy')],
      moves: moves,
    );

    focusChip(tester, 'Ziad E.');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(moves, ['u1:monday/morning->tuesday/morning']);
  });

  testWidgets('ArrowDown flips Morning→Night on the same day', (tester) async {
    final moves = <String>[];
    await pumpGrid(
      tester,
      schedule: _sched({
        ScheduleDay.monday: {
          ScheduleShift.morning: ['u1'],
        },
      }),
      members: [_user('u1', 'Ziad Elsewedy')],
      moves: moves,
    );

    focusChip(tester, 'Ziad E.');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(moves, ['u1:monday/morning->monday/night']);
  });

  testWidgets('an edge arrow is consumed with no move', (tester) async {
    final moves = <String>[];
    await pumpGrid(
      tester,
      schedule: _sched({
        // Sunday morning: no day to the left, no shift above.
        ScheduleDay.sunday: {
          ScheduleShift.morning: ['u1'],
        },
      }),
      members: [_user('u1', 'Ziad Elsewedy')],
      moves: moves,
    );

    focusChip(tester, 'Ziad E.');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();

    expect(moves, isEmpty);
  });

  testWidgets('the chip surfaces the position when set', (tester) async {
    await pumpGrid(
      tester,
      schedule: _sched({
        ScheduleDay.monday: {
          ScheduleShift.morning: ['u1'],
        },
      }),
      members: [_user('u1', 'Ziad Elsewedy', position: 'Cashier')],
      moves: <String>[],
    );

    expect(find.textContaining('Cashier'), findsOneWidget);
  });

  testWidgets('touch: long-press still opens the action sheet (unchanged)',
      (tester) async {
    final actions = <String>[];
    await pumpGrid(
      tester,
      // Mobile width — the desktop drag/keyboard affordances are off here.
      size: const Size(420, 900),
      schedule: _sched({
        ScheduleDay.sunday: {
          ScheduleShift.morning: ['u1'],
        },
      }),
      members: [_user('u1', 'Ziad Elsewedy')],
      moves: <String>[],
      actions: actions,
    );

    await tester.longPress(find.text('Ziad E.'));
    await tester.pump();

    expect(actions, ['u1:sunday/morning']);
  });
}
