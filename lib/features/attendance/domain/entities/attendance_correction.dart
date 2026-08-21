import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:opshub/core/enums/attendance_correction_kind.dart';
import 'package:opshub/core/enums/attendance_status.dart';
import 'package:opshub/core/enums/request_status.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/attendance/domain/attendance_resolution.dart';

part 'attendance_correction.freezed.dart';

/// An **attendance correction request** — the one honest way a *settled* record
/// changes. An employee disputes/fixes their own record (a missing clock-out, a
/// wrong time, an absence recorded in error); a manager/admin approves or rejects.
/// Stored at `attendance_corrections/{id}` (auto id).
///
/// It is a first-class approval object with a `Pending → Approved / Rejected`
/// lifecycle, reusing [RequestStatus] so corrections and operations requests
/// share one decision vocabulary. It deliberately mirrors the `requests/` slice.
///
/// **Server-authoritative apply:** the client only writes this doc (file a
/// correction; a reviewer stamps the decision). On approval the
/// `onAttendanceCorrectionWritten` Cloud Function copies [resolution] onto the
/// parent `attendance/{attendanceId}` record and appends the immutable
/// `correctionApproved` audit event — clients never touch the record or the audit
/// trail directly. The [resolution] itself is computed once, on approval, by
/// `DecideCorrection` through `AttendanceCalculator` (the single source of the
/// minute math), so nothing is recomputed server-side.
@freezed
class AttendanceCorrectionEntity with _$AttendanceCorrectionEntity {
  const AttendanceCorrectionEntity._();

  const factory AttendanceCorrectionEntity({
    required String id,

    /// The parent record's deterministic id (`{uid}_{yyyyMMdd}_{shift}`).
    required String attendanceId,

    /// Whose attendance this is (== [requestedBy] — the filer is the record's
    /// own employee; enforced by the create rule).
    required String userId,
    String? userName,
    String? branchId,

    /// Denormalized for the reviewer's queue row (avoids a record fetch per row).
    ScheduleShift? shift,
    DateTime? date,
    required String requestedBy,
    String? requestedByName,
    required AttendanceCorrectionKind kind,
    @Default(RequestStatus.pending) RequestStatus status,

    /// Why the record is wrong (the employee's explanation) — always required.
    required String reason,

    /// The scheduled window this correction is measured against. On a correction
    /// to an **existing** record these are redundant (the record already has
    /// them). On a **missed-punch** materialization (no record yet) they carry the
    /// rostered window so the applied record has a scheduled reference for
    /// lateness and the board — null for a genuinely unscheduled shift.
    DateTime? scheduledStart,
    DateTime? scheduledEnd,

    // ── The proposed fix (what the employee is asking for) ──
    DateTime? proposedClockIn,
    DateTime? proposedClockOut,

    /// An optional target lifecycle (e.g. an absence dispute → `completed`).
    AttendanceStatus? proposedStatus,

    /// The applied result, set by `DecideCorrection` on approval and copied onto
    /// the record by the Cloud Function. Null until approved.
    AttendanceResolution? resolution,

    // ── Decision stamps ──
    String? decidedBy,
    String? decidedByName,
    DateTime? decidedAt,
    String? decisionNote,
    DateTime? createdAt,
    DateTime? updatedAt,

    /// Admin soft-delete — the correction stays as history, lists filter it out.
    DateTime? deletedAt,
  }) = _AttendanceCorrectionEntity;

  bool get isPending => status.isPending;
  bool get isApproved => status.isApproved;
  bool get isRejected => status.isRejected;
  bool get isDecided => status.isTerminal;
  bool get isDeleted => deletedAt != null;
}
