import 'package:drop/core/enums/attendance_location_policy.dart';
import 'package:drop/core/enums/attendance_status.dart';
import 'package:drop/core/enums/leave_type.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/features/attendance/domain/attendance_config.dart';
import 'package:drop/features/attendance/domain/attendance_gps.dart';
import 'package:drop/features/attendance/domain/attendance_location_service.dart';
import 'package:drop/features/attendance/domain/entities/attendance_entity.dart';

/// Why a clock action can't proceed. [none] means "allowed". Each carries a
/// user-facing [message]; the enum value gives the UI a stable code to key on.
enum AttendanceBlock {
  none,
  notEnabled,
  userDisabled,
  noActiveShift,
  onLeave,
  alreadyClockedIn,
  alreadyClockedOut,
  notClockedIn,
  tooEarly,
  // ── GPS verification (clock-in gate) ──
  serviceDisabled,
  permissionDenied,
  locationUnavailable,
  noGeofence,
  lowAccuracy,
  outsideRadius,
  // ── Correction requests ──
  emptyReason,
  invalidTimes,
  sessionOpen,
  recordMissing,
  duplicateOpen,
  missingStartTime;

  bool get isBlocked => this != AttendanceBlock.none;
}

/// The outcome of a validation check — [allowed] plus a human [message] when
/// blocked. Mirrors the "return a reason" shape of `MoveValidation`, but typed so
/// callers (cubit + UI + tests) can branch on the [reason] code, not a string.
class AttendanceCheck {
  final AttendanceBlock reason;
  final String message;

  const AttendanceCheck(this.reason, [this.message = '']);

  static const AttendanceCheck ok = AttendanceCheck(AttendanceBlock.none);

  bool get allowed => reason == AttendanceBlock.none;
  bool get blocked => !allowed;
}

/// The pure, reusable **validation engine** for attendance clock actions. No
/// Flutter, no Firestore — every input is passed in (the caller resolves the
/// roster / user / existing record), so each rule is independently unit-testable.
/// This is the single place clock rules live; the cubit and the UI both consult
/// it rather than re-deriving.
class AttendanceValidation {
  AttendanceValidation._();

  /// The **eligibility** gate for a clock-in — everything that doesn't need a GPS
  /// fix, checked first so the app never asks for location when the person can't
  /// clock in anyway. Order: module enabled → user active → not on leave → has a
  /// shift → not already in/out for this shift → **inside the clock-in window**.
  /// The GPS gate ([checkGpsFix]) runs after this passes.
  ///
  /// The window (spec R1): a rostered clock-in is refused before
  /// `scheduledStart − config.clockInLeadMinutes` — [now] and [scheduledStart]
  /// drive it. When either is null (unscheduled shift, or the caller doesn't pass
  /// a clock), no window is enforced. Early presence still never counts as worked
  /// time — that clamp lives in `AttendanceCalculator` (spec R2).
  static AttendanceCheck checkClockIn({
    required bool userActive,
    required ScheduleShift? todaysShift,
    required LeaveType? leave,
    required AttendanceEntity? existing,
    DateTime? now,
    DateTime? scheduledStart,
    AttendanceConfig config = AttendanceConfig.defaults,
  }) {
    if (!config.enabled) {
      return const AttendanceCheck(
          AttendanceBlock.notEnabled, 'Attendance isn\'t enabled here.');
    }
    if (!userActive) {
      return const AttendanceCheck(
          AttendanceBlock.userDisabled, 'Your account is inactive.');
    }
    if (leave != null) {
      return AttendanceCheck(
          AttendanceBlock.onLeave, 'You\'re on ${leave.label.toLowerCase()} today.');
    }
    if (todaysShift == null && !config.allowUnscheduledClockIn) {
      return const AttendanceCheck(
          AttendanceBlock.noActiveShift, 'You have no shift scheduled today.');
    }
    if (existing != null && existing.isOpen) {
      return const AttendanceCheck(
          AttendanceBlock.alreadyClockedIn, 'You\'re already clocked in.');
    }
    if (existing != null && existing.hasClockedOut) {
      return const AttendanceCheck(AttendanceBlock.alreadyClockedOut,
          'You\'ve already completed this shift.');
    }
    if (now != null && scheduledStart != null) {
      final opens =
          scheduledStart.subtract(Duration(minutes: config.clockInLeadMinutes));
      if (now.isBefore(opens)) {
        return AttendanceCheck(AttendanceBlock.tooEarly,
            'Clock-in opens at ${_hhmm(opens)}.');
      }
    }
    return AttendanceCheck.ok;
  }

