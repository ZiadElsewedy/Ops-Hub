import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/utils/app_logger.dart';
import 'package:drop/core/enums/attendance_correction_kind.dart';
import 'package:drop/core/enums/attendance_status.dart';
import 'package:drop/core/enums/leave_type.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/features/attendance/domain/attendance_config.dart';
import 'package:drop/features/attendance/domain/attendance_feed.dart';
import 'package:drop/features/attendance/domain/attendance_gps.dart';
import 'package:drop/features/attendance/domain/attendance_id.dart';
import 'package:drop/features/attendance/domain/attendance_location_service.dart';
import 'package:drop/features/attendance/domain/attendance_service.dart';
import 'package:drop/features/attendance/domain/attendance_validation.dart';
import 'package:drop/features/attendance/domain/entities/attendance_correction.dart';
import 'package:drop/features/attendance/domain/entities/attendance_entity.dart';
import 'package:drop/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:drop/features/attendance/domain/usecases/clock_in.dart';
import 'package:drop/features/attendance/domain/usecases/clock_out.dart';
import 'package:drop/features/attendance/domain/usecases/request_correction.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/branch/domain/branch_geofence.dart';
import 'package:drop/features/branch/domain/repositories/branch_repository.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:drop/features/schedule/domain/repositories/schedule_repository.dart';
import 'package:drop/features/schedule/domain/shift_window.dart';
import 'package:drop/features/schedule/domain/schedule_week.dart';
import 'attendance_state.dart';

/// The employee-facing attendance cubit — today's shift, the clock in/out/break
/// actions, the live session timer, and the employee's own history.
///
/// The whole surface is driven by **one** realtime stream — the employee's own
/// history ([AttendanceRepository.watchUserHistory]) — from which the active
/// session and today's record are derived. This keeps reads minimal and naturally
/// surfaces an **overnight** session (a night shift still open past midnight lives
/// in yesterday's record, which the recent-history window still contains).
///
/// Today's rostered shift + its scheduled instants are resolved once from the
/// existing schedule seam ([ScheduleRepository.getSchedule] +
/// `WeeklyScheduleEntity.shiftsFor` / `hoursFor` → [ShiftWindow]) — no attendance
/// re-derivation. Every clock action is gated by the pure [AttendanceValidation]
/// engine before a write, so the cubit never issues a write the rules would
/// reject.
class AttendanceCubit extends Cubit<AttendanceState> {
  final AttendanceRepository _repository;
  final ScheduleRepository _scheduleRepository;
  final BranchRepository _branchRepository;
  final AttendanceService _service;
  final AttendanceLocationService _locationService;
  final ClockIn _clockIn;
  final ClockOut _clockOut;
  final RequestCorrection _requestCorrection;

  /// Injectable clock (defaults to [DateTime.now]) — the single time source, so
  /// the clock-in window and the live timer are deterministic under test.
  final DateTime Function() _now;

  UserEntity? _user;
  _TodayContext? _ctx;
  AttendanceConfig _config = const AttendanceConfig(enabled: true);
  List<AttendanceEntity> _history = const [];
  List<AttendanceCorrectionEntity> _myCorrections = const [];
  bool _offline = false;
  bool _syncing = false;
  bool _verifying = false;
  bool _previewing = false;
  AttendanceVerification? _previewVerification;
  LocationError? _previewError;
  StreamSubscription<AttendanceFeed>? _sub;
  StreamSubscription<List<AttendanceCorrectionEntity>>? _correctionsSub;
  Timer? _timer;
  bool _busy = false;
  late DateTime _tick = _now();

  AttendanceCubit({
    required AttendanceRepository repository,
    required ScheduleRepository scheduleRepository,
    required BranchRepository branchRepository,
    required AttendanceService service,
    required AttendanceLocationService locationService,
    required ClockIn clockIn,
    required ClockOut clockOut,
    required RequestCorrection requestCorrection,
    DateTime Function()? now,
  })  : _repository = repository,
        _scheduleRepository = scheduleRepository,
        _branchRepository = branchRepository,
        _service = service,
        _locationService = locationService,
        _clockIn = clockIn,
        _clockOut = clockOut,
        _requestCorrection = requestCorrection,
        _now = now ?? DateTime.now,
        super(const AttendanceState.initial());
  // Fields are assigned explicitly (named args read better at the call site than
  // `_`-prefixed initializing formals would).
  // ignore_for_file: prefer_initializing_formals

