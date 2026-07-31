/// What actually happened to a manager's direct attendance write.
///
/// A manager action does **not** change the attendance record directly. The
/// client writes an already-approved correction, and a Cloud Function
/// (`onAttendanceCorrectionWritten`) applies it onto the record and writes the
/// audit event — `ATTENDANCE_SPEC` T3/T4.
///
/// So "the write succeeded" and "the shift was settled" are two different
/// facts, and until the Functions deploy lands they are routinely different:
/// the correction document is created, the record never moves. Reporting
/// success on the first fact told a manager their absence was excused when the
/// person was still marked absent — the most damaging thing an attendance
/// screen can do, because the manager stops looking.
///
/// [awaitingBackend] is not an error. Nothing is lost: the correction is
/// durable and the Function applies it the moment it is deployed.
enum AttendanceWriteOutcome {
  /// The record now carries the correction. Confirmed by re-reading it.
  applied,

  /// The correction was saved, but the record has not changed yet — the server
  /// side that applies it is not running.
  awaitingBackend,

  /// Nothing was written. The cubit has already emitted the reason.
  failed;

  /// Whether anything was persisted at all.
  bool get isWritten => this != AttendanceWriteOutcome.failed;
}
