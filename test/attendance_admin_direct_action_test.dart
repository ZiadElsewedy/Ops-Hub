import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/attendance_correction_kind.dart';
import 'package:opshub/core/enums/attendance_status.dart';
import 'package:opshub/core/enums/request_status.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/features/attendance/domain/attendance_board.dart';
import 'package:opshub/features/attendance/domain/attendance_service.dart';
import 'package:opshub/features/attendance/domain/attendance_write_outcome.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_correction.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_entity.dart';
import 'package:opshub/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:opshub/features/attendance/domain/usecases/decide_correction.dart';
import 'package:opshub/features/attendance/presentation/cubit/attendance_admin_cubit.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/auth/domain/repositories/auth_repository.dart';
import 'package:opshub/features/auth/domain/usecases/get_users_by_branch.dart';
import 'package:opshub/features/branch/domain/entities/branch_entity.dart';
import 'package:opshub/features/branch/domain/repositories/branch_repository.dart';
import 'package:opshub/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:opshub/features/schedule/domain/repositories/schedule_repository.dart';

/// Captures the resolved-correction writes; streams for the two live queries.
class _CaptureRepo implements AttendanceRepository {
  final List<AttendanceCorrectionEntity> resolved = [];

  /// What `getRecord` returns during the apply-confirmation poll. Null models an
  /// undeployed backend: the correction is stored, the record never moves.
  AttendanceEntity? applied;

  @override
  Future<AttendanceEntity?> getRecord(String id) async => applied;
  final _day = StreamController<List<AttendanceEntity>>.broadcast();
  final _pending =
      StreamController<List<AttendanceCorrectionEntity>>.broadcast();

  @override
  Future<void> createResolvedCorrection(
          AttendanceCorrectionEntity correction) async =>
      resolved.add(correction);

  @override
  Stream<List<AttendanceEntity>> watchBranchDay(String b, String d) =>
      _day.stream;

