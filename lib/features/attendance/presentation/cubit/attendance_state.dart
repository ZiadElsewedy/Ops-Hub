import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:opshub/core/enums/leave_type.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/attendance/domain/attendance_config.dart';
import 'package:opshub/features/attendance/domain/attendance_gps.dart';
import 'package:opshub/features/attendance/domain/attendance_location_service.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_entity.dart';

part 'attendance_state.freezed.dart';

@freezed
class AttendanceState with _$AttendanceState {
  const factory AttendanceState.initial() = _Initial;

  /// First load (full-screen skeleton).
  const factory AttendanceState.loading() = _Loading;

  /// Loaded. [today] is the record the clock UI acts on — the live open session
  /// if one exists (including an overnight session from yesterday), else today's
  /// record for the resolved [shift], else null (not clocked in yet). [session]
  /// is the currently-running open session specifically (null when not clocked
  /// in), exposed distinctly from [today] so the UI can tell "a live session" from
  /// "today's finished/absent record". [shift] / [scheduledStart] /
  /// [scheduledEnd] describe today's rostered slot (null when nothing is
  /// rostered); [leave] is set when the employee is on leave today. [tick] is
  /// bumped by the live timer so the worked-time display recomputes.
  ///
  /// [busy] is a clock action in flight (a spinner-worthy local operation);
  /// [syncing] means a local write hasn't been acknowledged by the backend yet
  /// (offline persistence) and [offline] means the snapshot is cache-only — both
  /// derived from the history stream's metadata, so the UI can reassure "saved,
  /// syncing…" without blocking the clock.
  const factory AttendanceState.loaded({
    AttendanceEntity? today,
    AttendanceEntity? session,
    @Default(<AttendanceEntity>[]) List<AttendanceEntity> history,
    ScheduleShift? shift,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    LeaveType? leave,
    required AttendanceConfig config,
    required DateTime tick,
    @Default(false) bool busy,
    @Default(false) bool syncing,
    @Default(false) bool offline,

    /// A clock action is currently acquiring + verifying the GPS fix (the "GPS
    /// Validation" step). Drives the "Checking you're at the branch…" UI.
    @Default(false) bool verifying,

    /// Whether the branch has an attendance geofence configured (an admin set
    /// lat/lng/radius). False → GPS clock-in can't proceed here yet.
    @Default(false) bool geofenceReady,

    // ── Live GPS preview (Ready phase) ──
    // A passive location read taken while the employee is *deciding* to clock in,
    // so the GPS card is state-driven before they tap: it shows "At branch · 22 m"
    // / "Outside · 143 m" / a permission or service prompt. A fresh fix is taken
    // again on the actual clock-in write.
    /// True while the preview fix is being acquired ("Checking location…").
    @Default(false) bool previewing,

    /// The evaluated preview (distance · within-radius · accuracy), or null before
    /// the first read / when there's nothing to preview.
    AttendanceVerification? previewVerification,

    /// The reason the preview couldn't be read (permission / service / no fix).
    LocationError? previewError,
  }) = _Loaded;

  /// Transient — surfaced as a snackbar; the cubit immediately re-emits the last
  /// [loaded] snapshot so the UI never loses its data.
  const factory AttendanceState.error(String message) = _Error;
}
