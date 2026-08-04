import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/enums/leave_type.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/enums/shift_hours_scope.dart';
import 'package:drop/core/enums/shift_template_role.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/core/utils/app_logger.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/domain/usecases/get_users_by_branch.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:drop/features/schedule/domain/repositories/schedule_repository.dart';
import 'package:drop/features/schedule/domain/repositories/shift_template_repository.dart';
import 'package:drop/features/schedule/domain/schedule_week.dart';
import 'package:drop/features/schedule/domain/shift_hours.dart';
import 'schedule_state.dart';

/// Drives the weekly-schedule view for managers (own branch), admins (any
/// branch) and employees (read-only, own branch). Loads the schedule for a
/// (branch, week) together with the branch members (for name display + the
/// assignee picker), then keeps the view visible during mutations. Calls
/// [ScheduleRepository] directly (no use-case layer — same as branch/admin).
class ScheduleCubit extends Cubit<ScheduleState> {
  final ScheduleRepository _repository;
  final GetUsersByBranch _getUsersByBranch;
  final ShiftTemplateRepository _templates;

  String _branchId = '';
  DateTime _weekStart = ScheduleWeek.currentWeekStart();
  Set<String> _previousSaturdayNight = const {};

  /// When the data currently on screen was last fetched — the freshness clock
  /// behind [_freshFor]. Null until the first successful load, and reset to null
  /// on error so a retry always refetches.
  DateTime? _loadedAt;

  /// How long a just-loaded (branch, week) stays reusable without a refetch.
  /// Re-opening the schedule within this window is **instant** — the roster
  /// already on screen is shown as-is instead of firing a Firestore read on
  /// every single visit (the "it loads every time I click" complaint). Any real
  /// scope change (branch/week), an explicit [refresh] or pull-to-refresh, and
  /// every roster mutation still refetch, so a stale window is at most this long
  /// and only against edits made on another device. Short by design for an
  /// operations tool.
  static const Duration _freshFor = Duration(seconds: 60);

  ScheduleCubit(this._repository, this._getUsersByBranch, this._templates)
      : super(const ScheduleState.initial());

  String get branchId => _branchId;
  DateTime get weekStart => _weekStart;

  /// Who worked the **previous week's** Saturday night — refreshed with every
  /// load and consumed by the insight/health computations so the Saturday
  /// night → Sunday morning turnaround (the tightest one: weekend nights end
  /// at/after midnight) is caught across the week boundary. Kept beside [branchId]/
  /// [weekStart] as cubit context rather than in the freezed state.
  Set<String> get previousSaturdayNight => _previousSaturdayNight;

  bool get _busy => state.maybeWhen(
        loaded: (_, _, _, _, busy) => busy,
        loading: () => true,
        orElse: () => false,
      );

  /// Loads the schedule + branch members for ([branchId], [weekStart]). Pass an
  /// empty [branchId] (admin, no branch picked yet) to render the empty view.
  ///
  /// A **same-scope** reload (screen revisit, pull-to-refresh) keeps the
  /// current view on screen while refetching — no skeleton flash, the schedule
  /// never "disappears" on navigation. Only a real scope change (different
  /// branch or week) shows the loading state.
  ///
  /// Re-requesting the scope already on screen while it is still fresh (see
  /// [_freshFor]) is a **no-op** — the whole point of the freshness window: a
  /// screen revisit reuses what we have instead of hitting the network on every
  /// tap. Pass [force] (used by [refresh] and pull-to-refresh) to always
  /// refetch regardless of freshness.
  Future<void> load({
    required String branchId,
    DateTime? weekStart,
    bool force = false,
  }) async {
    final newWeek = ScheduleWeek.startOf(weekStart ?? _weekStart);
    // Silent only when the data already ON SCREEN is the requested scope.
    final showingSameScope = state.maybeWhen(
      loaded: (b, w, _, _, _) => b == branchId && w == newWeek,
      orElse: () => false,
    );
    final fresh = _loadedAt != null &&
        DateTime.now().difference(_loadedAt!) < _freshFor;
    if (showingSameScope && fresh && !force) return;
    _branchId = branchId;
    _weekStart = newWeek;
    if (!showingSameScope) emit(const ScheduleState.loading());
    await _emitLoaded();
  }

