import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/theme/app_theme.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:opshub/features/schedule/presentation/widgets/schedule_day_editor.dart';

UserEntity _emp(String uid, String name) => UserEntity(
      uid: uid,
      email: '$uid@drop.test',
      authProvider: 'password',
      displayName: name,
    );

/// Sunday 5 Jul 2026 — a week that is NOT the current week, so the editor's
/// default selection is deterministic (Sunday, not "today").
final _weekStart = DateTime(2026, 7, 5);

WeeklyScheduleEntity _schedule() => WeeklyScheduleEntity(
      id: 'b1_2026-07-05',
      branchId: 'b1',
      weekStart: _weekStart,
      assignments: const {
        ScheduleDay.sunday: {
          ScheduleShift.morning: ['u1'],
          // night deliberately empty → "Open"
        },
        ScheduleDay.monday: {
          ScheduleShift.morning: ['u2'],
        },
      },
    );

void main() {
  Future<_Calls> pump(WidgetTester tester) async {
    final calls = _Calls();
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: ListView(
            children: [
              ScheduleDayEditor(
                schedule: _schedule(),
                members: [_emp('u1', 'Salah Ahmed'), _emp('u2', 'Mona Adel')],
                canEdit: true,
                onAdd: (d, s) => calls.add.add((d, s)),
                onRemove: (d, s, u) => calls.remove.add((d, s, u)),
                onMove: (d, s, u) => calls.move.add((d, s, u)),
                onPersonTap: (d, s, u) => calls.tap.add((d, s, u)),
                onDayDetails: calls.dayDetails.add,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return calls;
  }

  testWidgets('opens on Sunday: shows both shifts, the person, and an Open tag',
      (tester) async {
    await pump(tester);
    expect(find.text('Sunday'), findsOneWidget);
    expect(find.text('Morning'), findsOneWidget);
    expect(find.text('Night'), findsOneWidget);
    expect(find.text('Salah Ahmed'), findsOneWidget); // Sun morning
    expect(find.text('OPEN'), findsOneWidget); // Sun night is empty
    expect(find.text('Add to morning'), findsOneWidget);
    expect(find.text('Add to night'), findsOneWidget);
  });

  testWidgets('switching day swaps the roster shown', (tester) async {
    await pump(tester);
    expect(find.text('Salah Ahmed'), findsOneWidget);
    expect(find.text('Mona Adel'), findsNothing);

    await tester.tap(find.text('MON'));
    await tester.pumpAndSettle();

    expect(find.text('Monday'), findsOneWidget);
    expect(find.text('Mona Adel'), findsOneWidget); // Mon morning
    expect(find.text('Salah Ahmed'), findsNothing);
  });

  testWidgets('add / remove / move fire the host handlers with the slot',
      (tester) async {
    final calls = await pump(tester);

    await tester.tap(find.text('Add to night'));
    expect(calls.add.single, (ScheduleDay.sunday, ScheduleShift.night));

    await tester.tap(find.byIcon(Icons.close_rounded));
    expect(calls.remove.single,
        (ScheduleDay.sunday, ScheduleShift.morning, 'u1'));

    await tester.tap(find.byIcon(Icons.swap_vert_rounded));
    expect(
        calls.move.single, (ScheduleDay.sunday, ScheduleShift.morning, 'u1'));
  });

  testWidgets('Notes & leave opens the day details handler', (tester) async {
    final calls = await pump(tester);
    await tester.tap(find.text('Notes & leave'));
    expect(calls.dayDetails.single, ScheduleDay.sunday);
  });
}

class _Calls {
  final add = <(ScheduleDay, ScheduleShift)>[];
  final remove = <(ScheduleDay, ScheduleShift, String)>[];
  final move = <(ScheduleDay, ScheduleShift, String)>[];
  final tap = <(ScheduleDay, ScheduleShift, String)>[];
  final dayDetails = <ScheduleDay>[];
}
