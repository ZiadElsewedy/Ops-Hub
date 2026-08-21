import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:opshub/core/enums/attendance_correction_kind.dart';
import 'package:opshub/core/enums/attendance_status.dart';
import 'package:opshub/core/enums/request_status.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/extensions/firestore_extensions.dart';
import 'package:opshub/features/attendance/domain/attendance_resolution.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_correction.dart';

/// Firestore (de)serialization for [AttendanceCorrectionEntity] — collection
/// `attendance_corrections/{id}` (auto id). Server-managed timestamps
/// (`createdAt`/`updatedAt`) are written by the datasource, so [toCreateMap] (the
/// filing payload) omits them. The applied [AttendanceResolution] is serialized
/// inline as a nested `resolution` map (mirrors how `AttendanceModel` embeds
/// breaks/location), so the `onAttendanceCorrectionWritten` Cloud Function reads
/// it verbatim to update the parent record.
class AttendanceCorrectionModel {
  final String id;
  final String attendanceId;
  final String userId;
  final String? userName;
  final String? branchId;
  final ScheduleShift? shift;
  final DateTime? date;
  final String requestedBy;
  final String? requestedByName;
  final AttendanceCorrectionKind kind;
  final RequestStatus status;
  final String reason;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final DateTime? proposedClockIn;
  final DateTime? proposedClockOut;
  final AttendanceStatus? proposedStatus;
  final AttendanceResolution? resolution;
  final String? decidedBy;
  final String? decidedByName;
  final DateTime? decidedAt;
  final String? decisionNote;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const AttendanceCorrectionModel({
    required this.id,
    required this.attendanceId,
    required this.userId,
    this.userName,
    this.branchId,
    this.shift,
    this.date,
    required this.requestedBy,
    this.requestedByName,
    required this.kind,
    this.status = RequestStatus.pending,
    required this.reason,
    this.scheduledStart,
    this.scheduledEnd,
    this.proposedClockIn,
    this.proposedClockOut,
    this.proposedStatus,
    this.resolution,
    this.decidedBy,
    this.decidedByName,
    this.decidedAt,
    this.decisionNote,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory AttendanceCorrectionModel.fromMap(Map<String, dynamic> map,
          {String? id}) =>
      AttendanceCorrectionModel(
        id: id ?? map['id'] as String? ?? '',
        attendanceId: map['attendanceId'] as String? ?? '',
        userId: map['userId'] as String? ?? '',
        userName: map['userName'] as String?,
        branchId: map['branchId'] as String?,
        shift: map['shift'] == null
            ? null
            : ScheduleShift.fromString(map['shift'] as String?),
        date: map.date('date'),
        requestedBy: map['requestedBy'] as String? ?? '',
        requestedByName: map['requestedByName'] as String?,
        kind: AttendanceCorrectionKind.fromString(map['kind'] as String?),
        status: RequestStatus.fromString(map['status'] as String?),
        reason: map['reason'] as String? ?? '',
        scheduledStart: map.date('scheduledStart'),
        scheduledEnd: map.date('scheduledEnd'),
        proposedClockIn: map.date('proposedClockIn'),
        proposedClockOut: map.date('proposedClockOut'),
        proposedStatus: map['proposedStatus'] == null
            ? null
            : AttendanceStatus.fromString(map['proposedStatus'] as String?),
        resolution: _resolutionFromMap(map['resolution']),
        decidedBy: map['decidedBy'] as String?,
        decidedByName: map['decidedByName'] as String?,
        decidedAt: map.date('decidedAt'),
        decisionNote: map['decisionNote'] as String?,
        createdAt: map.date('createdAt'),
        updatedAt: map.date('updatedAt'),
        deletedAt: map.date('deletedAt'),
      );

  factory AttendanceCorrectionModel.fromEntity(
          AttendanceCorrectionEntity e) =>
      AttendanceCorrectionModel(
        id: e.id,
        attendanceId: e.attendanceId,
        userId: e.userId,
        userName: e.userName,
        branchId: e.branchId,
        shift: e.shift,
        date: e.date,
        requestedBy: e.requestedBy,
        requestedByName: e.requestedByName,
        kind: e.kind,
        status: e.status,
        reason: e.reason,
        scheduledStart: e.scheduledStart,
        scheduledEnd: e.scheduledEnd,
        proposedClockIn: e.proposedClockIn,
        proposedClockOut: e.proposedClockOut,
        proposedStatus: e.proposedStatus,
        resolution: e.resolution,
        decidedBy: e.decidedBy,
        decidedByName: e.decidedByName,
        decidedAt: e.decidedAt,
        decisionNote: e.decisionNote,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
        deletedAt: e.deletedAt,
      );

  AttendanceCorrectionEntity toEntity() => AttendanceCorrectionEntity(
        id: id,
        attendanceId: attendanceId,
        userId: userId,
        userName: userName,
        branchId: branchId,
        shift: shift,
        date: date,
        requestedBy: requestedBy,
        requestedByName: requestedByName,
        kind: kind,
        status: status,
        reason: reason,
        scheduledStart: scheduledStart,
        scheduledEnd: scheduledEnd,
        proposedClockIn: proposedClockIn,
        proposedClockOut: proposedClockOut,
        proposedStatus: proposedStatus,
        resolution: resolution,
        decidedBy: decidedBy,
        decidedByName: decidedByName,
        decidedAt: decidedAt,
        decisionNote: decisionNote,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
      );

  /// The **filing payload** (status `pending`). Server timestamps
  /// (`createdAt`/`updatedAt`) are added by the datasource; the decision fields
  /// (`resolution`/`decided*`) are absent until a reviewer decides.
  Map<String, dynamic> toCreateMap() => {
        'id': id,
        'attendanceId': attendanceId,
        'userId': userId,
        'userName': userName,
        'branchId': branchId,
        'shift': shift?.value,
        'date': _ts(date),
        'requestedBy': requestedBy,
        'requestedByName': requestedByName,
        'kind': kind.value,
        'status': RequestStatus.pending.value,
        'reason': reason,
        'scheduledStart': _ts(scheduledStart),
        'scheduledEnd': _ts(scheduledEnd),
        'proposedClockIn': _ts(proposedClockIn),
        'proposedClockOut': _ts(proposedClockOut),
        'proposedStatus': proposedStatus?.value,
      };

  /// The **manager direct-action payload** — a correction born already
  /// `approved`, carrying the [resolution] + decision stamps, for *Add record* /
  /// *Resolve* (spec R11). The Cloud Function's create branch applies it to the
  /// record immediately (no reviewer step). `decidedAt`/`createdAt`/`updatedAt`
  /// are stamped as server timestamps by the datasource.
  Map<String, dynamic> toResolvedCreateMap() => {
        'id': id,
        'attendanceId': attendanceId,
        'userId': userId,
        'userName': userName,
        'branchId': branchId,
        'shift': shift?.value,
        'date': _ts(date),
        'requestedBy': requestedBy,
        'requestedByName': requestedByName,
        'kind': kind.value,
        'status': RequestStatus.approved.value,
        'reason': reason,
        'scheduledStart': _ts(scheduledStart),
        'scheduledEnd': _ts(scheduledEnd),
        'proposedClockIn': _ts(proposedClockIn),
        'proposedClockOut': _ts(proposedClockOut),
        'proposedStatus': proposedStatus?.value,
        'resolution': resolutionToMap(resolution),
        'decidedBy': decidedBy,
        'decidedByName': decidedByName,
        'decisionNote': decisionNote,
      };

  // ─── Embedded resolution (the applied snapshot) ───────────────────────
  static Map<String, dynamic>? resolutionToMap(AttendanceResolution? r) {
    if (r == null) return null;
    return {
      'clockIn': _ts(r.clockIn),
      'clockOut': _ts(r.clockOut),
      'status': r.status.value,
      'workedMinutes': r.workedMinutes,
      'lateMinutes': r.lateMinutes,
      'earlyLeaveMinutes': r.earlyLeaveMinutes,
      'overtimeMinutes': r.overtimeMinutes,
      'breakMinutes': r.breakMinutes,
    };
  }

  static AttendanceResolution? _resolutionFromMap(dynamic raw) {
    if (raw is! Map) return null;
    return AttendanceResolution(
      clockIn: (raw['clockIn'] as Timestamp?)?.toDate(),
      clockOut: (raw['clockOut'] as Timestamp?)?.toDate(),
      status: AttendanceStatus.fromString(raw['status'] as String?),
      workedMinutes: (raw['workedMinutes'] as num?)?.toInt() ?? 0,
      lateMinutes: (raw['lateMinutes'] as num?)?.toInt() ?? 0,
      earlyLeaveMinutes: (raw['earlyLeaveMinutes'] as num?)?.toInt() ?? 0,
      overtimeMinutes: (raw['overtimeMinutes'] as num?)?.toInt() ?? 0,
      breakMinutes: (raw['breakMinutes'] as num?)?.toInt() ?? 0,
    );
  }

  static Timestamp? _ts(DateTime? d) => d == null ? null : Timestamp.fromDate(d);
}
