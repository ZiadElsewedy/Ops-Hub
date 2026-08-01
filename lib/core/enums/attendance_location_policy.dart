/// How strictly a branch validates the **location** of a clock-in — the single
/// knob for the whole geofence behaviour, read by `AttendanceValidation.checkGpsFix`
/// and by the clock UI.
///
/// The **effective** policy is resolved by `AttendanceService.resolveLocationPolicy`,
/// not read raw off the config: [soft] and [strict] both mean "compare the fix to
/// the branch geofence", so neither can mean anything at a branch that has no
/// geofence. There, the policy resolves to [none] (ADR-020).
enum AttendanceLocationPolicy {
  /// No location captured, no geofence check. Clock-in is a pure time action —
  /// what a branch with no geofence configured falls back to.
  none,

  /// Capture the location and **warn** if it's outside the branch geofence, but
  /// never block — the record is flagged, not refused.
  soft,

  /// Capture the location and **block** a clock-in outside the branch geofence.
  strict;

  String get value => name;

  String get label => switch (this) {
        AttendanceLocationPolicy.none => 'Off',
        AttendanceLocationPolicy.soft => 'Warn only',
        AttendanceLocationPolicy.strict => 'Enforced',
      };

  /// Whether a location should be captured at all (soft or strict).
  bool get capturesLocation => this != AttendanceLocationPolicy.none;

  /// Whether being outside the geofence should *block* the clock-in.
  bool get blocksOutside => this == AttendanceLocationPolicy.strict;

  /// Parses the stored string; unknown/missing → [none].
  static AttendanceLocationPolicy fromString(String? raw) {
    for (final p in AttendanceLocationPolicy.values) {
      if (p.name == raw) return p;
    }
    return AttendanceLocationPolicy.none;
  }
}
