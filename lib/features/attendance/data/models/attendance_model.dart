import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:opshub/core/enums/attendance_source.dart';
import 'package:opshub/core/enums/attendance_status.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/extensions/firestore_extensions.dart';
import 'package:opshub/features/attendance/domain/attendance_break.dart';
import 'package:opshub/features/attendance/domain/attendance_gps.dart';
import 'package:opshub/features/attendance/domain/attendance_location.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_entity.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_event.dart';

/// Firestore (de)serialization for [AttendanceEntity] — collection
/// `attendance/{id}` (deterministic id). Server-managed timestamps
/// (`createdAt`/`updatedAt`) are written by the datasource, so [toCreateMap]
/// (the clock-in payload) omits them. Embedded [breaks] and [location] are
/// serialized inline (mirrors how `TaskModel` embeds attachments); the audit
/// trail lives in `attendance/{id}/events` ([eventFromMap] / [eventToMap]).
class AttendanceModel {
  final String id;
  final String userId;
  final String? userName;
  final String? branchId;
  final ScheduleShift shift;
  final DateTime date;
  final String dayKey;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;

  /// Presence-style record (managers) — never measured against a roster.
  final bool presenceOnly;
  final DateTime? clockIn;
  final DateTime? clockOut;
  final List<AttendanceBreak> breaks;
  final AttendanceStatus status;
  final int workedMinutes;
  final int lateMinutes;
  final int earlyLeaveMinutes;
  final int overtimeMinutes;
  final int breakMinutes;
  final AttendanceVerification? clockInVerification;
  final AttendanceVerification? clockOutVerification;
  final String? photoUrl;
  final String? deviceId;
  final String? notes;
  final AttendanceSource source;
  final String? resolvedBy;
  final String? resolvedByName;
  final DateTime? resolvedAt;
  final int schemaVersion;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const AttendanceModel({
    required this.id,
    required this.userId,
    this.userName,
    this.branchId,
    required this.shift,
    required this.date,
    required this.dayKey,
    this.scheduledStart,
    this.scheduledEnd,
    this.presenceOnly = false,
    this.clockIn,
    this.clockOut,
    this.breaks = const [],
    this.status = AttendanceStatus.inProgress,
    this.workedMinutes = 0,
    this.lateMinutes = 0,
    this.earlyLeaveMinutes = 0,
    this.overtimeMinutes = 0,
    this.breakMinutes = 0,
    this.clockInVerification,
    this.clockOutVerification,
    this.photoUrl,
    this.deviceId,
    this.notes,
    this.source = AttendanceSource.clock,
    this.resolvedBy,
    this.resolvedByName,
    this.resolvedAt,
    this.schemaVersion = 1,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory AttendanceModel.fromMap(Map<String, dynamic> map, {String? id}) =>
      AttendanceModel(
        id: id ?? map['id'] as String? ?? '',
        userId: map['userId'] as String? ?? '',
        userName: map['userName'] as String?,
        branchId: map['branchId'] as String?,
        shift: ScheduleShift.fromString(map['shift'] as String?),
        date: map.date('date') ?? DateTime.now(),
        dayKey: map['dayKey'] as String? ?? '',
        scheduledStart: map.date('scheduledStart'),
        scheduledEnd: map.date('scheduledEnd'),
        presenceOnly: map['presenceOnly'] == true,
        clockIn: map.date('clockIn'),
        clockOut: map.date('clockOut'),
        breaks: _breaksFromList(map['breaks']),
        status: AttendanceStatus.fromString(map['status'] as String?),
        workedMinutes: (map['workedMinutes'] as num?)?.toInt() ?? 0,
        lateMinutes: (map['lateMinutes'] as num?)?.toInt() ?? 0,
        earlyLeaveMinutes: (map['earlyLeaveMinutes'] as num?)?.toInt() ?? 0,
        overtimeMinutes: (map['overtimeMinutes'] as num?)?.toInt() ?? 0,
        breakMinutes: (map['breakMinutes'] as num?)?.toInt() ?? 0,
        clockInVerification:
            _verificationFromMap(map['clockInVerification']),
        clockOutVerification:
            _verificationFromMap(map['clockOutVerification']),
        photoUrl: map['photoUrl'] as String?,
        deviceId: map['deviceId'] as String?,
        notes: map['notes'] as String?,
        source: AttendanceSource.fromString(map['source'] as String?),
        resolvedBy: map['resolvedBy'] as String?,
        resolvedByName: map['resolvedByName'] as String?,
        resolvedAt: map.date('resolvedAt'),
        schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
        createdAt: map.date('createdAt'),
        updatedAt: map.date('updatedAt'),
        deletedAt: map.date('deletedAt'),
      );

  factory AttendanceModel.fromEntity(AttendanceEntity e) => AttendanceModel(
        id: e.id,
        userId: e.userId,
        userName: e.userName,
        branchId: e.branchId,
        shift: e.shift,
        date: e.date,
        dayKey: e.dayKey,
        scheduledStart: e.scheduledStart,
        scheduledEnd: e.scheduledEnd,
        presenceOnly: e.presenceOnly,
        clockIn: e.clockIn,
        clockOut: e.clockOut,
        breaks: e.breaks,
        status: e.status,
        workedMinutes: e.workedMinutes,
        lateMinutes: e.lateMinutes,
        earlyLeaveMinutes: e.earlyLeaveMinutes,
        overtimeMinutes: e.overtimeMinutes,
        breakMinutes: e.breakMinutes,
        clockInVerification: e.clockInVerification,
        clockOutVerification: e.clockOutVerification,
        photoUrl: e.photoUrl,
        deviceId: e.deviceId,
        notes: e.notes,
        source: e.source,
        resolvedBy: e.resolvedBy,
        resolvedByName: e.resolvedByName,
        resolvedAt: e.resolvedAt,
        schemaVersion: e.schemaVersion,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
        deletedAt: e.deletedAt,
      );

  AttendanceEntity toEntity() => AttendanceEntity(
        id: id,
        userId: userId,
        userName: userName,
        branchId: branchId,
        shift: shift,
        date: date,
        scheduledStart: scheduledStart,
        scheduledEnd: scheduledEnd,
        presenceOnly: presenceOnly,
        clockIn: clockIn,
        clockOut: clockOut,
        breaks: breaks,
        status: status,
        workedMinutes: workedMinutes,
        lateMinutes: lateMinutes,
        earlyLeaveMinutes: earlyLeaveMinutes,
        overtimeMinutes: overtimeMinutes,
        breakMinutes: breakMinutes,
        clockInVerification: clockInVerification,
        clockOutVerification: clockOutVerification,
        photoUrl: photoUrl,
        deviceId: deviceId,
        notes: notes,
        source: source,
        resolvedBy: resolvedBy,
        resolvedByName: resolvedByName,
        resolvedAt: resolvedAt,
        schemaVersion: schemaVersion,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
      );

  /// The **clock-in create payload**. Server timestamps (`createdAt`/`updatedAt`)
  /// are added by the datasource, so they're omitted here.
  Map<String, dynamic> toCreateMap() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'branchId': branchId,
        'shift': shift.value,
        'date': Timestamp.fromDate(date),
        'dayKey': dayKey,
        'scheduledStart': _ts(scheduledStart),
        'scheduledEnd': _ts(scheduledEnd),
        'presenceOnly': presenceOnly,
        'clockIn': _ts(clockIn),
        'clockOut': _ts(clockOut),
        'breaks': breaksToList(breaks),
        'status': status.value,
        'workedMinutes': workedMinutes,
        'lateMinutes': lateMinutes,
        'earlyLeaveMinutes': earlyLeaveMinutes,
        'overtimeMinutes': overtimeMinutes,
        'breakMinutes': breakMinutes,
        'clockInVerification': verificationToMap(clockInVerification),
        'clockOutVerification': verificationToMap(clockOutVerification),
        'photoUrl': photoUrl,
        'deviceId': deviceId,
        'notes': notes,
        'source': source.value,
        'schemaVersion': schemaVersion,
      };

  // ─── Embedded breaks ({start, end}) ───────────────────────────────────
  static List<AttendanceBreak> _breaksFromList(dynamic raw) {
    if (raw is! List) return const [];
    final out = <AttendanceBreak>[];
    for (final b in raw) {
      if (b is Map) {
        final start = (b['start'] as Timestamp?)?.toDate();
        if (start == null) continue;
        out.add(AttendanceBreak(
          start: start,
          end: (b['end'] as Timestamp?)?.toDate(),
        ));
      }
    }
    return out;
  }

  /// Serialize a breaks array to Firestore maps — public so the datasource can
  /// write just the `breaks` field on a break start/end without a full record.
  static List<Map<String, dynamic>> breaksToList(List<AttendanceBreak> items) =>
      [
        for (final b in items)
          {
            'start': Timestamp.fromDate(b.start),
            'end': b.end == null ? null : Timestamp.fromDate(b.end!),
          },
      ];

  // ─── Embedded location ────────────────────────────────────────────────
  static AttendanceLocation? _locationFromMap(dynamic raw) {
    if (raw is! Map) return null;
    final lat = (raw['latitude'] as num?)?.toDouble();
    final lng = (raw['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return AttendanceLocation(
      latitude: lat,
      longitude: lng,
      accuracyMeters: (raw['accuracyMeters'] as num?)?.toDouble(),
      capturedAt: (raw['capturedAt'] as Timestamp?)?.toDate(),
    );
  }

  static Map<String, dynamic>? _locationToMap(AttendanceLocation? loc) {
    if (loc == null) return null;
    return {
      'latitude': loc.latitude,
      'longitude': loc.longitude,
      'accuracyMeters': loc.accuracyMeters,
      'capturedAt': loc.capturedAt == null ? null : Timestamp.fromDate(loc.capturedAt!),
    };
  }

  // ─── Embedded GPS verification (Phase 3) ──────────────────────────────
  static Map<String, dynamic>? verificationToMap(AttendanceVerification? v) {
    if (v == null) return null;
    return {
      'location': _locationToMap(v.location),
      'distanceMeters': v.distanceMeters,
      'radiusMeters': v.radiusMeters,
      'minAccuracyMeters': v.minAccuracyMeters,
      'withinRadius': v.withinRadius,
      'accuracyOk': v.accuracyOk,
      'verified': v.verified, // denormalized for cheap board queries/filters
    };
  }

  static AttendanceVerification? _verificationFromMap(dynamic raw) {
    if (raw is! Map) return null;
    final loc = _locationFromMap(raw['location']);
    if (loc == null) return null;
    return AttendanceVerification(
      location: loc,
      distanceMeters: (raw['distanceMeters'] as num?)?.toDouble() ?? 0,
      radiusMeters: (raw['radiusMeters'] as num?)?.toDouble() ?? 0,
      minAccuracyMeters: (raw['minAccuracyMeters'] as num?)?.toDouble() ?? 0,
      withinRadius: raw['withinRadius'] as bool? ?? false,
      accuracyOk: raw['accuracyOk'] as bool? ?? false,
    );
  }

  // ─── Audit events (`attendance/{id}/events/{id}`) ─────────────────────
  /// The event payload for a client `add`. `createdAt` is written as a server
  /// timestamp by the datasource. Any [DateTime] inside [data] is normalized to
  /// a [Timestamp] at this boundary.
  static Map<String, dynamic> eventToMap(AttendanceEvent e) => {
        'kind': e.kind.value,
        'actorId': e.actorId,
        'actorName': e.actorName,
        'note': e.note,
        'data': _dataToMap(e.data),
      };

  static AttendanceEvent eventFromMap(Map<String, dynamic> map, {String? id}) =>
      AttendanceEvent(
        id: id ?? map['id'] as String? ?? '',
        kind: AttendanceEventKind.fromString(map['kind'] as String?),
        actorId: map['actorId'] as String? ?? '',
        actorName: map['actorName'] as String?,
        note: map['note'] as String?,
        data: _dataFromMap(map['data']),
        createdAt: map.date('createdAt') ?? DateTime.now(),
      );

  static Map<String, dynamic> _dataFromMap(dynamic raw) {
    if (raw is! Map) return const {};
    final out = <String, dynamic>{};
    raw.forEach((k, v) => out[k.toString()] = v is Timestamp ? v.toDate() : v);
    return out;
  }

  static Map<String, dynamic> _dataToMap(Map<String, dynamic> data) {
    final out = <String, dynamic>{};
    data.forEach((k, v) => out[k] = v is DateTime ? Timestamp.fromDate(v) : v);
    return out;
  }

  static Timestamp? _ts(DateTime? d) => d == null ? null : Timestamp.fromDate(d);
}
