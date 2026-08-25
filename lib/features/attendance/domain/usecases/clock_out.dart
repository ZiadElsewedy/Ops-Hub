import 'package:opshub/core/enums/attendance_status.dart';
import 'package:opshub/features/attendance/domain/attendance_calculator.dart';
import 'package:opshub/features/attendance/domain/attendance_config.dart';
import 'package:opshub/features/attendance/domain/attendance_gps.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_entity.dart';
import 'package:opshub/features/attendance/domain/repositories/attendance_repository.dart';

/// Clocks out — sets the clock-out time + status on the record. The worked /
/// late / early / overtime minute snapshot is **not** persisted from here: those
/// feed payroll, so they are recomputed server-side by `onAttendanceWritten` with
/// the Admin SDK, and the client is forbidden by rules from writing them
/// (ADR-024). The totals are still computed here — with the same
/// [AttendanceCalculator] the server mirrors — and returned for immediate UI
/// feedback, so the screen never waits for the server round-trip.
class ClockOut {
  final AttendanceRepository _repository;
  const ClockOut(this._repository);

  Future<AttendanceTotals> call(
    AttendanceEntity record, {
    required DateTime now,
    AttendanceConfig config = AttendanceConfig.defaults,
    AttendanceVerification? verification,
  }) async {
    final totals = AttendanceCalculator.compute(
      scheduledStart: record.scheduledStart,
      scheduledEnd: record.scheduledEnd,
      // The clock-in read back from the server timestamp; the GPS capture time
      // stands in if it hasn't synced yet, so worked-minutes are never computed
      // against a null start.
      clockIn: record.effectiveClockIn,
      clockOut: now,
      breaks: record.breaks,
      now: now,
      config: config,
    );
    await _repository.clockOut(
      record.id,
      clockOut: now,
      status: AttendanceStatus.completed,
      totals: totals,
      verification: verification,
    );
    return totals;
  }
}
