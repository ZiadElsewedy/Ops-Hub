import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/auth/domain/usecases/get_users_by_branch.dart';
import 'package:opshub/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:opshub/features/schedule/domain/repositories/schedule_repository.dart';
import 'package:opshub/features/schedule/domain/schedule_week.dart';
import 'package:opshub/features/schedule/presentation/cubit/schedule_cubit.dart';
import 'package:opshub/features/schedule/presentation/widgets/schedule_grid.dart';
import 'support/fake_shift_template_repository.dart';

/// Schedule 3.1 — drag one person ONTO another and the two trade slots.
/// Covers the cubit's [ScheduleCubit.exchange] (assign-first ordering +
/// no-op guards) and the grid wiring (a chip is a drop target that wins the
/// hit test over its host cell).

class _RecordingRepo implements ScheduleRepository {
  final calls = <String>[];

  @override
  Future<void> assignEmployee({
    required String scheduleId,
    required ScheduleDay day,
    required ScheduleShift shift,
    required String employeeId,
  }) async {
    calls.add('assign:$employeeId:${day.name}:${shift.name}');
  }

  @override
  Future<void> removeEmployee({
    required String scheduleId,
    required ScheduleDay day,
    required ScheduleShift shift,
    required String employeeId,
  }) async {
    calls.add('remove:$employeeId:${day.name}:${shift.name}');
  }

  @override
  Future<void> moveEmployee({
    required String scheduleId,
    required ScheduleDay fromDay,
    required ScheduleShift fromShift,
    required ScheduleDay toDay,
    required ScheduleShift toShift,
    required String employeeId,
  }) async {
    calls.add('move:$employeeId:${fromDay.name}:${fromShift.name}'
        '->${toDay.name}:${toShift.name}');
  }

  @override
  Future<void> exchangeEmployees({
    required String scheduleId,
    required ScheduleDay dayA,
    required ScheduleShift shiftA,
    required String uidA,
    required ScheduleDay dayB,
    required ScheduleShift shiftB,
    required String uidB,
  }) async {
    calls.add('exchange:$uidA:${dayA.name}:${shiftA.name}'
        '<->$uidB:${dayB.name}:${shiftB.name}');
  }

  @override
  Future<WeeklyScheduleEntity?> getSchedule(
          String branchId, DateTime weekStart) async =>
      null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeGetUsersByBranch implements GetUsersByBranch {
  @override
  Future<List<UserEntity>> call(String branchId) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserEntity _user(String uid, String name) => UserEntity(
      uid: uid,
      email: '$uid@drop.test',
      displayName: name,
      authProvider: 'password',
      branchId: 'b1',
    );

void main() {
  group('ScheduleCubit.exchange', () {
    late _RecordingRepo repo;
    late ScheduleCubit cubit;

    setUp(() async {
      repo = _RecordingRepo();
      cubit = ScheduleCubit(
          repo, _FakeGetUsersByBranch(), FakeShiftTemplateRepository());
      await cubit.load(branchId: 'b1');
      repo.calls.clear();
    });

    tearDown(() => cubit.close());

    test('trades the two slots in ONE atomic repository call', () async {
      await cubit.exchange(
        dayA: ScheduleDay.monday,
        shiftA: ScheduleShift.morning,
        uidA: 'ziad',
        dayB: ScheduleDay.tuesday,
        shiftB: ScheduleShift.night,
        uidB: 'richard',
      );

      // A single atomic exchange, not four separate assign/remove writes whose
      // partial failure could double-book either person.
      expect(repo.calls, [
        'exchange:ziad:monday:morning<->richard:tuesday:night',
      ]);
    });

    test('self-swap is a no-op', () async {
      await cubit.exchange(
        dayA: ScheduleDay.monday,
        shiftA: ScheduleShift.morning,
        uidA: 'ziad',
        dayB: ScheduleDay.tuesday,
        shiftB: ScheduleShift.night,
        uidB: 'ziad',
      );
      expect(repo.calls, isEmpty);
    });

    test('same-slot trade is a no-op', () async {
      await cubit.exchange(
        dayA: ScheduleDay.monday,
        shiftA: ScheduleShift.morning,
        uidA: 'ziad',
        dayB: ScheduleDay.monday,
        shiftB: ScheduleShift.morning,
        uidB: 'richard',
      );
      expect(repo.calls, isEmpty);
    });
  });

  group('grid drag-to-switch', () {
    testWidgets('dropping a chip on another person fires onSwapChip, not move',
        (tester) async {
      // Desktop tier — chip drag & drop is a desktop affordance.
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final members = [_user('u1', 'Ziad Elsewedy'), _user('u2', 'Richard')];
      final weekStart = ScheduleWeek.currentWeekStart();
      final schedule = WeeklyScheduleEntity(
        id: 'b1_week',
        branchId: 'b1',
        weekStart: weekStart,
        assignments: {
          ScheduleDay.monday: {
            ScheduleShift.morning: ['u1'],
          },
          ScheduleDay.tuesday: {
            ScheduleShift.night: ['u2'],
          },
        },
      );

      final swaps = <String>[];
      final moves = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ScheduleGrid(
            schedule: schedule,
            members: members,
            canEdit: true,
            onCellTap: (_, _) {},
            onMoveChip: (data, toDay, toShift) =>
                moves.add('${data.uid}->${toDay.name}/${toShift.name}'),
            onSwapChip: (data, toDay, toShift, withUid) => swaps.add(
                '${data.uid}@${data.day.name}/${data.shift.name}'
                '⇄$withUid@${toDay.name}/${toShift.name}'),
          ),
        ),
      ));

      final from = tester.getCenter(find.text('Ziad E.'));
      final to = tester.getCenter(find.text('Richard'));

      final gesture = await tester.startGesture(from);
      // Step towards the target so the pan recognizer claims the drag.
      await gesture.moveTo(from + const Offset(20, 0));
      await tester.pump();
      await gesture.moveTo(to);
      await tester.pump();
      await gesture.up();
      await tester.pump();

      // The chip target (inner) wins over the cell target (outer): a drop ON
      // a person is a switch, never a move-into-cell.
      expect(swaps, ['u1@monday/morning⇄u2@tuesday/night']);
      expect(moves, isEmpty);
    });
  });
}
