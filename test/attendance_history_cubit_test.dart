import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/attendance_status.dart';
import 'package:drop/core/enums/attendance_status_filter.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/features/attendance/domain/attendance_analytics.dart';
import 'package:drop/features/attendance/domain/attendance_directory_match.dart';
import 'package:drop/features/attendance/domain/attendance_feed.dart';
import 'package:drop/features/attendance/domain/attendance_history_preset.dart';
import 'package:drop/features/attendance/domain/attendance_history_query.dart';
import 'package:drop/features/attendance/domain/entities/attendance_entity.dart';
import 'package:drop/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:drop/features/attendance/presentation/history/attendance_history_cubit.dart';
import 'package:drop/features/attendance/presentation/history/attendance_history_state.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/domain/usecases/get_users_by_branch.dart';

/// Minimal fake — only the reads the History cubit uses are implemented; the rest
/// forward to `noSuchMethod` (never called by these tests).
class _FakeRepo implements AttendanceRepository {
  final _history = StreamController<AttendanceFeed>.broadcast();
  final _branch = StreamController<List<AttendanceEntity>>.broadcast();

  void pushHistory(List<AttendanceEntity> records) =>
      _history.add(AttendanceFeed(records: records));

  void pushBranch(List<AttendanceEntity> records) => _branch.add(records);

  @override
  Stream<AttendanceFeed> watchUserHistory(String uid, {int limit = 30}) =>
      _history.stream;

  @override
  Stream<List<AttendanceEntity>> watchBranchRange(
    String branchId,
    String startKey,
    String endKey,
  ) => _branch.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A directory loader that returns a fixed set of users (any AuthRepository is
/// bypassed — the cubit only calls `.call`).
class _FakeUsersByBranch implements GetUsersByBranch {
  _FakeUsersByBranch(this.users);
  final List<UserEntity> users;

  @override
  Future<List<UserEntity>> call(String branchId) async => users;
}

UserEntity _user(String uid, String name, {bool active = true}) => UserEntity(
  uid: uid,
  email: '$uid@example.com',
  authProvider: 'password',
  displayName: name,
  isActive: active,
);

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
          loaded: (records, stats, query, branchId, offline, syncing, directory) =>
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

  test('review mode loads the branch directory (active users only)', () async {
    final repo = _FakeRepo();
    final cubit = AttendanceHistoryCubit(
      repository: repo,
      mode: AttendanceHistoryMode.review,
      branchId: 'b1',
      getUsersByBranch: _FakeUsersByBranch([
        _user('u-moh', 'Mohamed'),
        _user('u-ghost', 'Ghost', active: false), // deactivated → excluded
      ]),
      now: () => now,
    )..load();

    repo.pushBranch(const []);
    await pumpEventQueue();

    final directory = cubit.state.maybeMap(
      loaded: (s) => s.directory,
      orElse: () => const <AttendanceDirectoryEntry>[],
    );
    expect(directory.map((e) => e.userId).toList(), ['u-moh']);
    expect(directory.single.name, 'Mohamed');

    await cubit.close();
  });

  test('applyPreset sets the quick view\'s range and status set', () async {
    final repo = _FakeRepo();
    final cubit = build(repo)..load();
    repo.pushHistory([]);
    await pumpEventQueue();

    cubit.applyPreset(
      kAttendanceHistoryPresets.firstWhere((p) => p.label == 'Late this week'),
    );
    expect(cubit.query.range, AttendanceDateRange.last7Days);
    expect(cubit.query.activeStatuses, {AttendanceStatusFilter.late});

    await cubit.close();
  });
}
