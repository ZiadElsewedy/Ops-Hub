import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/utils/app_logger.dart';
import 'package:drop/core/enums/attendance_correction_kind.dart';
import 'package:drop/core/enums/attendance_location_policy.dart';
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
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
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
  BranchEntity? _branch;
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
      scheduledEnd: ctx.scheduledEnd,
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

    final hasData = state.maybeMap(loaded: (_) => true, orElse: () => false);
    if (!hasData) emit(const AttendanceState.loading());

    _branch = await _resolveBranch(user.branchId);
    _config = _resolveConfig(user, branch: _branch);
    await _resolveContext(user, branch: _branch);
    // The geofence is only known after the context resolves, and it decides
    // whether a location policy can mean anything at all. Collapsing it into
    // `_config` here means every downstream reader — the validation gate, the
    // clock UI, the record's config snapshot (spec R19) — sees one resolved
    // value instead of re-deriving it.
    _config = _config.copyWith(
      locationPolicy: AttendanceService.resolveLocationPolicy(
        configured: _config.locationPolicy,
        hasGeofence: _ctx?.geofence != null,
      ),
    );

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

  /// Config seam — delegated to [AttendanceService], with the one resolved
  /// branch supplied by this cubit rather than triggering another branch read.
  AttendanceConfig _resolveConfig(UserEntity user, {BranchEntity? branch}) =>
      _service.configFor(user, branch: branch);

  /// Resolve today's rostered shift + scheduled window from the schedule (one
  /// cached read). Degrades gracefully to "no shift" when nothing is rostered.
  ///
  /// **Presence-style roles (managers) always get a clock target.** Their
  /// attendance is an *open shift* — clock in and out at any time — so the
  /// primary [clockIn] must work with or without a rostered slot. When nothing
  /// is rostered the target is the time-of-day bucket ([unscheduledShiftFor]);
  /// when they *do* happen to be on the roster the bucket is that shift, but the
  /// scheduled window is dropped either way (there is nothing to be late for).
  /// The record carries `presenceOnly: true`, so this is not an anomaly — it is
  /// what a manager's clock means.
  Future<void> _resolveContext(UserEntity user, {BranchEntity? branch}) async {
    final now = _now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final day = ScheduleDay.fromDate(now);
    final presenceOnly = !_config.enforceSchedule;

    // A presence-only clock target: an open shift keyed on the current
    // time-of-day bucket, with no scheduled window. Used whenever a manager has
    // no rostered slot resolved (which is the normal case).
    _TodayContext presenceCtx({LeaveType? leave, BranchGeofence? geofence}) {
      final shift = unscheduledShiftFor(now);
      return _TodayContext(
        todayDate: todayDate,
        shift: shift,
        leave: leave,
        geofence: geofence,
        targetRecordId:
            attendanceDocId(uid: user.uid, date: todayDate, shift: shift),
      );
    }

    try {
      final branchId = user.branchId;
      if (branchId == null || branchId.isEmpty) {
        _ctx = presenceOnly
            ? presenceCtx()
            : _TodayContext(todayDate: todayDate);
        return;
      }
      // Resolved before the schedule lookup on purpose: an unscheduled clock-in
      // still runs the full GPS gate (ADR-018), and an unpublished week must not
      // block it for the wrong reason.
      final geofence = branch?.geofence;
      final weekStart = ScheduleWeek.startOf(now);
      final schedule = await _scheduleRepository.getSchedule(branchId, weekStart);
      if (schedule == null) {
        _ctx = presenceOnly
            ? presenceCtx(geofence: geofence)
            : _TodayContext(todayDate: todayDate, geofence: geofence);
        return;
      }
      final leave = schedule.leaveTypeOf(user.uid, day);
      final shifts = schedule.shiftsFor(user.uid, day);
      final target = _pickTargetShift(shifts, schedule, weekStart, day, now);
      if (target == null) {
        _ctx = presenceOnly
            ? presenceCtx(leave: leave, geofence: geofence)
            : _TodayContext(
                todayDate: todayDate, leave: leave, geofence: geofence);
        return;
      }
      final hours = schedule.hoursFor(day, target);
      _ctx = _TodayContext(
        todayDate: todayDate,
        shift: target,
        leave: leave,
        geofence: geofence,
        // A presence-style role carries no scheduled window even when rostered,
        // so its clock never re-acquires the early/late semantics it exists to
        // avoid (mirrors the record built in [clockIn]).
        scheduledStart:
            presenceOnly ? null : ShiftWindow.startOf(weekStart, day, hours),
        scheduledEnd:
            presenceOnly ? null : ShiftWindow.endOf(weekStart, day, hours),
        targetRecordId:
            attendanceDocId(uid: user.uid, date: todayDate, shift: target),
      );
    } catch (e, st) {
      AppLog.error('attendance', 'resolveContext failed', e, st);
      _ctx = presenceOnly ? presenceCtx() : _TodayContext(todayDate: todayDate);
    }
  }

  /// Resolves the branch once from the cached directory so its geofence and
  /// manager clock policy are always based on the same branch snapshot.
  Future<BranchEntity?> _resolveBranch(String? branchId) async {
    if (branchId == null || branchId.isEmpty) return null;
    try {
      final branches = await _branchRepository.getBranches();
      for (final b in branches) {
        if (b.id == branchId) return b;
      }
    } catch (e, st) {
      AppLog.error('attendance', 'branch resolve failed', e, st);
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
  /// A no-op once clocked in, or wherever the effective policy is `none` (which
  /// includes every branch with no geofence — there is nothing to preview
  /// against, and asking for a fix would prompt for a permission the punch will
  /// never need).
  Future<void> previewLocation() async {
    final ctx = _ctx;
    if (isClosed || _busy || _verifying) return;
    if (_config.locationPolicy == AttendanceLocationPolicy.none ||
        ctx?.geofence == null ||
        _activeRecord != null ||
        _todayIsSettled) {
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
      policy: _config.locationPolicy,
    );
    if (gpsCheck.blocked) {
      _surface(gpsCheck.message);
      return;
    }

    _setBusy(true);
    try {
      // Presence-style roles (managers) never carry a scheduled window, even
      // when they happen to be on the roster — their attendance answers "were
      // they here", so a schedule would only re-introduce the early/late
      // semantics the flexible mode exists to remove.
      final presenceOnly = !_config.enforceSchedule;
      final record = AttendanceEntity(
        id: id,
        userId: user.uid,
        userName: user.displayName,
        branchId: user.branchId,
        shift: shift,
        date: ctx.todayDate,
        scheduledStart: presenceOnly ? null : ctx.scheduledStart,
        scheduledEnd: presenceOnly ? null : ctx.scheduledEnd,
        presenceOnly: presenceOnly,
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

  /// **Start an unscheduled shift** — [ADR-018].
  ///
  /// For the employee who is genuinely at work on a day the roster does not
  /// know about: covering a sick colleague, called in at short notice, or
  /// working a week that was never published. Refusing the punch does not
  /// prevent the work, it prevents the record — and the alternative (a manager
  /// typing the times in afterwards) is strictly worse evidence than this,
  /// which is server-timestamped and GPS-verified at the moment of presence.
  ///
  /// Deliberate by construction: this is never the screen's primary action and
  /// [reason] is mandatory. The full GPS gate applies, exactly as for a
  /// scheduled clock-in — when the roster does not vouch for someone, location
  /// is the only remaining proof they were there.
  ///
  /// The shift carries **no scheduled window**, so there is nothing to be late
  /// for, worked minutes run from the real clock-in (R2's clamp needs a
  /// scheduled start), and the session closes under R7's 16-hour cap rather
  /// than R6's scheduled-end grace. It counts in **nothing** until a manager
  /// approves it in Daily Review.
  Future<bool> clockInUnscheduled({required String reason}) async {
    final user = _user, ctx = _ctx;
    if (user == null || ctx == null || _busy || _verifying) return false;
    if (!_config.enabled) {
      _surface('Attendance isn\'t enabled here.');
      return false;
    }
    if (!_config.allowUnscheduledClockIn) {
      _surface('Unscheduled shifts are switched off for this branch.');
      return false;
    }
    if (ctx.shift != null) {
      _surface('You have a shift scheduled today — clock in to that instead.');
      return false;
    }
    final trimmed = reason.trim();
    if (trimmed.isEmpty) {
      _surface('Say why you are working an unscheduled shift.');
      return false;
    }
    if (_activeRecord != null) {
      _surface('You\'re already clocked in.');
      return false;
    }

    final now = _now();
    final shift = unscheduledShiftFor(now);
    final id = attendanceDocId(
      uid: user.uid,
      date: ctx.todayDate,
      shift: shift,
    );

    _previewVerification = null;
    _previewError = null;

    _setVerifying(true);
    final gps = await _captureVerification(ctx.geofence);
    _setVerifying(false);
    final gpsCheck = AttendanceValidation.checkGpsFix(
      locationError: gps.error,
      verification: gps.verification,
      geofenceConfigured: ctx.geofence != null,
      policy: _config.locationPolicy,
    );
    if (gpsCheck.blocked) {
      _surface(gpsCheck.message);
      return false;
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
        // No scheduled window — this is what marks the shift unscheduled
        // everywhere downstream. For a presence-style role it is not an
        // anomaly at all, so the flag rides along to say so.
        scheduledStart: null,
        scheduledEnd: null,
        presenceOnly: !_config.enforceSchedule,
        clockIn: now, // placeholder; the datasource writes a server timestamp
        clockInVerification: gps.verification,
        notes: trimmed,
      );
      await _clockIn(record);
      return true;
    } on Failure catch (e) {
      _surface(e.message);
      return false;
    } catch (_) {
      _surface('Something went wrong starting the shift.');
      return false;
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

  /// Drops both user-scoped streams, the live ticker and every cached record,
  /// returning the cubit to [AttendanceState.initial]. Called on sign-out and on
  /// single-active-session eviction. The ticker matters as much as the streams:
  /// this cubit is app-wide, so a `Timer` left running keeps rebuilding a
  /// signed-out user's clock state forever.
  void reset() {
    _timer?.cancel();
    _timer = null;
    _sub?.cancel();
    _sub = null;
    _correctionsSub?.cancel();
    _correctionsSub = null;
    _user = null;
    _branch = null;
    _ctx = null;
    _config = const AttendanceConfig(enabled: true);
    _history = const [];
    _myCorrections = const [];
    _offline = false;
    _syncing = false;
    _verifying = false;
    _previewing = false;
    _previewVerification = null;
    _previewError = null;
    _busy = false;
    if (!isClosed) emit(const AttendanceState.initial());
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
