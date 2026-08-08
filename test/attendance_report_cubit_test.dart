import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_ledger_row.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_period.dart';
import 'package:drop/features/attendance/domain/repositories/attendance_reporting_repository.dart';
import 'package:drop/features/attendance/presentation/history/widgets/attendance_history_summary.dart';
import 'package:drop/features/attendance/presentation/reporting/attendance_report_cubit.dart';
import 'package:drop/features/attendance/presentation/reporting/attendance_report_state.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/domain/repositories/auth_repository.dart';
import 'package:drop/features/auth/domain/usecases/get_users_by_branch.dart';

class _FakeReportingRepository implements AttendanceReportingRepository {
  final branch = StreamController<List<AttendanceLedgerRow>>.broadcast();
  final user = StreamController<List<AttendanceLedgerRow>>.broadcast();
  final calls = <String>[];

  void pushUser(List<AttendanceLedgerRow> rows) => user.add(rows);
  void pushBranch(List<AttendanceLedgerRow> rows) => branch.add(rows);

  @override
  Stream<List<AttendanceLedgerRow>> watchBranchLedgerRange({
    required String branchId,
    required String startDayKey,
    required String endDayKey,
  }) {
    calls.add('branch:$branchId:$startDayKey:$endDayKey');
    return branch.stream;
  }

  @override
  Stream<List<AttendanceLedgerRow>> watchUserLedgerRange({
    required String userId,
    required String startDayKey,
    required String endDayKey,
  }) {
    calls.add('user:$userId:$startDayKey:$endDayKey');
    return user.stream;
  }

  Future<void> close() async {
    await branch.close();
    await user.close();
  }
}

class _AuthRepo implements AuthRepository {
  _AuthRepo(this.users);
  final List<UserEntity> users;
  @override
  Future<List<UserEntity>> getUsersByBranch(String branchId) async => users;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

UserEntity _user(String uid, UserRole role) => UserEntity(
      uid: uid,
      email: '$uid@x.com',
      authProvider: 'password',
      displayName: uid,
      role: role,
      branchId: 'b1',
    );

AttendanceLedgerRow _rowFor(String uid) => AttendanceLedgerRow(
      id: '${uid}_20260715_morning',
      rowId: '${uid}_20260715_morning',
      userId: uid,
      branchId: 'b1',
      dayKey: '20260715',
      businessDate: '2026-07-15',
      shift: ScheduleShift.morning,
      outcome: AttendanceLedgerOutcome.worked,
      expected: true,
      workedMinutes: 480,
      closedAt: DateTime(2026, 7, 16),
    );

AttendanceLedgerRow _row() => AttendanceLedgerRow(
  id: 'u1_20260715_morning',
  rowId: 'u1_20260715_morning',
  userId: 'u1',
  branchId: 'b1',
  dayKey: '20260715',
  businessDate: '2026-07-15',
  shift: ScheduleShift.morning,
  outcome: AttendanceLedgerOutcome.worked,
  expected: true,
  workedMinutes: 480,
  closedAt: DateTime(2026, 7, 16),
);

void main() {
  final window = AttendancePeriodWindow(
    startDate: DateTime(2026, 7, 1),
    endDate: DateTime(2026, 7, 31),
  );

  test(
    'empty ledger is loaded as awaiting close, not as real zero metrics',
    () async {
      final repo = _FakeReportingRepository();
      final cubit = AttendanceReportCubit(repository: repo);

      cubit.watchUserWindow(userId: 'u1', window: window);
      repo.pushUser(const []);
      await pumpEventQueue();

      expect(repo.calls.single, 'user:u1:20260701:20260731');
      expect(cubit.state.status, AttendanceReportStatus.loaded);
      expect(cubit.state.coverage.awaitingClose, isTrue);
      expect(cubit.state.summary.showUpRate.percent, isNull);

      await cubit.close();
      await repo.close();
    },
  );

  test('branch window reads branch/dayKey range and aggregates rows', () async {
    final repo = _FakeReportingRepository();
    final cubit = AttendanceReportCubit(repository: repo);

    cubit.watchBranchWindow(branchId: 'b1', window: window);
    repo.pushBranch([_row()]);
    await pumpEventQueue();

    expect(repo.calls.single, 'branch:b1:20260701:20260731');
    expect(cubit.state.coverage.awaitingClose, isFalse);
    expect(cubit.state.coverage.closedRowCount, 1);
    expect(cubit.state.summary.present, 1);
    expect(
      cubit.state.summary.showUpRate.describe(),
      '100% · 1 / 1 scheduled shifts',
    );

    await cubit.close();
    await repo.close();
  });

  test('missing branch scope does not attempt a Firestore query', () async {
    final repo = _FakeReportingRepository();
    final cubit = AttendanceReportCubit(repository: repo);

    cubit.watchBranchWindow(branchId: null, window: window);

    expect(repo.calls, isEmpty);
    expect(cubit.state.status, AttendanceReportStatus.loaded);
    expect(cubit.state.coverage.awaitingClose, isTrue);

    await cubit.close();
    await repo.close();
  });

  test('a manager branch report hides peer managers, keeps employees + self',
      () async {
    final repo = _FakeReportingRepository();
    final cubit = AttendanceReportCubit(
      repository: repo,
      getUsersByBranch: GetUsersByBranch(
        _AuthRepo([
          _user('m1', UserRole.manager), // the viewer
          _user('m2', UserRole.manager), // a peer manager — hidden
          _user('e1', UserRole.employee),
        ]),
      ),
    );

    cubit.watchBranchWindow(
      branchId: 'b1',
      window: window,
      viewerUid: 'm1',
      employeesOnly: true,
    );
    repo.pushBranch([_rowFor('e1'), _rowFor('m2'), _rowFor('m1')]);
    await pumpEventQueue();

    final uids = cubit.state.rows.map((r) => r.userId).toSet();
    expect(uids, {'m1', 'e1'});
    // The summary is recomputed from the filtered rows (peer manager excluded).
    expect(cubit.state.summary.present, 2);

    await cubit.close();
    await repo.close();
  });

  test('an admin branch report (employeesOnly off) keeps every row', () async {
    final repo = _FakeReportingRepository();
    final cubit = AttendanceReportCubit(
      repository: repo,
      getUsersByBranch: GetUsersByBranch(
        _AuthRepo([
          _user('m2', UserRole.manager),
          _user('e1', UserRole.employee),
        ]),
      ),
    );

    cubit.watchBranchWindow(branchId: 'b1', window: window);
    repo.pushBranch([_rowFor('e1'), _rowFor('m2')]);
    await pumpEventQueue();

    expect(cubit.state.rows.map((r) => r.userId).toSet(), {'m2', 'e1'});

    await cubit.close();
    await repo.close();
  });

  testWidgets('summary renders missing data instead of 0 percent', (
    tester,
  ) async {
    final repo = _FakeReportingRepository();
    final cubit = AttendanceReportCubit(repository: repo);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: Scaffold(
            body: AttendanceHistorySummary(
              isReview: false,
              userId: 'u1',
              branchId: null,
              window: window,
            ),
          ),
        ),
      ),
    );
    repo.pushUser(const []);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('No data yet'), findsOneWidget);
    expect(find.text('0%'), findsNothing);
    expect(find.text('Show-up rate'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await cubit.close();
    await repo.close();
  });
}