  /// `HH:MM` (24h, zero-padded) for a user-facing "opens at" message.
  static String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// The **GPS gate** for a clock-in — pure over the acquisition outcome. The
  /// caller (cubit) reads the device location, evaluates it against the branch
  /// geofence into [verification], and passes either a [locationError] (nothing
  /// could be read) or the [verification].
  ///
  /// [policy] is the **effective** policy from
  /// `AttendanceService.resolveLocationPolicy` — already collapsed to
  /// [AttendanceLocationPolicy.none] when the branch has no geofence, so
  /// `geofenceConfigured` is only ever false alongside `none` in practice. It is
  /// still checked, because a `strict` branch whose geofence vanishes mid-session
  /// must fail loudly rather than silently pass.
  ///
  /// * **none** — nothing is captured or checked. Always OK (ADR-020).
  /// * **soft** — capture, record, **never block**. The verification rides on the
  ///   record (possibly unverified) as evidence for review.
  /// * **strict** — the full gate, rejections in order: service off → permission
  ///   denied → couldn't read → branch not geofenced → GPS too inaccurate →
  ///   outside the allowed radius.
  static AttendanceCheck checkGpsFix({
    required LocationError? locationError,
    required AttendanceVerification? verification,
    required bool geofenceConfigured,
    AttendanceLocationPolicy policy = AttendanceLocationPolicy.strict,
  }) {
    // A pure time clock: the punch is never refused for a location reason, and
    // nothing above needed to be read in the first place.
    if (policy == AttendanceLocationPolicy.none) return AttendanceCheck.ok;

    // Warn-only: the location is still captured and stored — that is the whole
    // point of `soft` — but it can never cost someone their punch.
    if (!policy.blocksOutside) return AttendanceCheck.ok;

    if (locationError != null) {
      switch (locationError) {
        case LocationError.serviceDisabled:
          return const AttendanceCheck(AttendanceBlock.serviceDisabled,
              'Turn on location services to clock in.');
        case LocationError.permissionDenied:
          return const AttendanceCheck(AttendanceBlock.permissionDenied,
              'Allow location access to clock in.');
        case LocationError.unavailable:
          return const AttendanceCheck(AttendanceBlock.locationUnavailable,
              'Couldn\'t get your location. Try again in the open.');
      }
    }
    if (!geofenceConfigured) {
      return const AttendanceCheck(AttendanceBlock.noGeofence,
          'This branch isn\'t set up for GPS attendance yet.');
    }
    if (verification == null) {
      return const AttendanceCheck(AttendanceBlock.locationUnavailable,
          'Couldn\'t verify your location. Try again.');
    }
    if (!verification.accuracyOk) {
      return const AttendanceCheck(AttendanceBlock.lowAccuracy,
          'GPS signal is too weak to verify — move to open sky and retry.');
    }
    if (!verification.withinRadius) {
      return const AttendanceCheck(AttendanceBlock.outsideRadius,
          'You\'re too far from the branch to clock in.');
    }
    return AttendanceCheck.ok;
  }

  /// Can [existing] clock **out** now? Needs an open session with no running
  /// break.
  static AttendanceCheck checkClockOut({
    required AttendanceEntity? existing,
    required DateTime now,
    AttendanceConfig config = AttendanceConfig.defaults,
  }) {
    // A disabled module must still let an open session close, or a live shift
    // is stranded until an automated sweep intervenes.
    if (!config.enabled && (existing == null || !existing.isOpen)) {
      return const AttendanceCheck(
          AttendanceBlock.notEnabled, 'Attendance isn\'t enabled here.');
    }
    if (existing == null || !existing.hasClockedIn) {
      return const AttendanceCheck(
          AttendanceBlock.notClockedIn, 'You haven\'t clocked in.');
    }
    if (existing.hasClockedOut) {
      return const AttendanceCheck(
          AttendanceBlock.alreadyClockedOut, 'You\'ve already clocked out.');
    }
    return AttendanceCheck.ok;
  }

