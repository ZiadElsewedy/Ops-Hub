import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/domain/repositories/auth_repository.dart';
import 'package:drop/features/auth/domain/usecases/get_users_by_branch.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:drop/features/schedule/domain/repositories/schedule_repository.dart';
import 'package:drop/features/schedule/presentation/cubit/today_coverage_cubit.dart';
import 'package:drop/features/schedule/presentation/cubit/today_coverage_state.dart';

/// **Opening Schedule must not re-read the backend every time.**
///
/// The reported complaint: "every time I click on Schedule it makes a request
/// and the data loads several times". The admin Today board was the worst of
/// it — one roster query **per branch**, none of them cached, fired on every
/// entry, behind a skeleton that blanked the board each time.
///
/// [ScheduleCubit] already had a freshness window; this pins the same
/// behaviour on the board that did not, plus the two rules that keep it
/// honest: a real scope change still refetches, and so does anything the user
/// asked for.
class _CountingAuthRepository implements AuthRepository {
  int rosterReads = 0;

  @override
  Future<List<UserEntity>> getUsersByBranch(String branchId) async {
    rosterReads++;
    return [
      UserEntity(
        uid: 'u-$branchId',
        email: 'u@$branchId.test',
        authProvider: 'password',
        role: UserRole.employee,
        branchId: branchId,
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _CountingScheduleRepository implements ScheduleRepository {
  int scheduleReads = 0;

  @override
  Future<WeeklyScheduleEntity?> getScheduleCacheFirst(
    String branchId,
    DateTime weekStart,
  ) async {
    scheduleReads++;
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  const branchA = BranchEntity(id: 'a', name: 'Arkan');
  const branchB = BranchEntity(id: 'b', name: 'Zayed');

  late _CountingAuthRepository auth;
  late _CountingScheduleRepository schedules;
  late TodayCoverageCubit cubit;

  setUp(() {
    auth = _CountingAuthRepository();
    schedules = _CountingScheduleRepository();
    cubit = TodayCoverageCubit(schedules, GetUsersByBranch(auth));
  });

  tearDown(() => cubit.close());

  test('re-entering Schedule reads nothing and shows no skeleton', () async {
    await cubit.load([branchA, branchB]);
    expect(auth.rosterReads, 2);
    expect(schedules.scheduleReads, 2);

    final states = <TodayCoverageState>[];
    final sub = cubit.stream.listen(states.add);

    // Leaving and re-opening the screen, inside the freshness window.
    await cubit.load([branchA, branchB]);
    await cubit.load([branchA, branchB]);

    expect(auth.rosterReads, 2, reason: 'no roster query per visit');
    expect(schedules.scheduleReads, 2);
    await Future<void>.delayed(Duration.zero); // let the stream deliver
    await sub.cancel();
    expect(states, isEmpty, reason: 'no loading flash, no re-emit');
  });

  test('the same branches in a different order is the same scope', () async {
    await cubit.load([branchA, branchB]);
    await cubit.load([branchB, branchA]);
    expect(auth.rosterReads, 2);
  });

  test('a branch appearing refetches — it is not the same board', () async {
    await cubit.load([branchA]);
    expect(auth.rosterReads, 1);

    await cubit.load([branchA, branchB]);
    expect(auth.rosterReads, 3);
  });

  test('force refetches — Refresh, and returning to Today after editing', () async {
    await cubit.load([branchA]);
    expect(auth.rosterReads, 1);

    await cubit.load([branchA], force: true);
    expect(auth.rosterReads, 2);
  });

  test('a forced refresh keeps the board on screen while it re-derives', () async {
    await cubit.load([branchA]);

    final states = <TodayCoverageState>[];
    final sub = cubit.stream.listen(states.add);
    await cubit.load([branchA], force: true);
    await Future<void>.delayed(Duration.zero); // let the stream deliver
    await sub.cancel();

    // Refresh must never blank the list it is refreshing.
    expect(states.whereType<TodayCoverageLoading>(), isEmpty);
    expect(states.last, isA<TodayCoverageLoaded>());
  });

  test('a genuinely new scope does show the skeleton', () async {
    await cubit.load([branchA]);

    final states = <TodayCoverageState>[];
    final sub = cubit.stream.listen(states.add);
    await cubit.load([branchA, branchB]);
    await Future<void>.delayed(Duration.zero); // let the stream deliver
    await sub.cancel();

    expect(states.first, isA<TodayCoverageLoading>());
  });

  test('no branches reads nothing at all', () async {
    await cubit.load(const []);
    expect(auth.rosterReads, 0);
    expect(schedules.scheduleReads, 0);
    expect(cubit.state, isA<TodayCoverageLoaded>());
  });
}
