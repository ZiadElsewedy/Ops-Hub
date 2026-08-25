import 'package:opshub/core/enums/attendance_status.dart';
import 'package:opshub/core/enums/request_status.dart';
import 'package:opshub/features/attendance/domain/attendance_config.dart';
import 'package:opshub/features/attendance/domain/attendance_resolution.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_correction.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_entity.dart';
import 'package:opshub/features/attendance/domain/repositories/attendance_repository.dart';

/// A reviewer (manager/admin) approves or rejects a correction.
///
/// On **approve** this is the one place the corrected minute snapshot is
/// computed — through [AttendanceCalculator], the single source of that math, so
/// a corrected record's totals can never drift from the clock-out path. The
/// settled times come from the proposal (falling back to the record's existing
/// values), and the result is packaged as an [AttendanceResolution] stored on the
/// correction. The `onAttendanceCorrectionWritten` Cloud Function then copies that
/// resolution onto `attendance/{attendanceId}` and appends the immutable audit
/// event — the client never touches the record or the audit trail.
///
/// On **reject** no resolution is written and the record is left untouched.
class DecideCorrection {
  final AttendanceRepository _repository;
  const DecideCorrection(this._repository);

  Future<AttendanceResolution?> call(
    AttendanceCorrectionEntity correction, {
    required AttendanceEntity record,
    required bool approve,
    required String decidedBy,
    String? decidedByName,
    String? decisionNote,
    required DateTime now,
    AttendanceConfig config = AttendanceConfig.defaults,
  }) async {
    if (!approve) {
      await _repository.decideCorrection(
        correction.id,
        status: RequestStatus.rejected,
        decidedBy: decidedBy,
        decidedByName: decidedByName,
        decisionNote: decisionNote,
      );
      return null;
    }

    // The scheduled window comes from the record when it exists, else from the
    // correction (a missed-punch materializes a record that never existed).
    final resolution = AttendanceResolution.fromRecord(
      scheduledStart: record.scheduledStart ?? correction.scheduledStart,
      scheduledEnd: record.scheduledEnd ?? correction.scheduledEnd,
      clockIn: correction.proposedClockIn ?? record.clockIn,
      clockOut: correction.proposedClockOut ?? record.clockOut,
      status: correction.proposedStatus ?? AttendanceStatus.completed,
      breaks: record.breaks,
      now: now,
      config: config,
    );
    await _repository.decideCorrection(
      correction.id,
      status: RequestStatus.approved,
      decidedBy: decidedBy,
      decidedByName: decidedByName,
      decisionNote: decisionNote,
      resolution: resolution,
    );
    return resolution;
  }
}
