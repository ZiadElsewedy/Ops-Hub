import 'package:drop/core/enums/attendance_location_policy.dart';
import 'package:drop/features/attendance/domain/attendance_config.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';

/// The attendance module's **policy seam** — the single place that answers
/// "*is attendance on for this user, and with what rules?*". Pure + framework-free.
///
/// Every branch runs the standing [AttendanceConfig.defaults], with the branch's
/// [BranchEntity.managersCanClock] flag resolved here for managers. This remains
/// the one point that turns branch attendance settings into an [AttendanceConfig]
/// without call-site policy duplication.
///
/// It also owns the module **dark switch** ([isEnabledFor]): while a branch hasn't
/// opted in, the clock surface is inert and the (future) task-start guard is a
/// no-op, so shipping the module never regresses an existing branch. The cubit
/// and any cross-feature guard consult this instead of hard-coding the config.
class AttendanceService {
  const AttendanceService();

  /// The resolved attendance rules for [user]'s [branch]. Managers follow the
  /// branch flag; every other role remains enabled. A missing branch fails open
  /// to preserve the working behaviour of legacy or not-yet-loaded branches.
  AttendanceConfig configFor(UserEntity user, {BranchEntity? branch}) =>
      AttendanceConfig(
        enabled: user.role.isManager ? branch?.managersCanClock ?? true : true,
      );

  /// Whether the attendance module is live for [user] (the dark-switch gate).
  bool isEnabledFor(UserEntity user, {BranchEntity? branch}) =>
      configFor(user, branch: branch).enabled;

  /// The **effective** location policy — the one thing that may gate a punch on
  /// GPS. Callers use this, never `config.locationPolicy` directly.
  ///
  /// [AttendanceLocationPolicy.soft] and [AttendanceLocationPolicy.strict] both
  /// mean "compare the device fix to the branch geofence". With no geofence there
  /// is nothing to compare against, so neither can be satisfied — and the old
  /// behaviour was to refuse the punch forever, which locked an unconfigured
  /// branch out of attendance entirely. Falling back to
  /// [AttendanceLocationPolicy.none] keeps the clock working as a pure time
  /// action until an admin draws the fence (ADR-020).
  static AttendanceLocationPolicy resolveLocationPolicy({
    required AttendanceLocationPolicy configured,
    required bool hasGeofence,
  }) => hasGeofence ? configured : AttendanceLocationPolicy.none;
}
