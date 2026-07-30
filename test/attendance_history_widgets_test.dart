import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/attendance_status.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/features/attendance/domain/attendance_history_query.dart';
import 'package:drop/features/attendance/domain/entities/attendance_entity.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_ledger_row.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_period.dart';
import 'package:drop/features/attendance/domain/repositories/attendance_reporting_repository.dart';
import 'package:drop/features/attendance/presentation/history/widgets/attendance_history_filters.dart';
import 'package:drop/features/attendance/presentation/history/widgets/attendance_history_summary.dart';
import 'package:drop/features/attendance/presentation/history/widgets/attendance_record_card.dart';
import 'package:drop/features/attendance/presentation/reporting/attendance_report_cubit.dart';
import 'dart:async';

class _FakeReportingRepository implements AttendanceReportingRepository {
  final user = StreamController<List<AttendanceLedgerRow>>.broadcast();

  void push(List<AttendanceLedgerRow> rows) => user.add(rows);

  @override
  Stream<List<AttendanceLedgerRow>> watchBranchLedgerRange({
    required String branchId,
    required String startDayKey,
    required String endDayKey,
  }) => user.stream;

  @override
  Stream<List<AttendanceLedgerRow>> watchUserLedgerRange({
    required String userId,
    required String startDayKey,
    required String endDayKey,
  }) => user.stream;

  Future<void> close() => user.close();
}

AttendanceEntity _rec({
  required DateTime date,
  AttendanceStatus status = AttendanceStatus.completed,
  int worked = 480,
  int late = 0,
  int overtime = 0,
  DateTime? clockIn,
  DateTime? clockOut,
}) => AttendanceEntity(
  id: date.toIso8601String(),
  userId: 'u1',
  userName: 'Alice',
  shift: ScheduleShift.morning,
  date: date,
  status: status,
  clockIn: clockIn,
  clockOut: clockOut,
  workedMinutes: worked,
  lateMinutes: late,
  overtimeMinutes: overtime,
);

AttendanceLedgerRow _ledger({
  required String id,
  AttendanceLedgerOutcome outcome = AttendanceLedgerOutcome.worked,
  int worked = 480,
  int late = 0,
}) => AttendanceLedgerRow(
  id: id,
  rowId: id,
  userId: 'u1',
  userName: 'Alice',
  branchId: 'b1',
  dayKey: '20260715',
  businessDate: '2026-07-15',
  shift: ScheduleShift.morning,
  outcome: outcome,
  expected: true,
  workedMinutes: worked,
  lateMinutes: late,
  closedAt: DateTime(2026, 7, 16),
);

void main() {
  Widget host(Widget child, AttendanceReportCubit cubit) => MaterialApp(
    home: BlocProvider.value(
      value: cubit,
      child: Scaffold(body: child),
    ),
  );

  final window = AttendancePeriodWindow(
    startDate: DateTime(2026, 7, 1),
    endDate: DateTime(2026, 7, 31),
  );

  // Mirrors the History screen's `_Loaded` body (summary + filters + cards in a
  // plain ListView) — the render path that must not throw.
  testWidgets(
    'history body renders summary, filters and cards without throwing',
    (tester) async {
      final records = [
        _rec(
          date: DateTime(2026, 7, 15),
          clockIn: DateTime(2026, 7, 15, 8, 35),
          clockOut: DateTime(2026, 7, 15, 16, 40),
          late: 5,
        ),
        _rec(
          date: DateTime(2026, 7, 12),
          status: AttendanceStatus.absent,
          worked: 0,
        ),
        _rec(
          date: DateTime(2026, 7, 10),
          clockIn: DateTime(2026, 7, 10, 8, 30),
          clockOut: DateTime(2026, 7, 10, 17, 10),
          overtime: 40,
        ),
      ];
      final repo = _FakeReportingRepository();
      final cubit = AttendanceReportCubit(repository: repo);

      await tester.pumpWidget(
        host(
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AttendanceHistorySummary(
                isReview: false,
                userId: 'u1',
                branchId: null,
                window: window,
              ),
              const SizedBox(height: 16),
              AttendanceHistoryFilters(
                query: const AttendanceHistoryQuery(),
                onRange: (_, {start, end}) {},
                onStatus: (_) {},
                onToggleShift: (_) {},
              ),
              const SizedBox(height: 16),
              for (final r in records) AttendanceRecordCard(record: r),
            ],
          ),
          cubit,
        ),
      );
      repo.push([
        _ledger(id: 'u1_20260715_morning', late: 5),
        _ledger(
          id: 'u1_20260712_morning',
          outcome: AttendanceLedgerOutcome.absent,
        ),
      ]);
      await tester.pump(const Duration(seconds: 1)); // settle the count-up

      expect(tester.takeException(), isNull);
      expect(find.text('Present'), findsOneWidget); // summary label
      expect(find.text('On time'), findsWidgets); // a status filter chip
      expect(find.text('Alice'), findsNothing); // self cards lead with the date

      await tester.pumpWidget(const SizedBox()); // unmount cleanly
      await cubit.close();
      await repo.close();
    },
  );

  testWidgets('empty-facet list still renders (no records)', (tester) async {
    final repo = _FakeReportingRepository();
    final cubit = AttendanceReportCubit(repository: repo);

    await tester.pumpWidget(
      host(
        ListView(
          children: [
            AttendanceHistorySummary(
              isReview: false,
              userId: 'u1',
              branchId: null,
              window: window,
            ),
            AttendanceHistoryFilters(
              query: const AttendanceHistoryQuery(),
              onRange: (_, {start, end}) {},
              onStatus: (_) {},
              onToggleShift: (_) {},
            ),
          ],
        ),
        cubit,
      ),
    );
    repo.push(const []);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.text('Awaiting close'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await cubit.close();
    await repo.close();
  });

  testWidgets('review-mode card leads with the employee name', (tester) async {
    final r = _rec(
      date: DateTime(2026, 7, 15),
      clockIn: DateTime(2026, 7, 15, 8, 30),
      clockOut: DateTime(2026, 7, 15, 16, 30),
    );
    final repo = _FakeReportingRepository();
    final cubit = AttendanceReportCubit(repository: repo);
    await tester.pumpWidget(
      host(
        ListView(
          children: [AttendanceRecordCard(record: r, showEmployee: true)],
        ),
        cubit,
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Alice'), findsOneWidget);
    await cubit.close();
    await repo.close();
  });
}