  @override
  Stream<List<AttendanceCorrectionEntity>> watchBranchPendingCorrections(
          String b) =>
      _pending.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _NoScheduleRepo implements ScheduleRepository {
  @override
  Future<WeeklyScheduleEntity?> getSchedule(
          String branchId, DateTime weekStart) async =>
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
  @override
  Future<List<UserEntity>> getUsersByBranch(String branchId) async => const [];
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  final admin = UserEntity(
    uid: 'm1',
    email: 'm@x.com',
    authProvider: 'password',
    displayName: 'Manager',
    role: UserRole.admin,
    branchId: 'b1',
    isActive: true,
  );
  final now = DateTime(2026, 7, 13, 18);

  late _CaptureRepo repo;

  AttendanceAdminCubit build() {
    repo = _CaptureRepo();
    return AttendanceAdminCubit(
      repository: repo,
      scheduleRepository: _NoScheduleRepo(),
      branchRepository: _BranchRepo(),
      getUsersByBranch: GetUsersByBranch(_AuthRepo()),
      decideCorrection: DecideCorrection(repo),
      service: const AttendanceService(),
      now: () => now,
      applyConfirmInterval: Duration.zero,
    );
  }

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  final pendingReview = AttendanceEntity(
    id: 'e1_20260713_morning',
    userId: 'e1',
    userName: 'Employee',
    branchId: 'b1',
    shift: ScheduleShift.morning,
    date: DateTime(2026, 7, 13),
    scheduledStart: DateTime(2026, 7, 13, 8, 30),
    scheduledEnd: DateTime(2026, 7, 13, 16, 30),
    clockIn: DateTime(2026, 7, 13, 8, 30),
    status: AttendanceStatus.pendingReview,
  );

  test('resolveDirectly writes an approved correction with the computed snapshot',
      () async {
    final cubit = build();
    await cubit.load(admin, branchId: 'b1');
    await pump();

    await cubit.resolveDirectly(
      pendingReview,
      clockIn: DateTime(2026, 7, 13, 8, 30),
      clockOut: DateTime(2026, 7, 13, 16, 30),
      reason: 'Employee left at 16:30, forgot to clock out',
    );

    expect(repo.resolved, hasLength(1));
    final c = repo.resolved.single;
    expect(c.attendanceId, 'e1_20260713_morning');
    expect(c.userId, 'e1');
    expect(c.status, RequestStatus.approved);
    expect(c.decidedBy, 'm1'); // the manager, not the employee (no self-approval)
    expect(c.kind, AttendanceCorrectionKind.missingClockOut);
    expect(c.reason, 'Employee left at 16:30, forgot to clock out');
    expect(c.resolution, isNotNull);
    expect(c.resolution!.status, AttendanceStatus.completed);
    expect(c.resolution!.workedMinutes, 480); // 08:30 → 16:30
    await cubit.close();
  });

  test('resolveDirectly requires a reason (no write on empty reason)', () async {
    final cubit = build();
    await cubit.load(admin, branchId: 'b1');
    await pump();

    await cubit.resolveDirectly(
      pendingReview,
      clockIn: DateTime(2026, 7, 13, 8, 30),
      clockOut: DateTime(2026, 7, 13, 16, 30),
      reason: '   ',
    );
    expect(repo.resolved, isEmpty);
    await cubit.close();
  });

  test('resolveDirectly is blocked while a correction is already pending (R15)',
      () async {
    final cubit = build();
    await cubit.load(admin, branchId: 'b1');
    repo._pending.add([
      AttendanceCorrectionEntity(
        id: 'c1',
        attendanceId: 'e1_20260713_morning',
        userId: 'e1',
        requestedBy: 'e1',
        kind: AttendanceCorrectionKind.missingClockOut,
        reason: 'employee filed one',
        status: RequestStatus.pending,
      ),
    ]);
    await pump();

    await cubit.resolveDirectly(
      pendingReview,
      clockIn: DateTime(2026, 7, 13, 8, 30),
      clockOut: DateTime(2026, 7, 13, 16, 30),
      reason: 'racing the pending one',
    );
    expect(repo.resolved, isEmpty); // duplicateOpen → decide the pending instead
    await cubit.close();
  });

  test('addRecord materializes an absent shift as an approved correction',
      () async {
    final cubit = build();
    await cubit.load(admin, branchId: 'b1');
    await pump();

    const entry = AttendanceRosterEntry(
      uid: 'e2',
      name: 'Absentee',
      shift: ScheduleShift.morning,
    );
    final row = AttendanceBoardRow(
      entry: entry.copyWithWindow(
        DateTime(2026, 7, 13, 8, 30),
        DateTime(2026, 7, 13, 16, 30),
      ),
      record: null,
      status: AttendanceBoardStatus.absent,
      isLate: true,
    );

    await cubit.addRecord(
      row,
      clockIn: DateTime(2026, 7, 13, 8, 30),
      clockOut: DateTime(2026, 7, 13, 16, 30),
      reason: 'Worked the shift, terminal was down',
    );

    expect(repo.resolved, hasLength(1));
    final c = repo.resolved.single;
    expect(c.attendanceId, 'e2_20260713_morning'); // deterministic id
    expect(c.userId, 'e2');
    expect(c.status, RequestStatus.approved);
    expect(c.decidedBy, 'm1');
    expect(c.resolution!.workedMinutes, 480);
    await cubit.close();
  });

  group('the UI is only told what actually happened', () {
    // A manager write creates an approved correction; a Cloud Function applies
    // it onto the record (ATTENDANCE_SPEC T3/T4). Those are two facts, and
    // until the Functions deploy lands they differ. Reporting the first as
    // success told a manager the absence was excused while the person was still
    // marked absent — the most damaging thing an attendance screen can do,
    // because the manager stops checking.

    AttendanceBoardRow absentRow(String uid) => AttendanceBoardRow(
      entry: AttendanceRosterEntry(
        uid: uid,
        name: 'Absentee',
        shift: ScheduleShift.morning,
      ).copyWithWindow(
        DateTime(2026, 7, 13, 8, 30),
        DateTime(2026, 7, 13, 16, 30),
      ),
      record: null,
      status: AttendanceBoardStatus.absent,
      isLate: true,
    );

    test('applied only when the server has moved the record', () async {
      final cubit = build();
      await cubit.load(admin, branchId: 'b1');
      await pump();

      // The Function ran: the record carries a fresh `resolvedAt`.
      repo.applied = pendingReview.copyWith(
        status: AttendanceStatus.excused,
        resolvedAt: DateTime(2026, 7, 13, 18, 30),
      );

      final outcome = await cubit.excuseAbsence(
        absentRow('e5'),
        reason: 'Approved leave, filed late',
      );

      expect(outcome, AttendanceWriteOutcome.applied);
      expect(repo.resolved, hasLength(1));
      await cubit.close();
    });

    test('awaitingBackend when the record never moves', () async {
      final cubit = build();
      await cubit.load(admin, branchId: 'b1');
      await pump();

      repo.applied = null; // undeployed Function: nothing applies the correction

      final outcome = await cubit.excuseAbsence(
        absentRow('e6'),
        reason: 'Approved leave, filed late',
      );

      // Not a failure: the correction is durable and will apply on deploy. But
      // the manager must not be told the shift is settled.
      expect(outcome, AttendanceWriteOutcome.awaitingBackend);
      expect(outcome.isWritten, isTrue);
      expect(repo.resolved, hasLength(1));
      await cubit.close();
    });

    test('a record corrected before needs a NEW resolvedAt, not just any', () async {
      final cubit = build();
      await cubit.load(admin, branchId: 'b1');
      await pump();

      final alreadyCorrected = DateTime(2026, 7, 13, 9);
      final existing = pendingReview.copyWith(resolvedAt: alreadyCorrected);
      // The server does nothing, so the stale stamp is all that comes back.
      repo.applied = existing;

      final outcome = await cubit.resolveDirectly(
        existing,
        clockIn: DateTime(2026, 7, 13, 8, 30),
        clockOut: DateTime(2026, 7, 13, 16, 30),
        reason: 'Second correction on the same shift',
      );

      expect(outcome, AttendanceWriteOutcome.awaitingBackend);
      await cubit.close();
    });
  });

  test(
    'a date-scoped board writes to the day under review, not to today',
    () async {
      // Daily Review settles a *past* day. Every write used to resolve its
      // document id from `_today()` at action time, so reviewing 12 July on the
      // 13th would have written 13 July's record — a wrong-date write on data
      // that feeds pay. The date is now pinned when the board is scoped.
      final cubit = build();
      await cubit.load(admin, branchId: 'b1', businessDate: DateTime(2026, 7, 12));
      await pump();

      const entry = AttendanceRosterEntry(
        uid: 'e9',
        name: 'Yesterday',
        shift: ScheduleShift.morning,
      );
      final row = AttendanceBoardRow(
        entry: entry.copyWithWindow(
          DateTime(2026, 7, 12, 8, 30),
          DateTime(2026, 7, 12, 16, 30),
        ),
        record: null,
        status: AttendanceBoardStatus.absent,
        isLate: true,
      );

      await cubit.addRecord(
        row,
        clockIn: DateTime(2026, 7, 12, 8, 30),
        clockOut: DateTime(2026, 7, 12, 16, 30),
        reason: 'Worked it, forgot to clock in',
      );

      expect(repo.resolved, hasLength(1));
      // `now` in this harness is the 13th; the id must still name the 12th.
      expect(repo.resolved.single.attendanceId, 'e9_20260712_morning');
      await cubit.close();
    },
  );

  test('an unscoped board still writes to today', () async {
    final cubit = build();
    await cubit.load(admin, branchId: 'b1');
    await pump();

    const entry = AttendanceRosterEntry(
      uid: 'e8',
      name: 'Today',
      shift: ScheduleShift.morning,
    );
    final row = AttendanceBoardRow(
      entry: entry.copyWithWindow(
        DateTime(2026, 7, 13, 8, 30),
        DateTime(2026, 7, 13, 16, 30),
      ),
      record: null,
      status: AttendanceBoardStatus.absent,
      isLate: true,
    );

    await cubit.addRecord(
      row,
      clockIn: DateTime(2026, 7, 13, 8, 30),
      clockOut: DateTime(2026, 7, 13, 16, 30),
      reason: 'Live board behaviour is unchanged',
    );

    expect(repo.resolved.single.attendanceId, 'e8_20260713_morning');
    await cubit.close();
  });

  test('excuseAbsence materializes an excused record with zero worked minutes',
      () async {
    final cubit = build();
    await cubit.load(admin, branchId: 'b1');
    await pump();

    const entry = AttendanceRosterEntry(
      uid: 'e3',
      name: 'Excused One',
      shift: ScheduleShift.morning,
    );
    final row = AttendanceBoardRow(
      entry: entry,
      record: null,
      status: AttendanceBoardStatus.absent,
      isLate: true,
    );

    await cubit.excuseAbsence(row, reason: 'Approved sick day, called ahead');

    expect(repo.resolved, hasLength(1));
    final c = repo.resolved.single;
    expect(c.attendanceId, 'e3_20260713_morning');
    expect(c.status, RequestStatus.approved);
    expect(c.decidedBy, 'm1');
    expect(c.resolution!.status, AttendanceStatus.excused);
    expect(c.resolution!.workedMinutes, 0);
    expect(c.resolution!.clockIn, isNull);
    expect(c.resolution!.clockOut, isNull);
    expect(c.reason, 'Approved sick day, called ahead');
    await cubit.close();
  });

  test('excuseAbsence requires a reason', () async {
    final cubit = build();
    await cubit.load(admin, branchId: 'b1');
    await pump();
    const entry = AttendanceRosterEntry(
      uid: 'e3',
      name: 'Excused One',
      shift: ScheduleShift.morning,
    );
    await cubit.excuseAbsence(
      AttendanceBoardRow(
        entry: entry,
        record: null,
        status: AttendanceBoardStatus.absent,
        isLate: true,
      ),
      reason: '   ',
    );
    expect(repo.resolved, isEmpty);
    await cubit.close();
  });
}

/// Local helper: a roster entry has no copyWith, so rebuild it with a window.
extension on AttendanceRosterEntry {
  AttendanceRosterEntry copyWithWindow(DateTime start, DateTime end) =>
      AttendanceRosterEntry(
        uid: uid,
        name: name,
        shift: shift,
        scheduledStart: start,
        scheduledEnd: end,
        leave: leave,
      );
}