  // ─── Derived views over the current history + context ────────────────
  /// The live open session (in-progress, not clocked out), if any — may be an
  /// overnight session from yesterday.
  AttendanceEntity? get _activeRecord {
    for (final r in _history) {
      if (r.isOpen) return r;
    }
    return null;
  }

  /// Today's record for the resolved target shift (may be completed, or null).
  AttendanceEntity? get _todayTargetRecord {
    final id = _ctx?.targetRecordId;
    if (id == null) return null;
    for (final r in _history) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// The record the clock UI acts on.
  AttendanceEntity? get _clockRecord => _activeRecord ?? _todayTargetRecord;

  /// The **eligibility** to clock in (shift / leave / already-clocked) — the
  /// non-GPS gate the UI can show before the person taps. The GPS gate
  /// (permission · service · radius · accuracy) runs at tap time in [clockIn].
  AttendanceCheck get clockInCheck {
    final ctx = _ctx, user = _user;
    if (ctx == null || user == null) {
      return const AttendanceCheck(AttendanceBlock.notEnabled, 'Loading…');
    }
    return AttendanceValidation.checkClockIn(
      userActive: user.isActive,
      todaysShift: ctx.shift,
      leave: ctx.leave,
      existing: _todayTargetRecord,
      now: _now(),
      scheduledStart: ctx.scheduledStart,
      config: _config,
    );
  }

  /// Whether the employee can clock out right now (and why not).
  AttendanceCheck get clockOutCheck => AttendanceValidation.checkClockOut(
        existing: _activeRecord,
        now: _now(),
        config: _config,
      );

  static String _scopeKey(UserEntity u) => '${u.uid}:${u.branchId ?? ''}';

  Future<void> load(UserEntity user, {bool forceRefresh = false}) async {
    final sameScope = _user != null && _scopeKey(_user!) == _scopeKey(user);
    final inError = state.maybeWhen(error: (_) => true, orElse: () => false);
    if (!forceRefresh && !inError && _sub != null && sameScope) return;

    _user = user;
    _config = _resolveConfig(user);

    final hasData = state.maybeMap(loaded: (_) => true, orElse: () => false);
    if (!hasData) emit(const AttendanceState.loading());

    await _resolveContext(user);

    await _sub?.cancel();
    _sub = _repository.watchUserHistory(user.uid).listen(
      (feed) {
        _history = feed.records;
        _offline = feed.isOffline;
        _syncing = feed.hasPendingWrites;
        _emitLoaded();
        _syncTimer();
      },
      onError: (Object e, StackTrace st) {
        AppLog.error('attendance', 'history stream error', e, st);
        emit(const AttendanceState.error('Failed to load attendance.'));
      },
    );

    // The employee's own corrections — drives the one-open-per-record guard
    // (spec R15) so a second correction can't be filed while one is pending.
    await _correctionsSub?.cancel();
    _correctionsSub = _repository.watchUserCorrections(user.uid).listen(
      (corrections) {
        _myCorrections = corrections;
      },
      onError: (Object e, StackTrace st) =>
          AppLog.error('attendance', 'corrections stream error', e, st),
    );
  }

  /// True when the employee already has a pending correction for [recordId]
  /// (enforces one open correction per record — spec R15).
  bool _hasOpenCorrectionFor(String recordId) => _myCorrections.any(
      (c) => c.attendanceId == recordId && c.isPending && !c.isDeleted);

  Future<void> refresh() async {
    final user = _user;
    if (user != null) {
      await load(user, forceRefresh: true);
      await previewLocation();
    }
  }

  /// Config seam — delegated to [AttendanceService], the single place that later
  /// reads a per-branch `branches/{id}/attendanceConfig`. No call-site changes.
  AttendanceConfig _resolveConfig(UserEntity user) => _service.configFor(user);

  /// Resolve today's rostered shift + scheduled window from the schedule (one
  /// cached read). Degrades gracefully to "no shift" when nothing is rostered.
  Future<void> _resolveContext(UserEntity user) async {
    final now = _now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final day = ScheduleDay.fromDate(now);
    try {
      final branchId = user.branchId;
      if (branchId == null || branchId.isEmpty) {
        _ctx = _TodayContext(todayDate: todayDate);
        return;
      }
      final weekStart = ScheduleWeek.startOf(now);
      final schedule = await _scheduleRepository.getSchedule(branchId, weekStart);
      if (schedule == null) {
        _ctx = _TodayContext(todayDate: todayDate);
        return;
      }
      final geofence = await _resolveGeofence(branchId);
      final leave = schedule.leaveTypeOf(user.uid, day);
      final shifts = schedule.shiftsFor(user.uid, day);
      final target = _pickTargetShift(shifts, schedule, weekStart, day, now);
      if (target == null) {
        _ctx = _TodayContext(
            todayDate: todayDate, leave: leave, geofence: geofence);
        return;
      }
      final hours = schedule.hoursFor(day, target);
      _ctx = _TodayContext(
        todayDate: todayDate,
        shift: target,
        leave: leave,
        geofence: geofence,
        scheduledStart: ShiftWindow.startOf(weekStart, day, hours),
        scheduledEnd: ShiftWindow.endOf(weekStart, day, hours),
        targetRecordId:
            attendanceDocId(uid: user.uid, date: todayDate, shift: target),
      );
    } catch (e, st) {
      AppLog.error('attendance', 'resolveContext failed', e, st);
      _ctx = _TodayContext(todayDate: todayDate);
    }
  }

  /// The branch's attendance geofence (from the cached branch list — cheap). Null
  /// when the branch has none configured, or on a lookup failure.
  Future<BranchGeofence?> _resolveGeofence(String branchId) async {
    try {
      final branches = await _branchRepository.getBranches();
      for (final b in branches) {
        if (b.id == branchId) return b.geofence;
      }
    } catch (e, st) {
      AppLog.error('attendance', 'geofence resolve failed', e, st);
    }
    return null;
  }

  /// Of the shift(s) rostered today, the one the clock should target now: the
  /// first slot that hasn't finished yet (morning before night); if both are
  /// done, the later one.
  ScheduleShift? _pickTargetShift(
    List<ScheduleShift> shifts,
    WeeklyScheduleEntity schedule,
    DateTime weekStart,
    ScheduleDay day,
    DateTime now,
  ) {
    if (shifts.isEmpty) return null;
    if (shifts.length == 1) return shifts.first;
    ScheduleShift? last;
    for (final s in shifts) {
      last = s;
      final end = ShiftWindow.endOf(weekStart, day, schedule.hoursFor(day, s));
      if (now.isBefore(end)) return s;
    }
    return last;
  }

  void _emitLoaded() {
    if (isClosed) return;
    final ctx = _ctx;
    emit(AttendanceState.loaded(
      today: _clockRecord,
      session: _activeRecord,
      history: _history,
      shift: ctx?.shift,
      scheduledStart: ctx?.scheduledStart,
      scheduledEnd: ctx?.scheduledEnd,
      leave: ctx?.leave,
      config: _config,
      tick: _tick,
      busy: _busy,
      syncing: _syncing,
      offline: _offline,
      verifying: _verifying,
      geofenceReady: ctx?.geofence != null,
      previewing: _previewing,
      previewVerification: _previewVerification,
      previewError: _previewError,
    ));
  }

  /// Passively read the device location for the **Ready** phase, so the GPS card
  /// shows "At branch · 22 m" / "Outside · 143 m" / a permission-or-service prompt
  /// *before* the employee taps Clock In (a fresh fix is still taken on the write).
  /// A no-op once clocked in or when the branch has no geofence.
  Future<void> previewLocation() async {
    final ctx = _ctx;
    if (isClosed || _busy || _verifying) return;
    if (ctx?.geofence == null || _activeRecord != null || _todayIsSettled) {
      _previewVerification = null;
      _previewError = null;
      return;
    }
    _previewing = true;
    _emitLoaded();
    final gps = await _captureVerification(ctx!.geofence);
    if (isClosed) return;
    _previewVerification = gps.verification;
    _previewError = gps.error;
    _previewing = false;
    _emitLoaded();
  }

  /// Today's target record exists and is finished (completed / auto-closed) — the
  /// Summary phase, where a location preview is irrelevant.
  bool get _todayIsSettled {
    final r = _todayTargetRecord;
    return r != null && !r.isOpen;
  }

  // ─── Clock actions ───────────────────────────────────────────────────
  /// Clock in — the GPS-verified path: eligibility → acquire + verify the GPS fix
  /// → gate on permission/service/radius/accuracy → write the record (with the
  /// clock-in verification; the clock TIME is a server timestamp). Rejections are
  /// surfaced as transient errors.
  Future<void> clockIn() async {
    final user = _user, ctx = _ctx;
    if (user == null || ctx == null || _busy || _verifying) return;
    final eligibility = clockInCheck;
    if (eligibility.blocked) {
      _surface(eligibility.message);
      return;
    }
    final id = ctx.targetRecordId;
    final shift = ctx.shift;
    if (id == null || shift == null) return;

    // The preview gives way to the live verification for the write.
    _previewVerification = null;
    _previewError = null;

    // ── GPS Validation step ──
    _setVerifying(true);
    final gps = await _captureVerification(ctx.geofence);
    _setVerifying(false);
    final gpsCheck = AttendanceValidation.checkGpsFix(
      locationError: gps.error,
      verification: gps.verification,
      geofenceConfigured: ctx.geofence != null,
    );
    if (gpsCheck.blocked) {
      _surface(gpsCheck.message);
      return;
    }

    _setBusy(true);
    try {
      final record = AttendanceEntity(
        id: id,
        userId: user.uid,
        userName: user.displayName,
        branchId: user.branchId,
        shift: shift,
        date: ctx.todayDate,
        scheduledStart: ctx.scheduledStart,
        scheduledEnd: ctx.scheduledEnd,
        // A placeholder — the datasource overrides it with a server timestamp.
        clockIn: _now(),
        clockInVerification: gps.verification,
      );
      await _clockIn(record);
    } on Failure catch (e) {
      _surface(e.message);
    } catch (_) {
      _surface('Something went wrong clocking in.');
    } finally {
      _setBusy(false);
    }
  }

  /// Clock out — captures a **best-effort** GPS verification (recorded wherever
  /// the person is, so a manager can see if they left the branch), but is never
  /// blocked by location: you must always be able to end your shift.
  Future<void> clockOut() async {
    final user = _user;
    final record = _activeRecord;
    if (user == null || record == null || _busy || _verifying) return;
    final check = clockOutCheck;
    if (check.blocked) {
      _surface(check.message);
      return;
    }

    _setVerifying(true);
    final gps = await _captureVerification(_ctx?.geofence);
    _setVerifying(false);

    _setBusy(true);
    try {
      await _clockOut(record,
          now: _now(), config: _config, verification: gps.verification);
    } on Failure catch (e) {
      _surface(e.message);
    } catch (_) {
      _surface('Something went wrong clocking out.');
    } finally {
      _setBusy(false);
    }
  }

  /// Read the device location and evaluate it against [geofence]. Returns the
  /// acquisition [LocationError] (nothing readable) OR the built
  /// [AttendanceVerification] (readable + a geofence to score against).
  Future<({LocationError? error, AttendanceVerification? verification})>
      _captureVerification(BranchGeofence? geofence) async {
    final result = await _locationService.currentLocation();
    if (!result.ok) return (error: result.error, verification: null);
    if (geofence == null) return (error: null, verification: null);
    return (
      error: null,
      verification: AttendanceVerification.evaluate(
        location: result.location!,
        branchLat: geofence.latitude,
        branchLng: geofence.longitude,
        radiusMeters: geofence.radiusMeters,
        minAccuracyMeters: geofence.minAccuracyMeters,
      ),
    );
  }

  void _setVerifying(bool verifying) {
    _verifying = verifying;
    _emitLoaded();
  }

  // ─── Corrections ─────────────────────────────────────────────────────
  /// File a correction against a settled [record] (the employee's own). Gated by
  /// the pure [AttendanceValidation.checkCorrection]; a blocked check surfaces as
  /// a transient error. The `correctionRequested` audit event + reviewer
  /// notifications are derived server-side by `onAttendanceCorrectionWritten`.
  ///
  /// Returns **true** when the correction was filed, **false** when it was blocked
  /// or failed — so the UI can show success vs. leave its sheet open.
  Future<bool> requestCorrection({
    required AttendanceEntity record,
    required AttendanceCorrectionKind kind,
    required String reason,
    DateTime? proposedClockIn,
    DateTime? proposedClockOut,
    AttendanceStatus? proposedStatus,
  }) async {
    final user = _user;
    if (user == null || _busy) return false;
    final check = AttendanceValidation.checkCorrection(
      existing: record,
      reason: reason,
      proposedClockIn: proposedClockIn,
      proposedClockOut: proposedClockOut,
      proposedStatus: proposedStatus,
      hasOpenCorrection: _hasOpenCorrectionFor(record.id),
    );
    if (check.blocked) {
      _surface(check.message);
      return false;
    }
    _setBusy(true);
    try {
      final correction = AttendanceCorrectionEntity(
        id: '',
        attendanceId: record.id,
        userId: user.uid,
        userName: user.displayName,
        branchId: user.branchId,
        shift: record.shift,
        date: record.date,
        scheduledStart: record.scheduledStart,
        scheduledEnd: record.scheduledEnd,
        requestedBy: user.uid,
        requestedByName: user.displayName,
        kind: kind,
        reason: reason.trim(),
        proposedClockIn: proposedClockIn,
        proposedClockOut: proposedClockOut,
        proposedStatus: proposedStatus,
      );
      await _requestCorrection(correction);
      return true;
    } on Failure catch (e) {
      _surface(e.message);
      return false;
    } catch (_) {
      _surface('Something went wrong filing the correction.');
      return false;
    } finally {
      _setBusy(false);
    }
  }

  /// File a **missed-punch** request — the employee worked a rostered shift but
  /// never clocked in, so there is **no record** to correct (the board shows them
  /// Absent). They assert the real clock-in/out + a reason; a reviewer's approval
  /// materializes the record (spec workflow 4). Gated by the same
  /// [AttendanceValidation.checkCorrection] with a null record, plus the
  /// one-open-per-record guard. Requires a resolved rostered shift today.
  ///
  /// Returns **true** when the request was filed, **false** when blocked/failed.
  Future<bool> requestMissedPunch({
    required DateTime proposedClockIn,
    DateTime? proposedClockOut,
    required String reason,
  }) async {
    final user = _user, ctx = _ctx;
    if (user == null || _busy) return false;
    final id = ctx?.targetRecordId;
    final shift = ctx?.shift;
    if (id == null || shift == null) {
      _surface('There\'s no shift scheduled today to add a record for.');
      return false;
    }
    final check = AttendanceValidation.checkCorrection(
      existing: null,
      reason: reason,
      proposedClockIn: proposedClockIn,
      proposedClockOut: proposedClockOut,
      hasOpenCorrection: _hasOpenCorrectionFor(id),
    );
    if (check.blocked) {
      _surface(check.message);
      return false;
    }
    _setBusy(true);
    try {
      final correction = AttendanceCorrectionEntity(
        id: '',
        attendanceId: id,
        userId: user.uid,
        userName: user.displayName,
        branchId: user.branchId,
        shift: shift,
        date: ctx!.todayDate,
        scheduledStart: ctx.scheduledStart,
        scheduledEnd: ctx.scheduledEnd,
        requestedBy: user.uid,
        requestedByName: user.displayName,
        kind: AttendanceCorrectionKind.absenceDispute,
        reason: reason.trim(),
        proposedClockIn: proposedClockIn,
        proposedClockOut: proposedClockOut,
      );
      await _requestCorrection(correction);
      return true;
    } on Failure catch (e) {
      _surface(e.message);
      return false;
    } catch (_) {
      _surface('Something went wrong filing the request.');
      return false;
    } finally {
      _setBusy(false);
    }
  }

  // ─── Live timer (only while a session is open) ───────────────────────
  void _syncTimer() {
    final open = _activeRecord != null;
    if (open && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 30), (_) {
        _tick = _now();
        _emitLoaded();
      });
    } else if (!open && _timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  void _setBusy(bool busy) {
    _busy = busy;
    _emitLoaded();
  }

  /// Surface a transient error as a snackbar, then restore the loaded snapshot so
  /// the UI never loses its data.
  void _surface(String message) {
    if (isClosed) return;
    emit(AttendanceState.error(message));
    _emitLoaded();
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _sub?.cancel();
    _correctionsSub?.cancel();
    return super.close();
  }
}

/// Today's resolved rostered context (immutable snapshot taken at load).
class _TodayContext {
  final DateTime todayDate;
  final ScheduleShift? shift;
  final LeaveType? leave;
  final BranchGeofence? geofence;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final String? targetRecordId;

  const _TodayContext({
    required this.todayDate,
    this.shift,
    this.leave,
    this.geofence,
    this.scheduledStart,
    this.scheduledEnd,
    this.targetRecordId,
  });
}
