import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/auth/domain/usecases/get_users_by_branch.dart';
import 'package:opshub/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:opshub/features/schedule/domain/repositories/schedule_repository.dart';
import 'package:opshub/features/schedule/presentation/cubit/schedule_cubit.dart';
import 'support/fake_shift_template_repository.dart';

/// Schedule 4.0 — undo. After a move / exchange / remove the cubit records
/// the exact inverse; [ScheduleCubit.undoLast] replays it once within the
/// window, and any newer mutation invalidates a stale undo.

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

void main() {
  late _RecordingRepo repo;
  late ScheduleCubit cubit;

  setUp(() async {
    repo = _RecordingRepo();
    cubit =
        ScheduleCubit(repo, _FakeGetUsersByBranch(), FakeShiftTemplateRepository());
    await cubit.load(branchId: 'b1');
    repo.calls.clear();
  });

  tearDown(() => cubit.close());

  test('undo of a move puts the person back in their original slot', () async {
    await cubit.move(
      fromDay: ScheduleDay.monday,
      fromShift: ScheduleShift.morning,
      toDay: ScheduleDay.tuesday,
      toShift: ScheduleShift.night,
      uid: 'ziad',
    );
    expect(cubit.canUndo, isTrue);
    repo.calls.clear();

    await cubit.undoLast();

    // The inverse move is one atomic call back to the original slot.
    expect(repo.calls, ['move:ziad:tuesday:night->monday:morning']);
    expect(cubit.canUndo, isFalse, reason: 'an undo is single-use');
  });

  test('undo of an exchange trades the two back', () async {
    await cubit.exchange(
      dayA: ScheduleDay.monday,
      shiftA: ScheduleShift.morning,
      uidA: 'ziad',
      dayB: ScheduleDay.tuesday,
      shiftB: ScheduleShift.night,
      uidB: 'richard',
    );
    expect(cubit.canUndo, isTrue);
    repo.calls.clear();

    await cubit.undoLast();

    // The inverse exchange is one atomic call trading the two back.
    expect(repo.calls,
        ['exchange:ziad:tuesday:night<->richard:monday:morning']);
  });

  test('undo of a remove re-assigns the person', () async {
    await cubit.remove(ScheduleDay.monday, ScheduleShift.morning, 'ziad');
    expect(cubit.canUndo, isTrue);
    repo.calls.clear();

    await cubit.undoLast();

    expect(repo.calls, ['assign:ziad:monday:morning']);
  });

  test('a newer mutation invalidates the pending undo', () async {
    await cubit.remove(ScheduleDay.monday, ScheduleShift.morning, 'ziad');
    expect(cubit.canUndo, isTrue);

    // A different edit lands before the user taps UNDO.
    await cubit.assign(ScheduleDay.friday, ScheduleShift.night, 'ahmed');

    expect(cubit.canUndo, isFalse,
        reason: 'the schedule the undo would restore no longer exists');
    repo.calls.clear();
    await cubit.undoLast();
    expect(repo.calls, isEmpty);
  });

  test('undoing twice is a quiet no-op', () async {
    await cubit.remove(ScheduleDay.monday, ScheduleShift.morning, 'ziad');
    await cubit.undoLast();
    repo.calls.clear();

    await cubit.undoLast();

    expect(repo.calls, isEmpty);
  });

  test('the undo itself does not record a new undo', () async {
    await cubit.move(
      fromDay: ScheduleDay.monday,
      fromShift: ScheduleShift.morning,
      toDay: ScheduleDay.tuesday,
      toShift: ScheduleShift.night,
      uid: 'ziad',
    );
    await cubit.undoLast();

    expect(cubit.canUndo, isFalse,
        reason: 'undo must not offer to undo the undo');
  });
}