  Future<void> previousWeek() =>
      load(branchId: _branchId, weekStart: _weekStart.subtract(const Duration(days: 7)));

  Future<void> nextWeek() =>
      load(branchId: _branchId, weekStart: _weekStart.add(const Duration(days: 7)));

  Future<void> selectBranch(String branchId) =>
      load(branchId: branchId, weekStart: _weekStart);

  /// User-driven refresh (toolbar button, pull-to-refresh) — always refetches,
  /// bypassing the freshness window.
  Future<void> refresh() =>
      load(branchId: _branchId, weekStart: _weekStart, force: true);

  /// Creates an empty schedule for the current (branch, week). The branch's
  /// current shift templates are **snapshotted** onto the new week (Schedule V2
  /// · Pillar 5), freezing its hours so later template edits never rewrite it. A
  /// branch with no templates snapshots nothing → standard hours (legacy).
  Future<void> createSchedule({String? createdBy}) {
    if (_branchId.isEmpty) return Future.value();
    return _mutate(() async {
      final set = await _templates.getSet(_branchId);
      await _repository.createSchedule(
        branchId: _branchId,
        weekStart: _weekStart,
        createdBy: createdBy,
        shiftPlan: set.isEmpty ? null : set.plan,
      );
    });
  }

  Future<bool> assign(ScheduleDay day, ScheduleShift shift, String uid) =>
      _mutate(() => _repository.assignEmployee(
            scheduleId: ScheduleWeek.docId(_branchId, _weekStart),
            day: day,
            shift: shift,
            employeeId: uid,
          ));

  Future<bool> remove(
    ScheduleDay day,
    ScheduleShift shift,
    String uid, {
    bool recordUndo = true,
  }) async {
    final ok = await _mutate(() => _repository.removeEmployee(
          scheduleId: ScheduleWeek.docId(_branchId, _weekStart),
          day: day,
          shift: shift,
          employeeId: uid,
        ));
    if (ok && recordUndo) {
      _recordUndo(() => assign(day, shift, uid));
    }
    return ok;
  }

  /// Drag-to-move (Schedule 3.0): reassign [uid] from one slot to another in
  /// a single busy cycle. Assign to the target FIRST, then release the source
  /// — if the assign fails the person never leaves their original shift.
  Future<bool> move({
    required ScheduleDay fromDay,
    required ScheduleShift fromShift,
    required ScheduleDay toDay,
    required ScheduleShift toShift,
    required String uid,
    bool recordUndo = true,
  }) async {
    if (fromDay == toDay && fromShift == toShift) return false;
    final scheduleId = ScheduleWeek.docId(_branchId, _weekStart);
    final ok = await _mutate(() async {
      await _repository.assignEmployee(
        scheduleId: scheduleId,
        day: toDay,
        shift: toShift,
        employeeId: uid,
      );
      await _repository.removeEmployee(
        scheduleId: scheduleId,
        day: fromDay,
        shift: fromShift,
        employeeId: uid,
      );
    });
    if (ok && recordUndo) {
      _recordUndo(() => move(
            fromDay: toDay,
            fromShift: toShift,
            toDay: fromDay,
            toShift: fromShift,
            uid: uid,
            recordUndo: false,
          ));
    }
    return ok;
  }

