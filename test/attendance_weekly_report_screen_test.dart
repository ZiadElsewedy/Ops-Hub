import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_ledger_row.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_period.dart';
import 'package:drop/features/attendance/domain/repositories/attendance_reporting_repository.dart';
import 'package:drop/features/attendance/presentation/reporting/attendance_report_cubit.dart';
import 'package:drop/features/attendance/presentation/reporting/attendance_weekly_report_screen.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:drop/features/auth/presentation/cubit/auth_state.dart';
import 'package:drop/features/branch/domain/branch_geofence.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/branch/domain/repositories/branch_repository.dart';
import 'package:drop/features/branch/presentation/cubit/branch_cubit.dart';

class _FakeAuthCubit extends Cubit<AuthState> implements AuthCubit {
  _FakeAuthCubit(UserEntity user) : super(AuthState.authenticated(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeReportingRepository implements AttendanceReportingRepository {
  final stream = StreamController<List<AttendanceLedgerRow>>.broadcast();
  String? watchedBranchId;
  String? watchedStart;
  String? watchedEnd;

  void push(List<AttendanceLedgerRow> rows) => stream.add(rows);

  @override
  Stream<List<AttendanceLedgerRow>> watchBranchLedgerRange({
    required String branchId,
    required String startDayKey,
    required String endDayKey,
  }) {
    watchedBranchId = branchId;
    watchedStart = startDayKey;
    watchedEnd = endDayKey;
    return stream.stream;
  }

  @override
  Stream<List<AttendanceLedgerRow>> watchUserLedgerRange({
    required String userId,
    required String startDayKey,
    required String endDayKey,
  }) => stream.stream;

  Future<void> close() => stream.close();
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

const _branchId = 'DDwedTHvI1sPHrMz06PI';
const _branch = BranchEntity(id: _branchId, name: 'Cairo A');

const _manager = UserEntity(
  uid: 'manager1',
  email: 'manager@drop.test',
  displayName: 'Manager',
  authProvider: 'password',
  role: UserRole.manager,
  branchId: _branchId,
);

final _window = weeklyWindow(DateTime(2026, 7, 30));
final _periodId = attendancePeriodId(
  type: AttendancePeriodType.weekly,
  scopeKey: _branchId,
  window: _window,
);

AttendanceLedgerRow _phantomAbsent(String id) => AttendanceLedgerRow(
  id: id,
  rowId: id,
  userId: 'u$id',
  userName: 'Employee $id',
  branchId: _branchId,
  dayKey: '20260729',
  businessDate: '2026-07-29',
  shift: ScheduleShift.morning,
  outcome: AttendanceLedgerOutcome.absent,
  expected: true,
  recordId: null,
  locked: false,
  version: 1,
  source: 'system',
  closedAt: DateTime(2026, 7, 29, 18),
);

Future<
  (_FakeReportingRepository, AttendanceReportCubit, BranchCubit, _FakeAuthCubit)
>
_pumpWeekly(WidgetTester tester, {required Size size, String? periodId}) async {
  await tester.binding.setSurfaceSize(size);
  // Reset inside test scope: `setSurfaceSize` asserts `inTest`, so calling it
  // from a bare `tearDown` (outside the test body) throws
  // "'inTest': is not true" instead of restoring the viewport.
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final repo = _FakeReportingRepository();
  final reportCubit = AttendanceReportCubit(repository: repo);
  final branchCubit = BranchCubit(_FakeBranchRepository(const [_branch]));
  final authCubit = _FakeAuthCubit(_manager);

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: authCubit),
        BlocProvider<BranchCubit>.value(value: branchCubit),
      ],
      child: MaterialApp(
        home: AttendanceWeeklyReportScreen(
          periodId: periodId ?? _periodId,
          cubit: reportCubit,
        ),
      ),
    ),
  );
  await tester.pump();
  return (repo, reportCubit, branchCubit, authCubit);
}

void _expectNoFlutterErrors(List<FlutterErrorDetails> errors) {
  expect(
    errors,
    isEmpty,
    reason: errors.map((error) => error.exceptionAsString()).join('\n'),
  );
}

void main() {
  final previousOnError = FlutterError.onError;
  late List<FlutterErrorDetails> errors;

  setUp(() {
    errors = [];
    FlutterError.onError = (details) {
      errors.add(details);
    };
  });

  tearDown(() {
    FlutterError.onError = previousOnError;
  });

  testWidgets('empty week renders awaiting-close and no rate percentage', (
    tester,
  ) async {
    final (repo, reportCubit, branchCubit, authCubit) = await _pumpWeekly(
      tester,
      size: const Size(1280, 900),
    );

    repo.push(const []);
    await tester.pump();

    expect(repo.watchedBranchId, _branchId);
    expect(repo.watchedStart, '20260726');
    expect(repo.watchedEnd, '20260801');
    expect(find.text('Awaiting close'), findsWidgets);
    expect(find.text('Show-up rate'), findsNothing);
    expect(find.text('0%'), findsNothing);
    expect(find.text('Sunday 26 Jul'), findsOneWidget);
    expect(find.text('Saturday 1 Aug'), findsOneWidget);
    expect(find.text('Not closed'), findsNWidgets(7));
    _expectNoFlutterErrors(errors);

    await tester.pumpWidget(const SizedBox());
    await reportCubit.close();
    await branchCubit.close();
    await authCubit.close();
    await repo.close();
  });

  testWidgets('production-shape partial week is honest on desktop and mobile', (
    tester,
  ) async {
    for (final size in [const Size(1280, 900), const Size(390, 844)]) {
      errors.clear();
      final (repo, reportCubit, branchCubit, authCubit) = await _pumpWeekly(
        tester,
        size: size,
      );

      repo.push([
        _phantomAbsent('1'),
        _phantomAbsent('2'),
        _phantomAbsent('3'),
      ]);
      await tester.pump();

      expect(find.text('Partially closed'), findsWidgets);
      expect(find.text('Show-up rate'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('0 / 3 expected work shifts'), findsOneWidget);
      expect(find.text('3 / 3 expected work shifts'), findsOneWidget);
      expect(find.text('Wednesday 29 Jul'), findsOneWidget);
      expect(find.text('Not closed'), findsNWidgets(6));
      expect(find.text('No record - phantom row'), findsNWidgets(3));
      _expectNoFlutterErrors(errors);

      await tester.pumpWidget(const SizedBox());
      await reportCubit.close();
      await branchCubit.close();
      await authCubit.close();
      await repo.close();
    }
  });

  testWidgets('invalid period id shows a clear message without crashing', (
    tester,
  ) async {
    final (repo, reportCubit, branchCubit, authCubit) = await _pumpWeekly(
      tester,
      size: const Size(390, 844),
      periodId: 'not-a-period',
    );

    expect(find.text('Invalid weekly report link'), findsOneWidget);
    expect(
      find.textContaining('Expected branch_weekly_YYYYMMDD'),
      findsOneWidget,
    );
    expect(repo.watchedBranchId, isNull);
    _expectNoFlutterErrors(errors);

    await tester.pumpWidget(const SizedBox());
    await reportCubit.close();
    await branchCubit.close();
    await authCubit.close();
    await repo.close();
  });
}
