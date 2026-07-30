import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_ledger_row.dart';
import 'package:drop/features/attendance/domain/repositories/attendance_reporting_repository.dart';
import 'package:drop/features/attendance/presentation/reporting/attendance_report_cubit.dart';
import 'package:drop/features/attendance/presentation/reporting/attendance_reports_screen.dart';
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

  void push(List<AttendanceLedgerRow> rows) => stream.add(rows);

  @override
  Stream<List<AttendanceLedgerRow>> watchBranchLedgerRange({
    required String branchId,
    required String startDayKey,
    required String endDayKey,
  }) {
    watchedBranchId = branchId;
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

const _branch = BranchEntity(id: 'DDwedTHvI1sPHrMz06PI', name: 'Cairo A');

const _manager = UserEntity(
  uid: 'manager1',
  email: 'manager@drop.test',
  displayName: 'Manager',
  authProvider: 'password',
  role: UserRole.manager,
  branchId: 'DDwedTHvI1sPHrMz06PI',
);

AttendanceLedgerRow _phantomAbsent(String id) => AttendanceLedgerRow(
  id: id,
  rowId: id,
  userId: 'u$id',
  userName: 'Employee $id',
  branchId: 'DDwedTHvI1sPHrMz06PI',
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
_pumpReports(WidgetTester tester) async {
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
        home: AttendanceReportsScreen(
          cubit: reportCubit,
          now: DateTime(2026, 7, 30, 14),
        ),
      ),
    ),
  );
  await tester.pump();
  return (repo, reportCubit, branchCubit, authCubit);
}

void main() {
  testWidgets('empty ledger renders awaiting-close without rate values', (
    tester,
  ) async {
    final (repo, reportCubit, branchCubit, authCubit) = await _pumpReports(
      tester,
    );

    repo.push(const []);
    await tester.pump();

    expect(repo.watchedBranchId, 'DDwedTHvI1sPHrMz06PI');
    expect(find.text('Awaiting close'), findsOneWidget);
    expect(find.text('Show-up rate'), findsNothing);
    expect(find.text('0%'), findsNothing);
    expect(find.textContaining('0 /'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await reportCubit.close();
    await branchCubit.close();
    await authCubit.close();
    await repo.close();
  });

  testWidgets('populated phantom rows render 0 percent over denominator 3', (
    tester,
  ) async {
    final (repo, reportCubit, branchCubit, authCubit) = await _pumpReports(
      tester,
    );

    repo.push([_phantomAbsent('1'), _phantomAbsent('2'), _phantomAbsent('3')]);
    await tester.pump();

    expect(find.text('Show-up rate'), findsOneWidget);
    expect(find.text('0%'), findsWidgets);
    expect(find.text('0 / 3 expected work shifts'), findsWidgets);
    expect(find.text('3 / 3 expected work shifts'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await reportCubit.close();
    await branchCubit.close();
    await authCubit.close();
    await repo.close();
  });
}
