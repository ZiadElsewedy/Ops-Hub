import 'package:drop/core/enums/attendance_location_policy.dart';

/// The tunable rules of the attendance module — grace windows, clock-in window,
/// overtime + auto-close thresholds, and the (default-off) GPS / photo policies.
/// Pure + immutable.
///
/// Today this is a single set of sensible [defaults]; the type exists so those
/// rules become **branch-configurable data later without a refactor** (a future
/// `branches/{id}/attendanceConfig` doc parsed into this object). The validation
/// engine, the calculator and the Cloud Functions all read their thresholds
/// from here — no magic numbers scattered across the code.
///
/// [enabled] is the module's **dark switch**: while false the attendance surface
/// is inert and the task-start guard is a no-op, so shipping the module never
/// regresses an existing branch until it's deliberately turned on.
class AttendanceConfig {
  /// Master switch — the module is dark (no clock UI, no task gating) until a
  /// branch opts in. Default false.
  final bool enabled;

  /// Clocking in up to this many minutes late is **not** counted as lateness
  /// (absorbs a couple of minutes of clock skew / walking to the terminal).
  final int lateGraceMinutes;

  /// Leaving up to this many minutes before the scheduled end is **not** counted
  /// as an early leave.
  final int earlyLeaveGraceMinutes;

  /// How early (before the scheduled start) the employee may clock in. Before
  /// `scheduledStart − lead` a clock-in is refused ("Opens at HH:MM") — use a
  /// missed-punch request instead. Enforced by `AttendanceValidation.checkClockIn`
  /// (spec R1). Early presence never counts as worked time (spec R2 — the
  /// calculator measures work from `max(clockIn, scheduledStart)`).
  final int clockInLeadMinutes;

  /// Extra minutes past the scheduled end that must be worked before the excess
  /// counts as overtime (so finishing a couple of minutes over isn't overtime).
  final int overtimeGraceMinutes;

  /// How long after the scheduled end a still-open session is left before the
  /// `autoCloseAttendance` function closes it to `pendingReview`.
  final int autoCloseGraceMinutes;

  /// The absolute maximum a session may stay open, measured from clock-in — the
  /// **safety net** (spec R7) that closes a session which has no scheduled end (an
  /// unscheduled clock-in) or one running pathologically long. Default 16h. Read
  /// by the `autoCloseAttendance` sweep (mirrored server-side); no magic numbers.
  final int maxSessionMinutes;

  /// The geofence policy for a branch **that has a geofence**.
  ///
  /// Defaults to [AttendanceLocationPolicy.strict] because that is what the
  /// product actually ships and what `ATTENDANCE_SPEC` workflow 6 describes; the
  /// old [AttendanceLocationPolicy.none] default was a leftover from when GPS was
  /// planned as opt-in, and it never matched behaviour because nothing read it.
  ///
  /// Never read raw — a branch with no geofence resolves to
  /// [AttendanceLocationPolicy.none] via `AttendanceService.resolveLocationPolicy`
  /// (ADR-020).
  final AttendanceLocationPolicy locationPolicy;

  /// Whether a selfie is required to clock in (default false — optional).
  final bool requirePhoto;

  /// Whether an employee with **no rostered shift today** may still clock in.
  ///
  /// **Default true since [ADR-018].** A blocked punch does not prevent the
  /// work, it prevents the record — and the workaround (a manager typing the
  /// times in afterwards) is strictly worse evidence than a live, GPS-verified,
  /// server-timestamped punch. The flag survives so a branch can choose the
  /// stricter behaviour; the product's default is permissive.
  ///
  /// Permissive at *capture* only: an unscheduled shift counts in nothing until
  /// a manager approves it in Daily Review.
  final bool allowUnscheduledClockIn;

  const AttendanceConfig({
    this.enabled = false,
    this.lateGraceMinutes = 5,
    this.earlyLeaveGraceMinutes = 5,
    this.clockInLeadMinutes = 15,
    this.overtimeGraceMinutes = 15,
    this.autoCloseGraceMinutes = 120,
    this.maxSessionMinutes = 16 * 60,
    this.locationPolicy = AttendanceLocationPolicy.strict,
    this.requirePhoto = false,
    this.allowUnscheduledClockIn = true,
  });

  /// The standing defaults. `enabled` stays false here — a branch turns the
  /// module on explicitly (see the module dark-switch note above).
  static const AttendanceConfig defaults = AttendanceConfig();

  AttendanceConfig copyWith({
    bool? enabled,
    int? lateGraceMinutes,
    int? earlyLeaveGraceMinutes,
    int? clockInLeadMinutes,
    int? overtimeGraceMinutes,
    int? autoCloseGraceMinutes,
    int? maxSessionMinutes,
    AttendanceLocationPolicy? locationPolicy,
    bool? requirePhoto,
    bool? allowUnscheduledClockIn,
  }) =>
      AttendanceConfig(
        enabled: enabled ?? this.enabled,
        lateGraceMinutes: lateGraceMinutes ?? this.lateGraceMinutes,
        earlyLeaveGraceMinutes:
            earlyLeaveGraceMinutes ?? this.earlyLeaveGraceMinutes,
        clockInLeadMinutes: clockInLeadMinutes ?? this.clockInLeadMinutes,
        overtimeGraceMinutes: overtimeGraceMinutes ?? this.overtimeGraceMinutes,
        autoCloseGraceMinutes:
            autoCloseGraceMinutes ?? this.autoCloseGraceMinutes,
        maxSessionMinutes: maxSessionMinutes ?? this.maxSessionMinutes,
        locationPolicy: locationPolicy ?? this.locationPolicy,
        requirePhoto: requirePhoto ?? this.requirePhoto,
        allowUnscheduledClockIn:
            allowUnscheduledClockIn ?? this.allowUnscheduledClockIn,
      );
}
