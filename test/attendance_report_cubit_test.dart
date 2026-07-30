import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_ledger_row.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_period.dart';
import 'package:drop/features/attendance/domain/repositories/attendance_reporting_repository.dart';
import 'package:drop/features/attendance/presentation/history/widgets/attendance_history_summary.dart';
import 'package:drop/features/attendance/presentation/reporting/attendance_report_cubit.dart';
import 'package:drop/features/attendance/presentation/reporting/attendance_report_state.dart';

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
      '100% · 1 / 1 expected work shifts',
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

  testWidgets('summary renders awaiting close instead of 0 percent', (
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

    expect(find.text('No ledger data'), findsOneWidget);
    expect(find.text('0%'), findsNothing);
    expect(find.text('Show-up rate'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await cubit.close();
    await repo.close();
  });
}