  /// Chip-onto-chip drag (Schedule 3.1): two people trade slots in a single
  /// busy cycle — [uidA] (from A's slot) takes B's slot and [uidB] takes A's.
  /// Same safety order as [move]: both are assigned to their NEW slots first,
  /// then released from the old ones — a failed assign never strands anyone
  /// off the schedule.
  Future<bool> exchange({
    required ScheduleDay dayA,
    required ScheduleShift shiftA,
    required String uidA,
    required ScheduleDay dayB,
    required ScheduleShift shiftB,
    required String uidB,
    bool recordUndo = true,
  }) async {
    // Self-swaps and same-slot trades are no-ops, not errors.
    if (uidA == uidB) return false;
    if (dayA == dayB && shiftA == shiftB) return false;
    final scheduleId = ScheduleWeek.docId(_branchId, _weekStart);
    final ok = await _mutate(() async {
      await _repository.assignEmployee(
          scheduleId: scheduleId, day: dayB, shift: shiftB, employeeId: uidA);
      await _repository.assignEmployee(
          scheduleId: scheduleId, day: dayA, shift: shiftA, employeeId: uidB);
      await _repository.removeEmployee(
          scheduleId: scheduleId, day: dayA, shift: shiftA, employeeId: uidA);
      await _repository.removeEmployee(
          scheduleId: scheduleId, day: dayB, shift: shiftB, employeeId: uidB);
    });
    if (ok && recordUndo) {
      // An exchange is self-inverse: trade the (now swapped) slots back.
      _recordUndo(() => exchange(
            dayA: dayB,
            shiftA: shiftB,
            uidA: uidA,
            dayB: dayA,
            shiftB: shiftA,
            uidB: uidB,
            recordUndo: false,
          ));
    }
    return ok;
  }

  /// Pins a manager note to [day] (empty [note] clears it) — Schedule 5.0.
  Future<bool> setDayNote(ScheduleDay day, String note) =>
      _mutate(() => _repository.setDayNote(
            scheduleId: ScheduleWeek.docId(_branchId, _weekStart),
            day: day,
            note: note,
          ));

  /// Marks [uid] on [type] leave for [day]; null [type] clears the entry —
  /// Schedule 5.0. Leave is day-level (whole day), not per shift.
  Future<bool> setLeave(ScheduleDay day, String uid, LeaveType? type) =>
      _mutate(() => _repository.setLeave(
            scheduleId: ScheduleWeek.docId(_branchId, _weekStart),
            day: day,
            employeeId: uid,
            type: type,
          ));

  /// Overrides the [hours] for [day] + [shift] this week; null [hours] clears
  /// the override (the slot falls back to [ShiftHours.standard]). Configurable
  /// shift times — replaces the old hardcoded weekend end.
  Future<bool> setShiftHours(
    ScheduleDay day,
    ScheduleShift shift,
    ShiftHours? hours,
  ) =>
      _mutate(() => _repository.setShiftHours(
            scheduleId: ScheduleWeek.docId(_branchId, _weekStart),
            day: day,
            shift: shift,
            hours: hours,
          ));

  /// Applies a shift-hours edit at the manager's chosen [scope] (Schedule V2 ·
  /// Pillar 5):
  ///  - [ShiftHoursScope.thisWeek] → a frozen per-slot override on this week
  ///    (the existing [setShiftHours]);
  ///  - [ShiftHoursScope.future] → updates the branch template for the slot's
  ///    standing role; only weeks created afterward snapshot the new hours;
  ///  - [ShiftHoursScope.global] → updates the template **and** re-stamps this
  ///    week + every future existing week (past weeks stay frozen).
  Future<bool> applyShiftHours(
    ScheduleDay day,
    ScheduleShift shift,
    ShiftHours hours,
    ShiftHoursScope scope,
  ) {
    if (scope == ShiftHoursScope.thisWeek) {
      return setShiftHours(day, shift, hours);
    }
    return _mutate(() async {
      // ensureDefaults guarantees the three standing role templates exist.
      final set = await _templates.ensureDefaults(_branchId);
      final role = ShiftTemplateRole.forSlot(day, shift);
      final template = set.forRole(role);
      if (template != null) {
        await _templates.upsertTemplate(template.copyWith(hours: hours));
      }
      if (scope == ShiftHoursScope.global) {
        await _repository.restampShiftPlan(
          branchId: _branchId,
          fromWeek: _weekStart,
          plan: set.plan.withRole(role, hours),
        );
      }
    });
  }

