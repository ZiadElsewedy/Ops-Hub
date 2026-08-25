import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/auth/domain/usecases/get_users_by_branch.dart';
import 'package:opshub/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:opshub/features/schedule/domain/repositories/schedule_repository.dart';
import 'package:opshub/features/schedule/presentation/cubit/schedule_cubit.dart';
import 'package:opshub/features/schedule/presentation/cubit/schedule_state.dart';
import 'support/fake_shift_template_repository.dart';

/// Stabilization guard: a same-scope [ScheduleCubit.load] (screen revisit,
/// pull-to-refresh) must NOT emit `loading` — the schedule on screen stays
/// visible while the data refetches, so navigation never blanks the view.
/// A real scope change (different branch or week) still shows the loader.

class _StubRepo implements ScheduleRepository {
  @override
  Future<WeeklyScheduleEntity?> getSchedule(
          String branchId, DateTime weekStart) async =>
      WeeklyScheduleEntity(
        id: '${branchId}_w',
        branchId: branchId,
        weekStart: weekStart,
        assignments: const {
          ScheduleDay.monday: {
            ScheduleShift.morning: ['u1'],
          },
        },
      );

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
  late ScheduleCubit cubit;
  late List<ScheduleState> emitted;

  setUp(() {
    cubit = ScheduleCubit(
        _StubRepo(), _FakeGetUsersByBranch(), FakeShiftTemplateRepository());
    emitted = [];
    cubit.stream.listen(emitted.add);
  });

  tearDown(() => cubit.close());

  bool isLoading(ScheduleState s) =>
      s.maybeWhen(loading: () => true, orElse: () => false);

  // Stream listeners receive emits asynchronously — flush before asserting.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('first load shows the loading state', () async {
    await cubit.load(branchId: 'b1');
    await settle();
    expect(emitted.any(isLoading), isTrue);
    expect(
      emitted.last.maybeWhen(loaded: (b, _, _, _, _) => b, orElse: () => ''),
      'b1',
    );
  });

  test('same-scope reload is silent — no loading flash, data stays on screen',
      () async {
    await cubit.load(branchId: 'b1');
    await settle();
    emitted.clear();

    // Screen revisit / refresh: same branch, same week.
    await cubit.load(branchId: 'b1');
    await cubit.refresh();
    await settle();

    expect(emitted.where(isLoading), isEmpty,
        reason: 'a same-scope reload must never blank the visible schedule');
    // Unchanged data → identical loaded state → bloc dedupes (no emission,
    // no pointless rebuild). The view simply stays on screen.
    expect(
      cubit.state.maybeWhen(loaded: (b, _, _, _, _) => b, orElse: () => ''),
      'b1',
      reason: 'the loaded view is still current after the silent reload',
    );
  });

  test('branch change shows the loading state', () async {
    await cubit.load(branchId: 'b1');
    await settle();
    emitted.clear();

    await cubit.load(branchId: 'b2');
    await settle();

    expect(emitted.any(isLoading), isTrue,
        reason: 'a real scope change is a fresh view — the loader is honest');
  });

  test('week change shows the loading state', () async {
    await cubit.load(branchId: 'b1');
    await settle();
    emitted.clear();

    await cubit.nextWeek();
    await settle();

    expect(emitted.any(isLoading), isTrue);
  });
}
