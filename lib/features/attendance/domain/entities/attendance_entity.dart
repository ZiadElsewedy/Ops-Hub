import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:opshub/core/enums/attendance_source.dart';
import 'package:opshub/core/enums/attendance_status.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/attendance/domain/attendance_break.dart';
import 'package:opshub/features/attendance/domain/attendance_gps.dart';
import 'package:opshub/features/attendance/domain/attendance_id.dart';

part 'attendance_entity.freezed.dart';

/// One employee's attendance for **one shift on one day** — the record behind a
/// clock-in/out. Stored at `attendance/{uid}_{yyyyMMdd}_{shift}` (a deterministic
/// id — see [attendanceDocId] — which is what makes clock-in idempotent and
/// offline-safe). The append-only audit trail lives in the `events` subcollection
/// (`AttendanceEvent`).
///
/// The five minute totals ([workedMinutes] … [breakMinutes]) are a **snapshot**
/// written at clock-out / auto-close by `AttendanceCalculator` (the single source
/// of that math), so reports and the admin dashboard aggregate plain numbers
/// without re-deriving per document. While a session is in progress the live
/// timer recomputes them from the calculator against `now` instead of reading the
/// stale snapshot.
///
/// Lateness / early-leave / overtime are **derived** ([isLate] / [hasEarlyLeave]
/// / [hasOvertime]) from those minute fields — they are deliberately not extra
/// statuses (see [AttendanceStatus]).
@freezed
class AttendanceEntity with _$AttendanceEntity {
  const AttendanceEntity._();

  const factory AttendanceEntity({
    /// Deterministic id `{uid}_{yyyyMMdd}_{shift}` (see [attendanceDocId]).
    required String id,
    required String userId,

    /// Denormalized for list/board rows (avoids a user fetch per row).
    String? userName,
    String? branchId,

    /// Which rostered slot this record is for.
    required ScheduleShift shift,

    /// The calendar day of the shift (local midnight). Pairs with [dayKey].
    required DateTime date,

    /// The scheduled start / end **instants**, snapshotted at clock-in from the
    /// resolved `ShiftHours` so history stays stable even if the roster is later
    /// edited. Null for an unscheduled clock-in, and always null when
    /// [presenceOnly].
    DateTime? scheduledStart,
    DateTime? scheduledEnd,

    /// **Presence tracking, by policy** — this record is not measured against a
    /// roster at all. Set for managers, whose attendance answers "were they
    /// here" rather than "did they work their shift": worked minutes run
    /// clock-in → clock-out, and late / early-leave / overtime are meaningless
    /// and stay 0.
    ///
    /// This exists because a missing [scheduledStart] alone is ambiguous. It
    /// otherwise reads as `unscheduledWork` — an **exception**, meaning someone
    /// worked a shift nobody rostered — which reporting excludes from
    /// present/absent counts. Without this flag every manager day would be
    /// filed as an anomaly and managers would vanish from attendance stats.
    @Default(false) bool presenceOnly,
    DateTime? clockIn,
    DateTime? clockOut,

    /// Breaks taken this shift. **Dormant internal extension point** — the MVP has
    /// no break flow (no clock UI, use case, or write path), so this stays empty
    /// and the calculator nets 0; the field + [AttendanceBreak] value object are
    /// kept so break support can return without a migration. Not exposed.
    @Default(<AttendanceBreak>[]) List<AttendanceBreak> breaks,
    @Default(AttendanceStatus.inProgress) AttendanceStatus status,

    // ── Snapshot totals (written at clock-out / auto-close) ──
    @Default(0) int workedMinutes,
    @Default(0) int lateMinutes,
    @Default(0) int earlyLeaveMinutes,
    @Default(0) int overtimeMinutes,
    @Default(0) int breakMinutes,

    /// The GPS verification captured **at clock-in** — the device location, its
    /// distance from the branch, the accuracy, and whether it passed the branch
    /// geofence. Null on a record created without a fix (shouldn't happen once
    /// GPS is required, but stays null-safe for legacy/manual records).
    AttendanceVerification? clockInVerification,

    /// The GPS verification captured **at clock-out** (stored separately from
    /// [clockInVerification]).
    AttendanceVerification? clockOutVerification,

    /// Optional clock-in selfie (Storage URL). Dormant extension point for future
    /// face verification — stored, never analysed here.
    String? photoUrl,
    String? deviceId,
    String? notes,
    @Default(AttendanceSource.clock) AttendanceSource source,

    // ── Resolution (who closed out a pendingReview record, via a correction or
    //    a manager edit). NOT an "approval" of the record — approve/reject is a
    //    property of the Attendance Correction Request, never of attendance
    //    itself. These are denormalized stamps for the card + audit.
    String? resolvedBy,
    String? resolvedByName,
    DateTime? resolvedAt,

    /// Additive version tag so the shape can evolve without a migration.
    @Default(1) int schemaVersion,
    DateTime? createdAt,
    DateTime? updatedAt,

    /// Soft delete (admin) — the record stays as history, lists filter it out.
    DateTime? deletedAt,
  }) = _AttendanceEntity;

  /// The `yyyyMMdd` day key (also persisted, for the branch/day query).
  String get dayKey => attendanceDayKey(date);

  bool get isDeleted => deletedAt != null;
  bool get hasClockedIn => clockIn != null;
  bool get hasClockedOut => clockOut != null;

  /// A live, running session (clocked in, not out).
  bool get isOpen => hasClockedIn && !hasClockedOut;

  // ── Derived facts (from the snapshot minute fields) ──
  bool get isLate => lateMinutes > 0;
  bool get hasEarlyLeave => earlyLeaveMinutes > 0;
  bool get hasOvertime => overtimeMinutes > 0;

  bool get isPresent => status.isPresent;
  bool get needsReview => status.needsReview;
  bool get isExcused => status == AttendanceStatus.excused;

  /// True when this record was created without a rostered shift (the scheduled
  /// window is unknown) — surfaces an "unscheduled" hint.
  ///
  /// A [presenceOnly] record is **not** unscheduled: it has no schedule by
  /// policy, not by accident, so it is never an anomaly to explain.
  bool get isUnscheduled => scheduledStart == null && !presenceOnly;

  // ── GPS verification (Phase 3) ──
  bool get isClockInVerified => clockInVerification?.verified ?? false;
  bool get isClockOutVerified => clockOutVerification?.verified ?? false;

  /// The clock-in instant for the live timer. [clockIn] is written as a **server
  /// timestamp**, so it reads back null from the offline cache until the write
  /// syncs; until then the GPS capture time (device clock, ≈ the clock instant)
  /// stands in so the "Working" timer never shows nothing.
  DateTime? get effectiveClockIn =>
      clockIn ?? clockInVerification?.location.capturedAt;
}
