import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/attendance_location_policy.dart';
import 'package:drop/core/enums/attendance_status.dart';
import 'package:drop/core/enums/leave_type.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/features/attendance/domain/attendance_break.dart';
import 'package:drop/features/attendance/domain/attendance_config.dart';
import 'package:drop/features/attendance/domain/attendance_gps.dart';
import 'package:drop/features/attendance/domain/attendance_location.dart';
import 'package:drop/features/attendance/domain/attendance_location_service.dart';
import 'package:drop/features/attendance/domain/attendance_service.dart';
import 'package:drop/features/attendance/domain/attendance_validation.dart';
import 'package:drop/features/attendance/domain/entities/attendance_entity.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';

void main() {
  const enabled = AttendanceConfig(enabled: true);
  const managerFlexible = AttendanceConfig(
    enabled: true,
    enforceSchedule: false,
  );
  final start = DateTime(2026, 7, 11, 8, 30);
  final end = DateTime(2026, 7, 11, 16, 30);

  AttendanceEntity record({
    DateTime? clockIn,
    DateTime? clockOut,
    List<AttendanceBreak> breaks = const [],
    AttendanceStatus status = AttendanceStatus.inProgress,
  }) =>
      AttendanceEntity(
        id: 'u_20260711_morning',
        userId: 'u',
        shift: ScheduleShift.morning,
        date: DateTime(2026, 7, 11),
        scheduledStart: start,
        scheduledEnd: end,
        clockIn: clockIn,
        clockOut: clockOut,
        breaks: breaks,
        status: status,
      );

  group('checkClockIn (eligibility)', () {
    AttendanceCheck check({
      bool userActive = true,
      ScheduleShift? shift = ScheduleShift.morning,
      LeaveType? leave,
      AttendanceEntity? existing,
      DateTime? now,
      DateTime? scheduledStart,
      DateTime? scheduledEnd,
      AttendanceConfig config = enabled,
    }) =>
        AttendanceValidation.checkClockIn(
          userActive: userActive,
          todaysShift: shift,
          leave: leave,
          existing: existing,
          now: now,
          scheduledStart: scheduledStart,
          scheduledEnd: scheduledEnd,
          config: config,
        );

    test('blocked when the module is disabled', () {
      expect(check(config: const AttendanceConfig(enabled: false)).reason,
          AttendanceBlock.notEnabled);
    });

    test('blocked when the account is inactive', () {
      expect(check(userActive: false).reason, AttendanceBlock.userDisabled);
    });

    test('blocked when on leave', () {
      expect(check(leave: LeaveType.sick).reason, AttendanceBlock.onLeave);
    });

    test('no shift no longer blocks — ADR-018 flipped the default', () {
      // A blocked punch does not prevent the work, it prevents the record.
      expect(check(shift: null).allowed, isTrue);
    });

    test('a branch may still switch unscheduled shifts off', () {
      final c = check(
        shift: null,
        config: const AttendanceConfig(
          enabled: true,
          allowUnscheduledClockIn: false,
        ),
      );
      expect(c.reason, AttendanceBlock.noActiveShift);
    });

    test('blocked when already clocked in (open session)', () {
      expect(check(existing: record(clockIn: start)).reason,
          AttendanceBlock.alreadyClockedIn);
    });

    test('blocked when the shift is already completed', () {
      final done = record(
          clockIn: start, clockOut: end, status: AttendanceStatus.completed);
      expect(check(existing: done).reason, AttendanceBlock.alreadyClockedOut);
    });

    test('allowed (eligibility) with no prior record', () {
      expect(check().allowed, isTrue);
    });

    test('blocked before the clock-in window opens (R1, default 15 min lead)',
        () {
      // Shift starts 08:30 → window opens 08:15. At 08:00 clock-in is refused.
      final c = check(
        now: DateTime(2026, 7, 13, 8, 0),
        scheduledStart: DateTime(2026, 7, 13, 8, 30),
      );
      expect(c.reason, AttendanceBlock.tooEarly);
      expect(c.message, contains('08:15'));
    });

    test('allowed once inside the window', () {
      final c = check(
        now: DateTime(2026, 7, 13, 8, 20), // after 08:15
        scheduledStart: DateTime(2026, 7, 13, 8, 30),
      );
      expect(c.allowed, isTrue);
    });

    test('no window enforced when now/scheduledStart are absent', () {
      expect(check(now: null, scheduledStart: null).allowed, isTrue);
    });

    test('blocked after the shift has ended — cannot clock into a shift at '
        'night (upper bound)', () {
      // Morning shift 08:30–16:30, clock-in attempted at 22:58.
      final c = check(
        now: DateTime(2026, 7, 13, 22, 58),
        scheduledStart: DateTime(2026, 7, 13, 8, 30),
        scheduledEnd: DateTime(2026, 7, 13, 16, 30),
      );
      expect(c.reason, AttendanceBlock.tooLate);
      expect(c.message, contains('16:30'));
    });

    test('late but still within the shift is allowed (recorded as lateness)', () {
      final c = check(
        now: DateTime(2026, 7, 13, 10, 0), // 1.5h late, before 16:30 end
        scheduledStart: DateTime(2026, 7, 13, 8, 30),
        scheduledEnd: DateTime(2026, 7, 13, 16, 30),
      );
      expect(c.allowed, isTrue);
    });

    test('allowed right up to the scheduled end', () {
      final c = check(
        now: DateTime(2026, 7, 13, 16, 30),
        scheduledStart: DateTime(2026, 7, 13, 8, 30),
        scheduledEnd: DateTime(2026, 7, 13, 16, 30),
      );
      expect(c.allowed, isTrue);
    });

    test('overnight shift stays open past midnight (upper bound honours the '
        'real end instant)', () {
      // Night 20:00 → 02:00 (next day). At 01:00 the window is still open.
      final c = check(
        now: DateTime(2026, 7, 14, 1, 0),
        scheduledStart: DateTime(2026, 7, 13, 20, 0),
        scheduledEnd: DateTime(2026, 7, 14, 2, 0),
      );
      expect(c.allowed, isTrue);
    });

    test('no upper bound enforced when scheduledEnd is absent (unscheduled)', () {
      final c = check(
        now: DateTime(2026, 7, 13, 23, 0),
        scheduledStart: null,
        scheduledEnd: null,
      );
      expect(c.allowed, isTrue);
    });

    // No manager-specific GPS test lives here on purpose: `checkGpsFix` takes no
    // `AttendanceConfig`, so the geofence gate is role-independent by
    // construction and a "manager" variant would be a byte-identical copy of the
    // cases in the `checkGpsFix` group below.
    group('manager presence-style attendance', () {
      test('allows clock-in without a rostered shift when unscheduled is off',
          () {
        expect(
          check(
            shift: null,
            config: managerFlexible.copyWith(allowUnscheduledClockIn: false),
          ).allowed,
          isTrue,
        );
      });

      test('allows clock-in at arbitrary times outside the early window', () {
        final scheduledStart = DateTime(2026, 7, 13, 12, 0);
        for (final now in [
          DateTime(2026, 7, 13, 5, 0),
          DateTime(2026, 7, 13, 15, 0),
          DateTime(2026, 7, 13, 22, 0),
        ]) {
          expect(
            check(
              now: now,
              scheduledStart: scheduledStart,
              config: managerFlexible,
            ).allowed,
            isTrue,
            reason: 'manager clock-in at $now should not be schedule-gated',
          );
        }
      });

      test('keeps the enabled gate', () {
        expect(
          check(config: const AttendanceConfig(enforceSchedule: false)).reason,
          AttendanceBlock.notEnabled,
        );
      });

      test('keeps the open-session gate', () {
        expect(
          check(existing: record(clockIn: start), config: managerFlexible).reason,
          AttendanceBlock.alreadyClockedIn,
        );
      });

      test('keeps the completed-session gate', () {
        expect(
          check(
            existing: record(
              clockIn: start,
              clockOut: end,
              status: AttendanceStatus.completed,
            ),
            config: managerFlexible,
          ).reason,
          AttendanceBlock.alreadyClockedOut,
        );
      });

      test('keeps the active-account gate', () {
        expect(
          check(userActive: false, config: managerFlexible).reason,
          AttendanceBlock.userDisabled,
        );
      });

      test('keeps the leave gate', () {
        expect(
          check(leave: LeaveType.sick, config: managerFlexible).reason,
          AttendanceBlock.onLeave,
        );
      });
    });
  });

  group('checkGpsFix', () {
    AttendanceVerification verification({
      double distance = 10,
      double accuracy = 8,
      double radius = 150,
      double minAccuracy = 50,
    }) =>
        AttendanceVerification(
          location: AttendanceLocation(
              latitude: 30, longitude: 31, accuracyMeters: accuracy),
          distanceMeters: distance,
          radiusMeters: radius,
          minAccuracyMeters: minAccuracy,
          withinRadius: distance <= radius,
          accuracyOk: accuracy <= minAccuracy,
        );

    AttendanceCheck gps({
      LocationError? error,
      AttendanceVerification? v,
      bool geofence = true,
      AttendanceLocationPolicy policy = AttendanceLocationPolicy.strict,
    }) =>
        AttendanceValidation.checkGpsFix(
          locationError: error,
          verification: v,
          geofenceConfigured: geofence,
          policy: policy,
        );

    test('location service off → serviceDisabled', () {
      expect(gps(error: LocationError.serviceDisabled).reason,
          AttendanceBlock.serviceDisabled);
    });
    test('permission denied → permissionDenied', () {
      expect(gps(error: LocationError.permissionDenied).reason,
          AttendanceBlock.permissionDenied);
    });
    test('no fix → locationUnavailable', () {
      expect(gps(error: LocationError.unavailable).reason,
          AttendanceBlock.locationUnavailable);
    });
    test('branch not geofenced → noGeofence', () {
      expect(gps(geofence: false).reason, AttendanceBlock.noGeofence);
    });
    test('weak GPS → lowAccuracy', () {
      expect(gps(v: verification(accuracy: 120)).reason,
          AttendanceBlock.lowAccuracy);
    });
    test('too far → outsideRadius', () {
      expect(gps(v: verification(distance: 500)).reason,
          AttendanceBlock.outsideRadius);
    });
    test('at the branch with a good fix → allowed', () {
      expect(gps(v: verification()).allowed, isTrue);
    });

    // ADR-020 — the policy is the single knob, and it is now actually read.
    group('location policy', () {
      test('none never refuses a punch, whatever the fix says', () {
        const none = AttendanceLocationPolicy.none;
        expect(gps(policy: none, geofence: false).allowed, isTrue);
        expect(
          gps(policy: none, error: LocationError.permissionDenied).allowed,
          isTrue,
        );
        expect(
          gps(policy: none, error: LocationError.serviceDisabled).allowed,
          isTrue,
        );
        expect(gps(policy: none, v: verification(distance: 9000)).allowed,
            isTrue);
        expect(
            gps(policy: none, v: verification(accuracy: 500)).allowed, isTrue);
      });

      test('soft records but never refuses — outside the fence still punches',
          () {
        const soft = AttendanceLocationPolicy.soft;
        expect(gps(policy: soft, v: verification(distance: 9000)).allowed,
            isTrue);
        expect(
            gps(policy: soft, v: verification(accuracy: 500)).allowed, isTrue);
        expect(
          gps(policy: soft, error: LocationError.permissionDenied).allowed,
          isTrue,
        );
      });

      test('strict is the only policy that blocks', () {
        const strict = AttendanceLocationPolicy.strict;
        expect(gps(policy: strict, v: verification(distance: 9000)).reason,
            AttendanceBlock.outsideRadius);
        expect(gps(policy: strict, v: verification(accuracy: 500)).reason,
            AttendanceBlock.lowAccuracy);
        // A strict branch whose geofence vanished must fail loudly, not pass.
        expect(gps(policy: strict, geofence: false).reason,
            AttendanceBlock.noGeofence);
      });

      test('strict is the default, so an un-migrated caller keeps the gate', () {
        expect(
          AttendanceValidation.checkGpsFix(
            locationError: null,
            verification: verification(distance: 9000),
            geofenceConfigured: true,
          ).reason,
          AttendanceBlock.outsideRadius,
        );
      });
    });
  });

  group('AttendanceService.resolveLocationPolicy', () {
    test('a branch with no geofence collapses to none', () {
      for (final configured in AttendanceLocationPolicy.values) {
        expect(
          AttendanceService.resolveLocationPolicy(
            configured: configured,
            hasGeofence: false,
          ),
          AttendanceLocationPolicy.none,
          reason: '$configured cannot be checked without a fence',
        );
      }
    });

    test('a branch with a geofence keeps what it configured', () {
      for (final configured in AttendanceLocationPolicy.values) {
        expect(
          AttendanceService.resolveLocationPolicy(
            configured: configured,
            hasGeofence: true,
          ),
          configured,
        );
      }
    });

    test('the shipped default is strict, matching what the app enforces', () {
      expect(
        AttendanceConfig.defaults.locationPolicy,
        AttendanceLocationPolicy.strict,
      );
    });
  });

  group('AttendanceService manager branch policy', () {
    const service = AttendanceService();
    const manager = UserEntity(
      uid: 'manager',
      email: 'manager@drop.test',
      authProvider: 'password',
      role: UserRole.manager,
    );
    const employee = UserEntity(
      uid: 'employee',
      email: 'employee@drop.test',
      authProvider: 'password',
      role: UserRole.employee,
    );
    const clockDisabled =
        BranchEntity(id: 'b1', name: 'Branch 1', managersCanClock: false);
    const clockEnabled = BranchEntity(id: 'b2', name: 'Branch 2');

    test('manager follows a disabled branch flag', () {
      expect(service.configFor(manager, branch: clockDisabled).enabled, isFalse);
    });

    test('manager remains enabled when the branch flag is on', () {
      expect(service.configFor(manager, branch: clockEnabled).enabled, isTrue);
    });

    test('manager does not enforce the schedule', () {
      expect(
        service.configFor(manager, branch: clockEnabled).enforceSchedule,
        isFalse,
      );
    });

    test('manager fails open while the branch is unavailable', () {
      expect(service.configFor(manager).enabled, isTrue);
    });

    test('employee ignores the manager branch flag', () {
      expect(service.configFor(employee, branch: clockDisabled).enabled, isTrue);
    });

    test('employee enforces the schedule', () {
      expect(
        service.configFor(employee, branch: clockDisabled).enforceSchedule,
        isTrue,
      );
    });
  });

  group('checkClockOut', () {
    AttendanceCheck check(AttendanceEntity? existing,
            {AttendanceConfig config = enabled}) =>
        AttendanceValidation.checkClockOut(
            existing: existing, now: DateTime(2026, 7, 11, 16, 30), config: config);

    const disabled = AttendanceConfig(enabled: false);

    test('allows an open session to close when the module is disabled', () {
      expect(check(record(clockIn: start), config: disabled).allowed, isTrue);
    });

    test('blocks a clock-out with no session when the module is disabled', () {
      expect(check(null, config: disabled).reason, AttendanceBlock.notEnabled);
    });

    test('blocked when not clocked in', () {
      expect(check(null).reason, AttendanceBlock.notClockedIn);
    });

    test('blocked when already clocked out', () {
      expect(
        check(record(clockIn: start, clockOut: end, status: AttendanceStatus.completed))
            .reason,
        AttendanceBlock.alreadyClockedOut,
      );
    });

    test('allowed for an open clocked-in session', () {
      expect(check(record(clockIn: start)).allowed, isTrue);
    });

    test('manager presence attendance can clock out normally', () {
      expect(
        check(record(clockIn: start), config: managerFlexible).allowed,
        isTrue,
      );
    });
  });
}
