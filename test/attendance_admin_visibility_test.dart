import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/attendance_correction_kind.dart';
import 'package:drop/core/enums/attendance_status.dart';
import 'package:drop/core/enums/request_status.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/features/attendance/domain/attendance_service.dart';
import 'package:drop/features/attendance/domain/entities/attendance_correction.dart';
import 'package:drop/features/attendance/domain/entities/attendance_entity.dart';
import 'package:drop/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:drop/features/attendance/domain/usecases/decide_correction.dart';
import 'package:drop/features/attendance/presentation/cubit/attendance_admin_cubit.dart';
import 'package:drop/features/attendance/presentation/cubit/attendance_admin_state.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/domain/repositories/auth_repository.dart';
import 'package:drop/features/auth/domain/usecases/get_users_by_branch.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/branch/domain/repositories/branch_repository.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:drop/features/schedule/domain/repositories/schedule_repository.dart';

/// The manager-viewer visibility rule on the branch attendance board: a manager
/// sees only their employees plus their OWN row — never a peer manager (or an
/// admin). An admin sees everyone. Presentation only; the server read rules stay
/// branch-scoped (a collection query can't be partially filtered by rules).
void main() {
  UserEntity user(String uid, UserRole role) => UserEntity(
        uid: uid,
        email: '$uid@x.com',
        authProvider: 'password',
        displayName: uid,
        role: role,
        branchId: 'b1',
      );

  // A branch of: the viewing manager (m1), a peer manager (m2), an employee (e1).
  final directory = [
    user('m1', UserRole.manager),
    user('m2', UserRole.manager),
    user('e1', UserRole.employee),
  ];

  final now = DateTime(2026, 7, 13, 18);

  // Each person clocked in but is not on the schedule (managers are presence
  // roles; the no-schedule repo makes everyone unscheduled), so each surfaces as
  // one board row keyed by uid — the shape we filter on.
  AttendanceEntity rec(String uid) => AttendanceEntity(
        id: '${uid}_20260713_morning',
        userId: uid,
        userName: uid,
        branchId: 'b1',
        shift: ScheduleShift.morning,
        date: DateTime(2026, 7, 13),
        clockIn: DateTime(2026, 7, 13, 8, 30),
        status: AttendanceStatus.inProgress,
      );

  AttendanceCorrectionEntity pendingFor(String uid) => AttendanceCorrectionEntity(
        id: 'c_$uid',
        attendanceId: '${uid}_20260713_morning',
        userId: uid,
        requestedBy: uid,
        kind: AttendanceCorrectionKind.missingClockOut,
        reason: 'filed',
        status: RequestStatus.pending,
      );

  late _CaptureRepo repo;

  AttendanceAdminCubit build() {
    repo = _CaptureRepo();
    return AttendanceAdminCubit(
      repository: repo,
      scheduleRepository: _NoScheduleRepo(),
      branchRepository: _BranchRepo(),
      getUsersByBranch: GetUsersByBranch(_AuthRepo(directory)),
      decideCorrection: DecideCorrection(repo),
      service: const AttendanceService(),
      now: () => now,
    );
  }

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  Set<String> boardUids(AttendanceAdminState state) => state
      .maybeMap(loaded: (s) => s.board.rows.map((r) => r.uid).toSet(), orElse: () => <String>{});

  Set<String> correctionUids(AttendanceAdminState state) => state.maybeMap(
      loaded: (s) => s.corrections.map((c) => c.userId).toSet(), orElse: () => <String>{});

  test('a MANAGER viewer sees employees + own row, never a peer manager', () async {
    final cubit = build();
    await cubit.load(user('m1', UserRole.manager), branchId: 'b1');
    await pump();

    repo.day.add([rec('m1'), rec('m2'), rec('e1')]);
    repo.pending.add([pendingFor('m1'), pendingFor('m2'), pendingFor('e1')]);
    await pump();

    // m2 (peer manager) is gone; m1 (self) and e1 (employee) remain.
    expect(boardUids(cubit.state), {'m1', 'e1'});
    expect(correctionUids(cubit.state), {'m1', 'e1'});

    await cubit.close();
  });

  test('an ADMIN viewer sees everyone, managers included', () async {
    final cubit = build();
    await cubit.load(user('admin1', UserRole.admin), branchId: 'b1');
    await pump();

    repo.day.add([rec('m1'), rec('m2'), rec('e1')]);
    repo.pending.add([pendingFor('m1'), pendingFor('m2'), pendingFor('e1')]);
    await pump();

    expect(boardUids(cubit.state), {'m1', 'm2', 'e1'});
    expect(correctionUids(cubit.state), {'m1', 'm2', 'e1'});

    await cubit.close();
  });
}

class _CaptureRepo implements AttendanceRepository {
  final day = StreamController<List<AttendanceEntity>>.broadcast();
  final pending = StreamController<List<AttendanceCorrectionEntity>>.broadcast();

  @override
  Stream<List<AttendanceEntity>> watchBranchDay(String b, String d) => day.stream;

  @override
  Stream<List<AttendanceCorrectionEntity>> watchBranchPendingCorrections(String b) =>
      pending.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _NoScheduleRepo implements ScheduleRepository {
  @override
  Future<WeeklyScheduleEntity?> getSchedule(String branchId, DateTime weekStart) async =>
      null;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _BranchRepo implements BranchRepository {
  @override
  Future<List<BranchEntity>> getBranches({
    bool includeDeleted = false,
    bool forceRefresh = false,
  }) async =>
      [const BranchEntity(id: 'b1', name: 'Branch 1')];
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
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