  /// Can a correction be filed against [existing]? Two shapes share this gate:
  ///
  ///  * **A settled record** ([existing] non-null) — fixing a wrong time or a
  ///    missing clock-out. Rules: not soft-deleted, not a still-running session
  ///    (clock out first), a non-empty reason, an actual change proposed, and any
  ///    proposed clock-out after the (proposed or recorded) clock-in.
  ///  * **A missed punch** ([existing] null — the shift has no record because the
  ///    employee never clocked in). Rules: a real [proposedClockIn] must be
  ///    supplied (you're asserting when you started), a reason, and a valid
  ///    clock-out. This is the ONLY case a null record is allowed — it
  ///    materializes a record on approval (spec workflow 4). A soft-deleted record
  ///    is still [recordMissing].
  ///
  /// [hasOpenCorrection] enforces **one open correction per record** (spec R15):
  /// while a pending correction already exists for this record, a new one is
  /// blocked. Pure — the cubit/UI both consult it before a write.
  static AttendanceCheck checkCorrection({
    required AttendanceEntity? existing,
    required String reason,
    DateTime? proposedClockIn,
    DateTime? proposedClockOut,
    AttendanceStatus? proposedStatus,
    bool hasOpenCorrection = false,
  }) {
    if (existing != null && existing.isDeleted) {
      return const AttendanceCheck(
          AttendanceBlock.recordMissing, 'There\'s no record to correct yet.');
    }
    if (hasOpenCorrection) {
      return const AttendanceCheck(AttendanceBlock.duplicateOpen,
          'You already have a correction pending for this shift.');
    }
    if (existing == null) {
      // Missed punch — no record exists. The employee must assert a start time.
      if (proposedClockIn == null) {
        return const AttendanceCheck(AttendanceBlock.missingStartTime,
            'Add the time you actually started.');
      }
    } else if (existing.status.isInProgress) {
      // A genuinely-running session is fixed by clocking out, not a correction —
      // but a `pendingReview` record (auto-closed, missing its clock-out) is
      // exactly what corrections are for, so gate on the live status, not `isOpen`.
      return const AttendanceCheck(AttendanceBlock.sessionOpen,
          'Clock out first — this shift is still running.');
    }
    if (reason.trim().isEmpty) {
      return const AttendanceCheck(
          AttendanceBlock.emptyReason, 'Add a reason for the correction.');
    }
    final hasChange = proposedClockIn != null ||
        proposedClockOut != null ||
        proposedStatus != null;
    if (!hasChange) {
      return const AttendanceCheck(AttendanceBlock.invalidTimes,
          'Propose a corrected time or outcome.');
    }
    final start = proposedClockIn ?? existing?.clockIn;
    if (proposedClockOut != null &&
        start != null &&
        !proposedClockOut.isAfter(start)) {
      return const AttendanceCheck(AttendanceBlock.invalidTimes,
          'The clock-out must be after the clock-in.');
    }
    return AttendanceCheck.ok;
  }

  /// The gate for a **manager's direct action** — *Add record* (materialize a
  /// missing/absent shift) or *Resolve* a `pendingReview` record — applied
  /// immediately with audit, no approval loop (spec workflows 12/13, rule R11).
  /// The reviewer's authority is checked server-side (rules); this is the pure
  /// shape check: a mandatory [reason], a real [proposedClockIn] (the manager is
  /// asserting the worked window), a valid clock-out, and no competing open
  /// correction ([hasOpenCorrection] — resolve that one instead of racing it).
  static AttendanceCheck checkManagerEntry({
    required AttendanceEntity? existing,
    required String reason,
    DateTime? proposedClockIn,
    DateTime? proposedClockOut,
    bool hasOpenCorrection = false,
  }) {
    if (existing != null && existing.isDeleted) {
      return const AttendanceCheck(
          AttendanceBlock.recordMissing, 'This record was deleted.');
    }
    if (existing != null && existing.status.isInProgress) {
      return const AttendanceCheck(AttendanceBlock.sessionOpen,
          'This shift is still running — it can\'t be resolved yet.');
    }
    if (hasOpenCorrection) {
      return const AttendanceCheck(AttendanceBlock.duplicateOpen,
          'Decide the pending correction for this shift instead.');
    }
    if (reason.trim().isEmpty) {
      return const AttendanceCheck(
          AttendanceBlock.emptyReason, 'Add a reason for this change.');
    }
    if (proposedClockIn == null) {
      return const AttendanceCheck(AttendanceBlock.missingStartTime,
          'Set the time the employee started.');
    }
    if (proposedClockOut != null && !proposedClockOut.isAfter(proposedClockIn)) {
      return const AttendanceCheck(AttendanceBlock.invalidTimes,
          'The clock-out must be after the clock-in.');
    }
    return AttendanceCheck.ok;
  }

  /// The gate for a manager **excusing** an absence (spec R14) — a forgiven
  /// no-show, materialized with zero worked minutes and no clock times. Unlike
  /// [checkManagerEntry] it needs no start time (there was no work); it only
  /// requires a mandatory [reason], a not-still-running record, and no competing
  /// open correction.
  static AttendanceCheck checkExcuse({
    required AttendanceEntity? existing,
    required String reason,
    bool hasOpenCorrection = false,
  }) {
    if (existing != null && existing.isDeleted) {
      return const AttendanceCheck(
          AttendanceBlock.recordMissing, 'This record was deleted.');
    }
    if (existing != null && existing.status.isInProgress) {
      return const AttendanceCheck(AttendanceBlock.sessionOpen,
          'This shift is still running — it can\'t be excused yet.');
    }
    if (hasOpenCorrection) {
      return const AttendanceCheck(AttendanceBlock.duplicateOpen,
          'Decide the pending correction for this shift instead.');
    }
    if (reason.trim().isEmpty) {
      return const AttendanceCheck(
          AttendanceBlock.emptyReason, 'Add a reason for excusing this shift.');
    }
    return AttendanceCheck.ok;
  }
}
