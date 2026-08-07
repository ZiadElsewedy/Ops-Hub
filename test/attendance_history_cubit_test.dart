import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/attendance_status.dart';
import 'package:drop/core/enums/attendance_status_filter.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/features/attendance/domain/attendance_analytics.dart';
import 'package:drop/features/attendance/domain/attendance_feed.dart';
import 'package:drop/features/attendance/domain/attendance_history_query.dart';
import 'package:drop/features/attendance/domain/entities/attendance_entity.dart';
import 'package:drop/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:drop/features/attendance/presentation/history/attendance_history_cubit.dart';
import 'package:drop/features/attendance/presentation/history/attendance_history_state.dart';

/// Minimal fake — only the reads the History cubit uses are implemented; the rest
/// forward to `noSuchMethod` (never called by these tests).
class _FakeRepo implements AttendanceRepository {
  final _history = StreamController<AttendanceFeed>.broadcast();

  void pushHistory(List<AttendanceEntity> records) =>
      _history.add(AttendanceFeed(records: records));

  @override
  Stream<AttendanceFeed> watchUserHistory(String uid, {int limit = 30}) =>
      _history.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AttendanceEntity _rec({
  required DateTime date,
  AttendanceStatus status = AttendanceStatus.completed,
  int late = 0,
}) =>
    AttendanceEntity(
      id: '${date.toIso8601String()}_${status.name}',
      userId: 'u1',
      userName: 'Alice',
      shift: ScheduleShift.morning,
      date: date,
      status: status,
      lateMinutes: late,
    );

/// Read the loaded state's fields (the freezed case is private, so go through
/// `maybeWhen`, whose callback exposes them positionally).
({List<AttendanceEntity> records, AttendanceStats stats, AttendanceHistoryQuery query})?
    _loaded(AttendanceHistoryState s) =>
        s.maybeWhen(
          loaded: (records, stats, query, branchId, offline, syncing) =>
              (records: records, stats: stats, query: query),
          orElse: () => null,
        );

void main() {
  // Fixed "now": 17 July 2026, so the default `thisMonth` window is all of July.
  final now = DateTime(2026, 7, 17);

  AttendanceHistoryCubit build(_FakeRepo repo) => AttendanceHistoryCubit(
        repository: repo,
        mode: AttendanceHistoryMode.self,
        userId: 'u1',
        now: () => now,
      );

  test('emits loaded records + window summary from the history stream', () async {
    final repo = _FakeRepo();
    final cubit = build(repo)..load();

    repo.pushHistory([
      _rec(date: DateTime(2026, 7, 5)), // on time
      _rec(date: DateTime(2026, 7, 6), late: 10), // late
      _rec(date: DateTime(2026, 7, 7), status: AttendanceStatus.absent),
      _rec(date: DateTime(2026, 6, 20)), // last month → outside the window
    ]);
    await pumpEventQueue();

    final l = _loaded(cubit.state)!;
    // June record is excluded; the three July records remain (newest first).
    expect(l.records.length, 3);
    expect(l.records.first.date.day, 7);
    expect(l.stats.presentCount, 2);
    expect(l.stats.absentCount, 1);
    expect(l.stats.lateCount, 1);

    await cubit.close();
  });

  test('a status filter narrows the list but not the summary window', () async {
    final repo = _FakeRepo();
    final cubit = build(repo)..load();

    repo.pushHistory([
      _rec(date: DateTime(2026, 7, 5)),
      _rec(date: DateTime(2026, 7, 6), late: 10),
      _rec(date: DateTime(2026, 7, 7), status: AttendanceStatus.absent),
    ]);
    await pumpEventQueue();

    cubit.toggleStatus(AttendanceStatusFilter.late);
    final l = _loaded(cubit.state)!;

    // The list shows only the late record …
    expect(l.records.length, 1);
    expect(l.records.single.isLate, isTrue);
    // … while the summary still describes the whole month.
    expect(l.stats.presentCount, 2);
    expect(l.stats.absentCount, 1);
    expect(l.query.activeStatuses, {AttendanceStatusFilter.late});

    await cubit.close();
  });

  test('toggleStatus builds an OR set; the All facet clears it', () async {
    final repo = _FakeRepo();
    final cubit = build(repo)..load();

    repo.pushHistory([
      _rec(date: DateTime(2026, 7, 5)),
      _rec(date: DateTime(2026, 7, 6), late: 10),
      _rec(date: DateTime(2026, 7, 7), status: AttendanceStatus.absent),
    ]);
    await pumpEventQueue();

    // Late OR Absent → two rows.
    cubit.toggleStatus(AttendanceStatusFilter.late);
    cubit.toggleStatus(AttendanceStatusFilter.absent);
    expect(
      cubit.query.activeStatuses,
      {AttendanceStatusFilter.late, AttendanceStatusFilter.absent},
    );
    expect(_loaded(cubit.state)!.records.length, 2);

    // Toggling Late off leaves only Absent.
    cubit.toggleStatus(AttendanceStatusFilter.late);
    expect(_loaded(cubit.state)!.records.single.status,
        AttendanceStatus.absent);

    // The All chip clears every status facet.
    cubit.toggleStatus(AttendanceStatusFilter.all);
    expect(cubit.query.activeStatuses, isEmpty);
    expect(_loaded(cubit.state)!.records.length, 3);

    await cubit.close();
  });
}
