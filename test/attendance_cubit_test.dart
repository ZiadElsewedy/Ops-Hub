import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/attendance_correction_kind.dart';
import 'package:drop/core/enums/attendance_status.dart';
import 'package:drop/core/enums/request_status.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/features/attendance/domain/attendance_break.dart';
import 'package:drop/features/attendance/domain/attendance_calculator.dart';
import 'package:drop/features/attendance/domain/attendance_feed.dart';
import 'package:drop/features/attendance/domain/attendance_gps.dart';
import 'package:drop/features/attendance/domain/attendance_location.dart';
import 'package:drop/features/attendance/domain/attendance_location_service.dart';
import 'package:drop/features/attendance/domain/attendance_resolution.dart';
import 'package:drop/features/attendance/domain/attendance_service.dart';
import 'package:drop/features/attendance/domain/entities/attendance_correction.dart';
import 'package:drop/features/attendance/domain/entities/attendance_entity.dart';
import 'package:drop/features/attendance/domain/entities/attendance_event.dart';
import 'package:drop/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:drop/features/attendance/domain/usecases/clock_in.dart';
import 'package:drop/features/attendance/domain/usecases/clock_out.dart';
import 'package:drop/features/attendance/domain/usecases/request_correction.dart';
import 'package:drop/features/attendance/presentation/cubit/attendance_cubit.dart';
import 'package:drop/features/attendance/presentation/cubit/attendance_state.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/branch/domain/branch_geofence.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/branch/domain/repositories/branch_repository.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:drop/features/schedule/domain/repositories/schedule_repository.dart';
import 'package:drop/features/schedule/domain/schedule_week.dart';

/// In-memory attendance repository — pushes the history feed + captures writes.
class _FakeAttendanceRepository implements AttendanceRepository {
  final _history = StreamController<AttendanceFeed>.broadcast();

  final List<AttendanceEntity> clockedIn = [];
  final List<({String id, AttendanceStatus status, AttendanceTotals totals})>
      clockedOut = [];
  final List<AttendanceCorrectionEntity> corrections = [];

  void pushHistory(List<AttendanceEntity> h,
          {bool offline = false, bool pending = false}) =>
      _history.add(AttendanceFeed(
        records: h,
        isOffline: offline,
        hasPendingWrites: pending,
      ));

  @override
  Stream<AttendanceFeed> watchUserHistory(String uid, {int limit = 30}) =>
      _history.stream;

  @override
  Future<void> clockIn(AttendanceEntity record) async => clockedIn.add(record);

  @override
  Future<void> clockOut(String id,
      {required DateTime clockOut,
      required AttendanceStatus status,
      required AttendanceTotals totals,
      AttendanceVerification? verification}) async {
    clockedOut.add((id: id, status: status, totals: totals));
  }

  @override
  Future<String> uploadSelfie(
          {required String recordId,
          required File file,
          required String uploadedBy}) async =>
      'https://selfie';

  @override
  Future<void> requestCorrection(AttendanceCorrectionEntity correction) async =>
      corrections.add(correction);

  final List<AttendanceCorrectionEntity> resolved = [];
  final _userCorrections =
      StreamController<List<AttendanceCorrectionEntity>>.broadcast();

  void pushCorrections(List<AttendanceCorrectionEntity> c) =>
      _userCorrections.add(c);

  @override
  Future<void> createResolvedCorrection(
          AttendanceCorrectionEntity correction) async =>
      resolved.add(correction);

  // Unused by these tests.
  @override
  Future<AttendanceEntity?> getRecord(String id) async => null;
  @override
  Stream<AttendanceEntity?> watchRecord(String id) => const Stream.empty();
  @override
  Stream<List<AttendanceEntity>> watchBranchDay(String b, String d) =>
      const Stream.empty();
  @override
  Stream<List<AttendanceEntity>> watchBranchRange(String b, String s, String e) =>
      const Stream.empty();
  @override
  Stream<List<AttendanceEvent>> watchEvents(String id) => const Stream.empty();
  @override
  Future<void> softDelete(String id) async {}
  @override
  Future<AttendanceCorrectionEntity?> getCorrection(String id) async => null;
  @override
  Future<void> decideCorrection(String id,
      {required RequestStatus status,
      required String decidedBy,
      String? decidedByName,
      String? decisionNote,
      AttendanceResolution? resolution}) async {}
  @override
  Stream<List<AttendanceCorrectionEntity>> watchUserCorrections(String uid,
          {int limit = 30}) =>
      _userCorrections.stream;
  @override
  Stream<List<AttendanceCorrectionEntity>> watchBranchPendingCorrections(
          String branchId) =>
      const Stream.empty();
  @override
  Stream<List<AttendanceCorrectionEntity>> watchRecordCorrections(
          String attendanceId) =>
      const Stream.empty();
}

