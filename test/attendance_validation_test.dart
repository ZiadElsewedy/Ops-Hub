import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/attendance_status.dart';
import 'package:drop/core/enums/leave_type.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/features/attendance/domain/attendance_break.dart';
import 'package:drop/features/attendance/domain/attendance_config.dart';
import 'package:drop/features/attendance/domain/attendance_gps.dart';
import 'package:drop/features/attendance/domain/attendance_location.dart';
import 'package:drop/features/attendance/domain/attendance_location_service.dart';
import 'package:drop/features/attendance/domain/attendance_validation.dart';
import 'package:drop/features/attendance/domain/entities/attendance_entity.dart';

void main() {
  const enabled = AttendanceConfig(enabled: true);
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
      AttendanceConfig config = enabled,
    }) =>
        AttendanceValidation.checkClockIn(
          userActive: userActive,
          todaysShift: shift,
          leave: leave,
          existing: existing,
          now: now,
          scheduledStart: scheduledStart,
          config: config,
        );

    test('blocked when the module is disabled', () {
      expect(check(config: AttendanceConfig.defaults).reason,
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
    }) =>
        AttendanceValidation.checkGpsFix(
          locationError: error,
          verification: v,
          geofenceConfigured: geofence,
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
  });

  group('checkClockOut', () {
    AttendanceCheck check(AttendanceEntity? existing) =>
        AttendanceValidation.checkClockOut(
            existing: existing, now: DateTime(2026, 7, 11, 16, 30), config: enabled);

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
  });
}
