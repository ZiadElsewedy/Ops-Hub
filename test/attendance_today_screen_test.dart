import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/core/theme/app_theme.dart';
import 'package:opshub/features/attendance/domain/attendance_board.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_entity.dart';
import 'package:opshub/features/attendance/presentation/cubit/attendance_admin_cubit.dart';
import 'package:opshub/features/attendance/presentation/cubit/attendance_admin_state.dart';
import 'package:opshub/features/attendance/presentation/pages/admin_attendance_screen.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_state.dart';
import 'package:opshub/features/branch/domain/branch_geofence.dart';
import 'package:opshub/features/branch/domain/entities/branch_entity.dart';
import 'package:opshub/features/branch/domain/repositories/branch_repository.dart';
import 'package:opshub/features/branch/presentation/cubit/branch_cubit.dart';

/// The **Today** board — the manager/admin landing surface for attendance.
///
/// Covers the contract the redesign was asked for: who is present, late and
/// absent at a glance; an unscheduled punch that a manager can affirm in place;
/// and a per-person history door. Also pins the bootstrap case that has already
/// cost this module one spinner-forever hang: `BranchCubit` is an app-level
/// singleton, so it is normally **already loaded** when this screen mounts.
void main() {
  final today = DateTime(2026, 8, 1);
  final morningStart = DateTime(2026, 8, 1, 8, 30);
  final morningEnd = DateTime(2026, 8, 1, 16, 30);

  const branches = [
    BranchEntity(id: 'arkan', name: 'Drop the shop | Arkan'),
    BranchEntity(id: 'lmd', name: 'Drop The Shop | LMD'),
  ];

  const manager = UserEntity(
    uid: 'mgr-1',
    email: 'mgr@drop.test',
    displayName: 'Manager',
    authProvider: 'password',
    role: UserRole.manager,
    branchId: 'arkan',
  );

  const admin = UserEntity(
    uid: 'admin-1',
    email: 'admin@drop.test',
    displayName: 'Zoz',
    authProvider: 'password',
    role: UserRole.admin,
  );

  AttendanceRosterEntry roster(String name, {bool scheduled = true}) =>
      AttendanceRosterEntry(
        uid: name.toLowerCase(),
        name: name,
        shift: ScheduleShift.morning,
        scheduledStart: scheduled ? morningStart : null,
        scheduledEnd: scheduled ? morningEnd : null,
      );

  AttendanceEntity record(String uid, {DateTime? clockIn}) => AttendanceEntity(
    id: '${uid}_20260801_morning',
    userId: uid,
    shift: ScheduleShift.morning,
    date: today,
    clockIn: clockIn ?? morningStart,
  );

  AttendanceBoardRow row(
    String name,
    AttendanceBoardStatus status, {
    bool scheduled = true,
    bool withRecord = true,
    bool isLate = false,
  }) => AttendanceBoardRow(
    entry: roster(name, scheduled: scheduled),
    record: withRecord ? record(name.toLowerCase()) : null,
    status: status,
    isLate: isLate,
  );

  /// Two working, one late, one absent, one unscheduled punch.
  final board = AttendanceBoard([
    row('Salama', AttendanceBoardStatus.working),
    row('Richard', AttendanceBoardStatus.working),
    row('Moataz', AttendanceBoardStatus.late, isLate: true),
    row('Dina', AttendanceBoardStatus.absent, withRecord: false),
    row('Ahmed', AttendanceBoardStatus.unscheduled, scheduled: false),
  ]);

  late _FakeAdminCubit cubit;
  late _FakeAuthCubit auth;
  late BranchCubit branchCubit;

  setUp(() {
    cubit = _FakeAdminCubit();
    auth = _FakeAuthCubit(const AuthState.unauthenticated());
    branchCubit = BranchCubit(_FakeBranchRepository(branches));
  });

  tearDown(() async {
    await cubit.close();
    await auth.close();
    await branchCubit.close();
  });

  Future<void> pumpToday(
    WidgetTester tester, {
    required UserEntity user,
    Size size = const Size(1280, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    auth.emit(AuthState.authenticated(user));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<AuthCubit>.value(value: auth),
            BlocProvider<BranchCubit>.value(value: branchCubit),
            BlocProvider<AttendanceAdminCubit>.value(value: cubit),
          ],
          child: const AdminAttendanceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void emitLoaded({String branchId = 'arkan'}) => cubit.emit(
    AttendanceAdminState.loaded(
      branchId: branchId,
      branches: branches,
      board: board,
      now: DateTime(2026, 8, 1, 10),
    ),
  );

  group('the board a manager lands on', () {
    testWidgets('names the day and its four states', (tester) async {
      emitLoaded();
      await pumpToday(tester, user: manager);

      expect(find.text('Today'), findsWidgets);
      // The four things the owner asked to see at a glance.
      expect(find.text('Present'), findsOneWidget);
      expect(find.text('Late'), findsWidgets);
      expect(find.text('Absent'), findsWidgets);
      expect(find.text('Needs review'), findsOneWidget);
    });

    testWidgets('lists every rostered person by name', (tester) async {
      emitLoaded();
      await pumpToday(tester, user: manager);

      for (final name in ['Salama', 'Richard', 'Moataz', 'Dina', 'Ahmed']) {
        expect(find.text(name), findsWidgets, reason: '$name is missing');
      }
    });

    testWidgets('loads the manager\'s own branch without asking', (
      tester,
    ) async {
      emitLoaded();
      await pumpToday(tester, user: manager);

      expect(cubit.loadedBranches, ['arkan']);
    });
  });

  group('bootstrap', () {
    testWidgets('renders when BranchCubit was already loaded', (tester) async {
      // The regression shape: a singleton whose loadIfNeeded() emits nothing, so
      // a screen that waits for a state change waits forever.
      await branchCubit.load();

      await pumpToday(tester, user: admin);

      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'an already-loaded singleton must not strand the screen',
      );
      // The admin's branch choices resolved rather than hanging.
      expect(find.textContaining('Arkan'), findsWidgets);
    });

    testWidgets('an admin with no branch is asked to choose one', (
      tester,
    ) async {
      // No loaded state emitted: the admin has not picked a branch yet.
      await pumpToday(tester, user: admin);

      expect(cubit.loadedBranches, isEmpty);
      expect(find.textContaining('branch'), findsWidgets);
    });
  });

  group('the unscheduled punch', () {
    testWidgets('offers Mark present in plain language', (tester) async {
      emitLoaded();
      await pumpToday(tester, user: manager);

      await tester.tap(find.text('Ahmed').first);
      await tester.pumpAndSettle();

      expect(find.text('Mark present'), findsWidgets);
      // The affirmative action must not be the only way out.
      expect(find.textContaining('unapproved'), findsWidgets);
    });

    testWidgets('a scheduled worker is not offered Mark present', (
      tester,
    ) async {
      emitLoaded();
      await pumpToday(tester, user: manager);

      await tester.tap(find.text('Salama').first);
      await tester.pumpAndSettle();

      expect(find.text('Mark present'), findsNothing);
    });
  });

  testWidgets('a row opens that person\'s history', (tester) async {
    emitLoaded();
    await pumpToday(tester, user: manager);

    await tester.tap(find.text('Moataz').first);
    await tester.pumpAndSettle();

    expect(
      find.text('History'),
      findsWidgets,
      reason: 'reaching one person\'s record is the second thing asked for',
    );
  });

  testWidgets('survives a narrow window without overflowing', (tester) async {
    emitLoaded();
    await pumpToday(tester, user: manager, size: const Size(360, 780));

    expect(tester.takeException(), isNull);
    expect(find.text('Salama'), findsWidgets);
  });
}

class _FakeAdminCubit extends Cubit<AttendanceAdminState>
    implements AttendanceAdminCubit {
  _FakeAdminCubit() : super(const AttendanceAdminState.loading());

  final loadedBranches = <String>[];

  @override
  Future<void> load(
    UserEntity admin, {
    String? branchId,
    DateTime? businessDate,
  }) async {
    if (branchId != null) loadedBranches.add(branchId);
  }

  @override
  Future<void> selectBranch(String branchId) async {
    loadedBranches.add(branchId);
  }

  @override
  void emit(AttendanceAdminState state) => super.emit(state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthCubit extends Cubit<AuthState> implements AuthCubit {
  _FakeAuthCubit(super.initial);

  @override
  void emit(AuthState state) => super.emit(state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBranchRepository implements BranchRepository {
  _FakeBranchRepository(this.branches);

  final List<BranchEntity> branches;

  @override
  Future<List<BranchEntity>> getBranches({
    bool includeDeleted = false,
    bool forceRefresh = false,
  }) async => branches;

  @override
  Future<BranchEntity?> getBranch(String branchId, {bool forceRefresh = false}) async {
    for (final branch in branches) {
      if (branch.id == branchId) return branch;
    }
    return null;
  }

  @override
  Future<BranchEntity> createBranch(BranchEntity branch) async => branch;

  @override
  Future<void> updateBranch(BranchEntity branch) async {}

  @override
  Future<void> setBranchActive(String branchId, bool isActive) async {}

  @override
  Future<void> setGeofence(String branchId, BranchGeofence geofence) async {}

  @override
  Future<void> deleteBranch(String branchId) async {}

  @override
  Future<String> uploadBranchImage(
    String branchId,
    File file, {
    required bool isLogo,
  }) async => '';
}
