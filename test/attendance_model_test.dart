import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/attendance_source.dart';
import 'package:drop/core/enums/attendance_status.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/features/attendance/data/models/attendance_model.dart';
import 'package:drop/features/attendance/domain/attendance_break.dart';
import 'package:drop/features/attendance/domain/attendance_gps.dart';
import 'package:drop/features/attendance/domain/attendance_location.dart';
import 'package:drop/features/attendance/domain/entities/attendance_entity.dart';
import 'package:drop/features/attendance/domain/entities/attendance_event.dart';

void main() {
  final entity = AttendanceEntity(
    id: 'u1_20260711_morning',
    userId: 'u1',
    userName: 'Ziad',
    branchId: 'b1',
    shift: ScheduleShift.morning,
    date: DateTime(2026, 7, 11),
    scheduledStart: DateTime(2026, 7, 11, 8, 30),
    scheduledEnd: DateTime(2026, 7, 11, 16, 30),
    clockIn: DateTime(2026, 7, 11, 8, 32),
    clockOut: DateTime(2026, 7, 11, 16, 35),
    breaks: [
      AttendanceBreak(
          start: DateTime(2026, 7, 11, 12), end: DateTime(2026, 7, 11, 12, 30)),
    ],
    status: AttendanceStatus.completed,
    workedMinutes: 453,
    lateMinutes: 0,
    earlyLeaveMinutes: 0,
    overtimeMinutes: 5,
    breakMinutes: 30,
    clockInVerification: const AttendanceVerification(
      location: AttendanceLocation(
          latitude: 30.05, longitude: 31.23, accuracyMeters: 12.5),
      distanceMeters: 22,
      radiusMeters: 150,
      minAccuracyMeters: 50,
      withinRadius: true,
      accuracyOk: true,
    ),
    photoUrl: 'https://x/selfie.jpg',
    deviceId: 'dev-1',
    notes: 'ok',
    source: AttendanceSource.clock,
    schemaVersion: 1,
  );

  test('fromEntity → toEntity is a lossless round-trip', () {
    expect(AttendanceModel.fromEntity(entity).toEntity(), entity);
  });

  test('toCreateMap → fromMap preserves the clocked fields', () {
    final map = AttendanceModel.fromEntity(entity).toCreateMap();
    final back = AttendanceModel.fromMap(map, id: entity.id).toEntity();

    expect(back.id, entity.id);
    expect(back.userId, 'u1');
    expect(back.userName, 'Ziad');
    expect(back.branchId, 'b1');
    expect(back.shift, ScheduleShift.morning);
    expect(back.date, DateTime(2026, 7, 11));
    expect(back.dayKey, '20260711');
    expect(back.scheduledStart, DateTime(2026, 7, 11, 8, 30));
    expect(back.clockIn, DateTime(2026, 7, 11, 8, 32));
    expect(back.clockOut, DateTime(2026, 7, 11, 16, 35));
    expect(back.status, AttendanceStatus.completed);
    expect(back.workedMinutes, 453);
    expect(back.overtimeMinutes, 5);
    expect(back.breakMinutes, 30);
    expect(back.source, AttendanceSource.clock);
    expect(back.photoUrl, 'https://x/selfie.jpg');
  });

  test('breaks survive serialization (incl. an open break)', () {
    final withOpen = AttendanceModel.fromEntity(entity.copyWith(breaks: [
      AttendanceBreak(start: DateTime(2026, 7, 11, 12)), // open
    ]));
    final map = withOpen.toCreateMap();
    final back = AttendanceModel.fromMap(map).toEntity();
    expect(back.breaks.length, 1);
    expect(back.breaks.first.start, DateTime(2026, 7, 11, 12));
    expect(back.breaks.first.isOpen, isTrue);
  });

  test('clock-in GPS verification survives serialization', () {
    final map = AttendanceModel.fromEntity(entity).toCreateMap();
    final back = AttendanceModel.fromMap(map).toEntity();
    expect(back.clockInVerification, isNotNull);
    expect(back.clockInVerification!.location.latitude, 30.05);
    expect(back.clockInVerification!.location.accuracyMeters, 12.5);
    expect(back.clockInVerification!.distanceMeters, 22);
    expect(back.clockInVerification!.withinRadius, isTrue);
    expect(back.clockInVerification!.verified, isTrue);
  });

  test('presenceOnly survives serialization and defaults false when absent', () {
    final presence = AttendanceModel.fromEntity(entity.copyWith(
      presenceOnly: true,
      scheduledStart: null,
      scheduledEnd: null,
    ));
    final map = presence.toCreateMap();
    expect(map['presenceOnly'], isTrue);
    expect(AttendanceModel.fromMap(map).toEntity().presenceOnly, isTrue);

    // Every record written before this field existed must read as a normal,
    // schedule-measured record.
    final legacy = Map<String, dynamic>.from(presence.toCreateMap())
      ..remove('presenceOnly');
    expect(AttendanceModel.fromMap(legacy).toEntity().presenceOnly, isFalse);
  });

  test('dayKey is written to the create payload (for the branch/day query)', () {
    expect(AttendanceModel.fromEntity(entity).toCreateMap()['dayKey'], '20260711');
  });

  group('audit event (de)serialization', () {
    test('eventToMap omits createdAt (server-stamped) and keeps the fields', () {
      final event = AttendanceEvent(
        id: 'e1',
        kind: AttendanceEventKind.clockedIn,
        actorId: 'u1',
        actorName: 'Ziad',
        data: {'clockIn': DateTime(2026, 7, 11, 8, 32)},
        createdAt: DateTime(2026, 7, 11, 8, 32),
      );
      final map = AttendanceModel.eventToMap(event);
      expect(map['kind'], 'clockedIn');
      expect(map['actorId'], 'u1');
      expect(map.containsKey('createdAt'), isFalse);
      expect(map['data']['clockIn'], isA<Timestamp>()); // DateTime → Timestamp
    });

    test('eventFromMap reads a server-written event', () {
      final back = AttendanceModel.eventFromMap({
        'kind': 'clockedOut',
        'actorId': 'u1',
        'actorName': 'Ziad',
        'note': null,
        'data': {'clockOut': Timestamp.fromDate(DateTime(2026, 7, 11, 16, 35))},
        'createdAt': Timestamp.fromDate(DateTime(2026, 7, 11, 16, 35)),
      }, id: 'e2');
      expect(back.kind, AttendanceEventKind.clockedOut);
      expect(back.actorId, 'u1');
      expect(back.createdAt, DateTime(2026, 7, 11, 16, 35));
      expect(back.data['clockOut'], DateTime(2026, 7, 11, 16, 35)); // Timestamp → DateTime
    });
  });
}