  // ── Undo (Schedule 4.0) ────────────────────────────────────────
  /// The inverse of the last direct roster edit (move / exchange / remove),
  /// valid for [undoWindow] and cleared by any newer mutation. UI shows an
  /// UNDO snackbar for the same window.
  static const Duration undoWindow = Duration(seconds: 5);

  Future<bool> Function()? _undo;
  DateTime _undoExpires = DateTime.fromMillisecondsSinceEpoch(0);

  bool get canUndo => _undo != null && DateTime.now().isBefore(_undoExpires);

  void _recordUndo(Future<bool> Function() inverse) {
    _undo = inverse;
    _undoExpires = DateTime.now().add(undoWindow);
  }

  /// Reverts the last move / exchange / remove. Safe to call after the window
  /// or twice — a stale/duplicate undo is a quiet no-op.
  Future<void> undoLast() async {
    final inverse = _undo;
    if (inverse == null || !DateTime.now().isBefore(_undoExpires)) return;
    _undo = null;
    await inverse();
  }

  // ── Internals ──────────────────────────────────────────────────
  Future<void> _emitLoaded() async {
    try {
      if (_branchId.isEmpty) {
        _previousSaturdayNight = const {};
        _loadedAt = DateTime.now();
        emit(ScheduleState.loaded(
          branchId: _branchId,
          weekStart: _weekStart,
          schedule: null,
          members: const [],
        ));
        return;
      }
      // The three reads are independent — fetch in parallel so the extra
      // previous-week probe never adds a round-trip to the load.
      final schedule = AppLog.time('schedule', 'getSchedule',
          () => _repository.getSchedule(_branchId, _weekStart));
      final members = AppLog.time(
          'schedule', 'getUsersByBranch', () => _getUsersByBranch(_branchId));
      final prevNight = _previousSaturdayNightCrew();
      final results = await Future.wait([schedule, members, prevNight]);
      _previousSaturdayNight = results[2]! as Set<String>;
      _loadedAt = DateTime.now();
      emit(ScheduleState.loaded(
        branchId: _branchId,
        weekStart: _weekStart,
        schedule: results[0] as WeeklyScheduleEntity?,
        members: results[1]! as List<UserEntity>,
      ));
    } on Failure catch (e) {
      _loadedAt = null;
      emit(ScheduleState.error(e.message));
    } catch (_) {
      _loadedAt = null;
      emit(const ScheduleState.error('Failed to load the schedule.'));
    }
  }

  /// Last week's Saturday-night uids — best-effort: a missing previous week
  /// or a read failure yields an empty set and never fails the main load.
  Future<Set<String>> _previousSaturdayNightCrew() async {
    try {
      final prev = await _repository.getSchedule(
          _branchId, _weekStart.subtract(const Duration(days: 7)));
      return prev
              ?.employeesFor(ScheduleDay.saturday, ScheduleShift.night)
              .toSet() ??
          const {};
    } catch (_) {
      return const {};
    }
  }

  /// Runs [action], then reloads the view — keeping the current view visible
  /// (busy) so the UI never flickers, and restoring it on failure. Returns
  /// whether the action succeeded (drives undo recording + UI feedback).
  Future<bool> _mutate(Future<void> Function() action) async {
    if (_busy) return false;
    // Any newer mutation invalidates a pending undo — the schedule it would
    // restore no longer exists. (undoLast clears _undo before running its
    // inverse, so the inverse itself is never wiped here.)
    _undo = null;
    final prev = state;
    state.maybeWhen(
      loaded: (b, w, s, m, _) => emit(ScheduleState.loaded(
          branchId: b, weekStart: w, schedule: s, members: m, busy: true)),
      orElse: () {},
    );
    try {
      await action();
      await _emitLoaded();
      return true;
    } on Failure catch (e) {
      emit(ScheduleState.error(e.message));
      emit(prev);
      return false;
    } catch (_) {
      emit(const ScheduleState.error('Something went wrong. Please try again.'));
      emit(prev);
      return false;
    }
  }
}