/// Minimal schedule repository fake — only [getSchedule] matters here.
class _FakeScheduleRepository implements ScheduleRepository {
  WeeklyScheduleEntity? schedule;
  _FakeScheduleRepository(this.schedule);

  @override
  Future<WeeklyScheduleEntity?> getSchedule(String branchId, DateTime weekStart) async =>
      schedule;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// Branch repository fake — returns branch `b1` with (optionally) a geofence
/// and the manager clock-in policy under test.
class _FakeBranchRepository implements BranchRepository {
  final BranchGeofence? geofence;
  final bool managersCanClock;
  _FakeBranchRepository(this.geofence, {this.managersCanClock = true});

  @override
  Future<List<BranchEntity>> getBranches({
    bool includeDeleted = false,
    bool forceRefresh = false,
  }) async =>
      [
        BranchEntity(
          id: 'b1',
          name: 'Branch 1',
          geofence: geofence,
          managersCanClock: managersCanClock,
        )
      ];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// Location service fake — returns a scripted [LocationResult].
class _FakeLocationService implements AttendanceLocationService {
  LocationResult result;
  _FakeLocationService(this.result);

  @override
  Future<LocationResult> currentLocation() async => result;
}

/// The branch geofence used by the clock tests (30.0, 31.0 · 150 m · 50 m).
const _geofence = BranchGeofence(
  latitude: 30.0,
  longitude: 31.0,
  radiusMeters: 150,
  minAccuracyMeters: 50,
);

/// A GPS reading [approxMeters] north of the branch with [accuracy] m accuracy
/// (0.001° latitude ≈ 111 m).
LocationResult _fixNear(double approxMeters, {double accuracy = 8}) =>
    LocationResult.success(AttendanceLocation(
      latitude: 30.0 + (approxMeters / 111000.0),
      longitude: 31.0,
      accuracyMeters: accuracy,
      capturedAt: DateTime(2026, 7, 13, 9),
    ));

void main() {
  final user = UserEntity(
    uid: 'u1',
    email: 'u@x.com',
    authProvider: 'password',
    displayName: 'Ziad',
    role: UserRole.employee,
    branchId: 'b1',
    isActive: true,
  );

  // The same person as a manager — presence-only attendance (an open shift).
  // Shares uid `u1` so the roster fixtures apply when a manager happens to be
  // rostered.
  final manager = UserEntity(
    uid: 'u1',
    email: 'u@x.com',
    authProvider: 'password',
    displayName: 'Ziad',
    role: UserRole.manager,
    branchId: 'b1',
    isActive: true,
  );

  // A fixed "now": Monday 2026-07-13, 09:00 (inside a morning shift window).
  final now = DateTime(2026, 7, 13, 9);

  WeeklyScheduleEntity rosterAllMornings() => WeeklyScheduleEntity(
        id: 'b1_w',
        branchId: 'b1',
        weekStart: ScheduleWeek.startOf(now),
        assignments: {
          for (final d in ScheduleDay.values)
            d: {
              ScheduleShift.morning: ['u1']
            },
        },
      );

  late _FakeAttendanceRepository repo;

  AttendanceCubit build({
    DateTime? at,
    bool noSchedule = false,
    BranchGeofence? geofence = _geofence,
    LocationResult? location,
    bool managersCanClock = true,
  }) {
    repo = _FakeAttendanceRepository();
    return AttendanceCubit(
      repository: repo,
      scheduleRepository:
          _FakeScheduleRepository(noSchedule ? null : rosterAllMornings()),
      branchRepository:
          _FakeBranchRepository(geofence, managersCanClock: managersCanClock),
      service: const AttendanceService(),
      locationService:
          _FakeLocationService(location ?? _fixNear(20)), // ~20 m: at the branch
      clockIn: ClockIn(repo),
      clockOut: ClockOut(repo),
      requestCorrection: RequestCorrection(repo),
      now: () => at ?? now,
    );
  }

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  AttendanceEntity openRecord({List<AttendanceBreak> breaks = const []}) =>
      AttendanceEntity(
        id: 'u1_20260713_morning',
        userId: 'u1',
        branchId: 'b1',
        shift: ScheduleShift.morning,
        date: DateTime(2026, 7, 13),
        scheduledStart: DateTime(2026, 7, 13, 8, 30),
        scheduledEnd: DateTime(2026, 7, 13, 16, 30),
        clockIn: DateTime(2026, 7, 13, 8, 30),
        breaks: breaks,
        status: AttendanceStatus.inProgress,
      );

  test('load resolves today\'s shift + scheduled window', () async {
    final cubit = build();
    await cubit.load(user);
    repo.pushHistory([]);
    await pump();

    final loaded = cubit.state.maybeMap(loaded: (s) => s, orElse: () => null);
    expect(loaded, isNotNull);
    expect(loaded!.shift, ScheduleShift.morning);
    expect(loaded.scheduledStart, DateTime(2026, 7, 13, 8, 30));
    expect(loaded.scheduledEnd, DateTime(2026, 7, 13, 16, 30));
    expect(loaded.today, isNull);
    expect(loaded.config.enabled, isTrue);
    expect(cubit.clockInCheck.allowed, isTrue);
    await cubit.close();
  });

  test('clockIn at the branch writes a verified in-progress record', () async {
    final cubit = build(); // default: geofence + a ~20 m fix
    await cubit.load(user);
    repo.pushHistory([]);
    await pump();

    await cubit.clockIn();
    expect(repo.clockedIn, hasLength(1));
    final rec = repo.clockedIn.single;
    expect(rec.id, 'u1_20260713_morning');
    expect(rec.status, AttendanceStatus.inProgress);
    expect(rec.scheduledStart, DateTime(2026, 7, 13, 8, 30));
    // GPS verification was captured + passed.
    expect(rec.clockInVerification, isNotNull);
    expect(rec.clockInVerification!.verified, isTrue);
    expect(rec.clockInVerification!.withinRadius, isTrue);
    await cubit.close();
  });

  test('clockIn outside the allowed radius is blocked (no write)', () async {
    final cubit = build(location: _fixNear(500)); // ~500 m from the branch
    await cubit.load(user);
    repo.pushHistory([]);
    await pump();

    final states = <AttendanceState>[];
    final sub = cubit.stream.listen(states.add);
    await cubit.clockIn();
    await pump();
    await sub.cancel();

    expect(repo.clockedIn, isEmpty);
    expect(
      states.any((s) => s.maybeMap(error: (_) => true, orElse: () => false)),
      isTrue,
    );
    await cubit.close();
  });

  test('clockIn with location permission denied is blocked (no write)', () async {
    final cubit = build(
      location: const LocationResult.failure(LocationError.permissionDenied),
    );
    await cubit.load(user);
    repo.pushHistory([]);
    await pump();

    await cubit.clockIn();
    expect(repo.clockedIn, isEmpty);
    await cubit.close();
  });

  // ADR-020 reverses the old rule (a no-geofence branch used to be refused
  // forever, which locked it out of attendance entirely). `soft`/`strict` both
  // mean "compare the fix to the geofence", so with no geofence the effective
  // policy is `none` and the clock is a pure time action.
  test('clockIn with no geofence records the punch, unverified', () async {
    final cubit = build(geofence: null);
    await cubit.load(user);
    repo.pushHistory([]);
    await pump();

    await cubit.clockIn();

    expect(repo.clockedIn, hasLength(1));
    // No coordinates are captured when nothing can be checked against them.
    expect(repo.clockedIn.single.clockInVerification, isNull);
    await cubit.close();
  });

  test('clockIn does nothing with no rostered shift — there is no shift to '
      'clock into', () async {
    final cubit = build(noSchedule: true); // getSchedule → null
    await cubit.load(user);
    repo.pushHistory([]);
    await pump();

    // Eligibility no longer blocks (ADR-018), but the *scheduled* clock-in path
    // still has no target: starting an unscheduled shift is its own deliberate
    // action, never something the primary button falls through to.
    expect(cubit.clockInCheck.allowed, isTrue);
    await cubit.clockIn();
    expect(repo.clockedIn, isEmpty);
    await cubit.close();
  });

  group('manager open shift (presence-only)', () {
    test('a manager with no roster still gets an open-shift clock target',
        () async {
      final cubit = build(noSchedule: true);
      await cubit.load(manager);
      repo.pushHistory([]);
      await pump();

      final s = cubit.state.mapOrNull(loaded: (x) => x);
      expect(s, isNotNull);
      // Presence-style: no schedule enforcement, and a target exists so the
      // *primary* Clock In can act (the bug was clockIn falling through with a
      // null target for a shift-less manager).
      expect(s!.config.enforceSchedule, isFalse);
      expect(s.shift, isNotNull);
      expect(s.scheduledStart, isNull);
      expect(s.scheduledEnd, isNull);
      expect(cubit.clockInCheck.allowed, isTrue);
      await cubit.close();
    });

    test('the primary Clock In writes a presence record for a shift-less manager',
        () async {
      final cubit = build(noSchedule: true);
      await cubit.load(manager);
      repo.pushHistory([]);
      await pump();

      await cubit.clockIn(); // the *primary* action, no reason required
      expect(repo.clockedIn, hasLength(1));
      final rec = repo.clockedIn.single;
      expect(rec.presenceOnly, isTrue);
      expect(rec.scheduledStart, isNull);
      expect(rec.scheduledEnd, isNull);
      expect(rec.clockInVerification, isNotNull); // GPS still applies
      await cubit.close();
    });

    test('a rostered manager still clocks presence-only — no scheduled window',
        () async {
      final cubit = build(); // manager u1 is on the roster (all mornings)
      await cubit.load(manager);
      repo.pushHistory([]);
      await pump();

      final s = cubit.state.mapOrNull(loaded: (x) => x);
      expect(s!.shift, ScheduleShift.morning); // the rostered bucket
      expect(s.scheduledStart, isNull); // but the window is dropped
      expect(s.scheduledEnd, isNull);

      await cubit.clockIn();
      expect(repo.clockedIn.single.scheduledStart, isNull);
      await cubit.close();
    });

    test('clock-in is blocked when the branch has manager clock-in switched off',
        () async {
      final cubit = build(noSchedule: true, managersCanClock: false);
      await cubit.load(manager);
      repo.pushHistory([]);
      await pump();

      final s = cubit.state.mapOrNull(loaded: (x) => x);
      expect(s!.config.enabled, isFalse);
      expect(cubit.clockInCheck.allowed, isFalse);
      await cubit.clockIn();
      expect(repo.clockedIn, isEmpty);
      await cubit.close();
    });
  });

  group('unscheduled shift (ADR-018)', () {
    test('records a GPS-verified punch with no scheduled window', () async {
      final cubit = build(noSchedule: true);
      await cubit.load(user);
      repo.pushHistory([]);
      await pump();

      final ok = await cubit.clockInUnscheduled(reason: 'Covering for Sara');

      expect(ok, isTrue);
      expect(repo.clockedIn, hasLength(1));
      final written = repo.clockedIn.single;
      // The absence of a scheduled window is what marks it unscheduled
      // everywhere downstream.
      expect(written.scheduledStart, isNull);
      expect(written.scheduledEnd, isNull);
      expect(written.notes, 'Covering for Sara');
      expect(written.clockInVerification, isNotNull);
      await cubit.close();
    });

    test('a reason is mandatory', () async {
      final cubit = build(noSchedule: true);
      await cubit.load(user);
      repo.pushHistory([]);
      await pump();

      expect(await cubit.clockInUnscheduled(reason: '   '), isFalse);
      expect(repo.clockedIn, isEmpty);
      await cubit.close();
    });

    test('refused when the person already has a rostered shift', () async {
      final cubit = build(); // normal roster
      await cubit.load(user);
      repo.pushHistory([]);
      await pump();

      expect(await cubit.clockInUnscheduled(reason: 'Extra hours'), isFalse);
      expect(repo.clockedIn, isEmpty);
      await cubit.close();
    });
  });

  test('clockOut finalizes with computed totals', () async {
    final cubit = build(at: DateTime(2026, 7, 13, 17)); // 30m overtime
    await cubit.load(user);
    repo.pushHistory([openRecord()]); // clocked in 08:30
    await pump();

    await cubit.clockOut();
    expect(repo.clockedOut, hasLength(1));
    final out = repo.clockedOut.single;
    expect(out.id, 'u1_20260713_morning');
    expect(out.status, AttendanceStatus.completed);
    expect(out.totals.workedMinutes, 510); // 08:30 → 17:00
    expect(out.totals.overtimeMinutes, 30);
    await cubit.close();
  });

  test('session is exposed while open, and cleared when it closes', () async {
    final cubit = build(at: DateTime(2026, 7, 13, 12));
    await cubit.load(user);
    repo.pushHistory([openRecord()]);
    await pump();

    final open = cubit.state.mapOrNull(loaded: (s) => s);
    expect(open!.session, isNotNull);
    expect(open.session!.isOpen, isTrue);

    // A clocked-out record for the day → no live session.
    final done = openRecord().copyWith(
      clockOut: DateTime(2026, 7, 13, 16, 30),
      status: AttendanceStatus.completed,
    );
    repo.pushHistory([done]);
    await pump();
    final closed = cubit.state.mapOrNull(loaded: (s) => s);
    expect(closed!.session, isNull);
    expect(closed.today, isNotNull); // today's finished record still shown
    await cubit.close();
  });

  test('syncing + offline flags reflect the history feed metadata', () async {
    final cubit = build();
    await cubit.load(user);
    repo.pushHistory([], offline: true, pending: true);
    await pump();

    final loaded = cubit.state.maybeMap(loaded: (s) => s, orElse: () => null);
    expect(loaded!.offline, isTrue);
    expect(loaded.syncing, isTrue);

    repo.pushHistory([], offline: false, pending: false);
    await pump();
    final synced = cubit.state.maybeMap(loaded: (s) => s, orElse: () => null);
    expect(synced!.offline, isFalse);
    expect(synced.syncing, isFalse);
    await cubit.close();
  });

  test('requestCorrection files a pending correction for a settled record',
      () async {
    final cubit = build(at: DateTime(2026, 7, 13, 18));
    await cubit.load(user);
    // A session auto-closed to pendingReview (never clocked out).
    final pendingReview = openRecord().copyWith(
      status: AttendanceStatus.pendingReview,
    );
    repo.pushHistory([pendingReview]);
    await pump();

    await cubit.requestCorrection(
      record: pendingReview,
      kind: AttendanceCorrectionKind.missingClockOut,
      reason: 'Forgot to clock out',
      proposedClockOut: DateTime(2026, 7, 13, 16, 30),
    );

    expect(repo.corrections, hasLength(1));
    final c = repo.corrections.single;
    expect(c.attendanceId, 'u1_20260713_morning');
    expect(c.userId, 'u1');
    expect(c.requestedBy, 'u1');
    expect(c.status, RequestStatus.pending);
    expect(c.kind, AttendanceCorrectionKind.missingClockOut);
    expect(c.proposedClockOut, DateTime(2026, 7, 13, 16, 30));
    await cubit.close();
  });

  test('requestCorrection is blocked while the session is still open', () async {
    final cubit = build(at: DateTime(2026, 7, 13, 12));
    await cubit.load(user);
    repo.pushHistory([openRecord()]); // still open
    await pump();

    await cubit.requestCorrection(
      record: openRecord(),
      kind: AttendanceCorrectionKind.wrongTime,
      reason: 'anything',
      proposedClockOut: DateTime(2026, 7, 13, 16, 30),
    );
    expect(repo.corrections, isEmpty); // sessionOpen block → no write
    await cubit.close();
  });

  test('requestMissedPunch files an absence-dispute for a shift with no record',
      () async {
    final cubit = build(at: DateTime(2026, 7, 13, 18)); // after the shift
    await cubit.load(user);
    repo.pushHistory([]); // Absent — never clocked in, no record exists
    await pump();

    await cubit.requestMissedPunch(
      proposedClockIn: DateTime(2026, 7, 13, 8, 30),
      proposedClockOut: DateTime(2026, 7, 13, 16, 30),
      reason: 'Forgot to clock in — worked the full shift',
    );

    expect(repo.corrections, hasLength(1));
    final c = repo.corrections.single;
    expect(c.attendanceId, 'u1_20260713_morning');
    expect(c.kind, AttendanceCorrectionKind.absenceDispute);
    expect(c.status, RequestStatus.pending);
    expect(c.proposedClockIn, DateTime(2026, 7, 13, 8, 30));
    // Carries the rostered window so the materialized record is measurable.
    expect(c.scheduledStart, DateTime(2026, 7, 13, 8, 30));
    expect(c.scheduledEnd, DateTime(2026, 7, 13, 16, 30));
    await cubit.close();
  });

  test('requestMissedPunch is a no-op when nothing is rostered today', () async {
    final cubit = build(at: DateTime(2026, 7, 13, 18), noSchedule: true);
    await cubit.load(user);
    repo.pushHistory([]);
    await pump();

    await cubit.requestMissedPunch(
      proposedClockIn: DateTime(2026, 7, 13, 8, 30),
      reason: 'Forgot to clock in',
    );
    expect(repo.corrections, isEmpty); // no shift context → nothing to add
    await cubit.close();
  });

  test('a second correction is blocked while one is already pending (R15)',
      () async {
    final cubit = build(at: DateTime(2026, 7, 13, 18));
    await cubit.load(user);
    final pendingReview = openRecord().copyWith(
      status: AttendanceStatus.pendingReview,
    );
    repo.pushHistory([pendingReview]);
    // An open correction already exists for this record.
    repo.pushCorrections([
      AttendanceCorrectionEntity(
        id: 'c1',
        attendanceId: 'u1_20260713_morning',
        userId: 'u1',
        requestedBy: 'u1',
        kind: AttendanceCorrectionKind.missingClockOut,
        reason: 'earlier',
        status: RequestStatus.pending,
      ),
    ]);
    await pump();

    await cubit.requestCorrection(
      record: pendingReview,
      kind: AttendanceCorrectionKind.wrongTime,
      reason: 'a second one',
      proposedClockOut: DateTime(2026, 7, 13, 16, 30),
    );
    expect(repo.corrections, isEmpty); // duplicateOpen → no write
    await cubit.close();
  });

  test('previewLocation exposes an at-branch preview in the Ready phase',
      () async {
    final cubit = build(location: _fixNear(20)); // ~20 m from the branch
    await cubit.load(user);
    repo.pushHistory([]);
    await pump();

    await cubit.previewLocation();
    final s = cubit.state.mapOrNull(loaded: (x) => x);
    expect(s!.previewVerification, isNotNull);
    expect(s.previewVerification!.verified, isTrue);
    expect(s.previewError, isNull);
    await cubit.close();
  });

  test('previewLocation flags an outside-radius preview', () async {
    final cubit = build(location: _fixNear(500));
    await cubit.load(user);
    repo.pushHistory([]);
    await pump();

    await cubit.previewLocation();
    final s = cubit.state.mapOrNull(loaded: (x) => x);
    expect(s!.previewVerification!.withinRadius, isFalse);
    await cubit.close();
  });

  test('previewLocation surfaces a permission error', () async {
    final cubit = build(
      location: const LocationResult.failure(LocationError.permissionDenied),
    );
    await cubit.load(user);
    repo.pushHistory([]);
    await pump();

    await cubit.previewLocation();
    final s = cubit.state.mapOrNull(loaded: (x) => x);
    expect(s!.previewError, LocationError.permissionDenied);
    expect(s.previewVerification, isNull);
    await cubit.close();
  });

  test('previewLocation is a no-op once clocked in', () async {
    final cubit = build();
    await cubit.load(user);
    repo.pushHistory([openRecord()]); // an open session → Working phase
    await pump();

    await cubit.previewLocation();
    final s = cubit.state.mapOrNull(loaded: (x) => x);
    expect(s!.previewVerification, isNull);
    await cubit.close();
  });

  test('the live timer is cancelled on close (no pending timer)', () async {
    final cubit = build();
    await cubit.load(user);
    repo.pushHistory([openRecord()]); // open session → timer starts
    await pump();
    await cubit.close(); // must cancel the periodic timer
  });
}
