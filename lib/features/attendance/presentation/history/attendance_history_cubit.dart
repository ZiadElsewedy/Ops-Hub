import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/utils/app_logger.dart';
import 'package:drop/core/enums/attendance_status_filter.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/features/attendance/domain/attendance_analytics.dart';
import 'package:drop/features/attendance/domain/attendance_history_query.dart';
import 'package:drop/features/attendance/domain/entities/attendance_entity.dart';
import 'package:drop/features/attendance/domain/repositories/attendance_repository.dart';
import 'attendance_history_state.dart';

/// Which ledger this cubit is driving.
enum AttendanceHistoryMode {
  /// The signed-in employee's own history — one `watchUserHistory` stream.
  self,

  /// A manager/admin reviewing a whole branch over a date range —
  /// `watchBranchRange`, re-queried when the date window changes.
  review,
}

/// Drives the Attendance History ledger from **one** realtime stream, holding the
/// active [AttendanceHistoryQuery] and re-deriving the filtered list + summary on
/// every facet change. Reuses the existing repository reads and the pure
/// [AttendanceStats] / [AttendanceHistoryQuery] — no new data path.
///
/// The **summary** ([AttendanceStats]) is computed over the whole date *window*
/// (range facet only), while the **list** applies every facet — so filtering to
/// "Late" narrows the rows without making the headline read "100% late".
class AttendanceHistoryCubit extends Cubit<AttendanceHistoryState> {
  final AttendanceRepository _repository;
  final AttendanceHistoryMode mode;

  /// The employee whose history this is (self mode).
  final String? userId;

  /// Injectable clock so range resolution + streaks are deterministic under test.
  final DateTime Function() _now;

  String? _branchId;
  AttendanceHistoryQuery _query;
  List<AttendanceEntity> _all = const [];
  bool _offline = false;
  bool _syncing = false;
  StreamSubscription<Object?>? _sub;

  AttendanceHistoryCubit({
    required AttendanceRepository repository,
    required this.mode,
    this.userId,
    String? branchId,
    AttendanceHistoryQuery? query,
    DateTime Function()? now,
  })  : _repository = repository,
        _branchId = branchId,
        _query = query ?? const AttendanceHistoryQuery(),
        _now = now ?? DateTime.now,
        super(const AttendanceHistoryState.initial());
  // Injected deps are assigned explicitly (named args read better at the call
  // site than `_`-prefixed initializing formals would). Mirrors AttendanceCubit.
  // ignore_for_file: prefer_initializing_formals

  String? get branchId => _branchId;
  AttendanceHistoryQuery get query => _query;

  /// Start (or restart) the underlying subscription for the current mode/branch.
  void load() {
    if (mode == AttendanceHistoryMode.self) {
      _subscribeSelf();
    } else {
      _subscribeReview();
    }
  }

  Future<void> refresh() async => load();

  /// Replace the active facets. In review mode a change to the *date range*
  /// re-queries the server window; every other facet (status/shift/name) is a
  /// pure client-side re-filter.
  void setQuery(AttendanceHistoryQuery next) {
    final rangeChanged = mode == AttendanceHistoryMode.review &&
        (next.startKey(_now()) != _query.startKey(_now()) ||
            next.endKey(_now()) != _query.endKey(_now()));
    _query = next;
    _emit();
    if (rangeChanged) _subscribeReview();
  }

  // ── Facet shortcuts (thin wrappers the filter widget calls) ──────────────
  void setRange(
    AttendanceDateRange range, {
    DateTime? customStart,
    DateTime? customEnd,
  }) =>
      setQuery(_query.copyWith(
        range: range,
        customStart: customStart,
        customEnd: customEnd,
      ));

  void setStatus(AttendanceStatusFilter status) =>
      setQuery(_query.copyWith(status: status));

  void toggleShift(ScheduleShift shift) {
    final next = {..._query.shifts};
    next.contains(shift) ? next.remove(shift) : next.add(shift);
    setQuery(_query.copyWith(shifts: next));
  }

  void setSearch(String text) => setQuery(_query.copyWith(text: text));

  /// Review mode — switch the branch under review (admin branch picker).
  void selectBranch(String branchId) {
    if (branchId == _branchId) return;
    _branchId = branchId;
    _subscribeReview();
  }

  // ── Subscriptions ────────────────────────────────────────────────────────
  void _subscribeSelf() {
    final uid = userId;
    if (uid == null || uid.isEmpty) {
      emit(const AttendanceHistoryState.loaded(
        records: [],
        stats: AttendanceStats.empty,
        query: AttendanceHistoryQuery(),
      ));
      return;
    }
    _pump();
    _sub?.cancel();
    _sub = _repository.watchUserHistory(uid, limit: 180).listen(
      (feed) {
        _all = feed.records;
        _offline = feed.isOffline;
        _syncing = feed.hasPendingWrites;
        _emit();
      },
      onError: _onStreamError,
    );
  }

  void _subscribeReview() {
    final branchId = _branchId;
    if (branchId == null || branchId.isEmpty) {
      // No branch selected yet (e.g. an admin before the branch list loads) —
      // show an empty ledger; the screen offers the branch picker.
      emit(AttendanceHistoryState.loaded(
        records: const [],
        stats: AttendanceStats.empty,
        query: _query,
      ));
      return;
    }
    _pump();
    _offline = false;
    _syncing = false;
    _sub?.cancel();
    _sub = _repository
        .watchBranchRange(branchId, _query.startKey(_now()), _query.endKey(_now()))
        .listen(
      (records) {
        _all = records;
        _emit();
      },
      onError: _onStreamError,
    );
  }

  /// Show the skeleton only on a cold start (no data yet), never between filter
  /// changes — a re-query keeps the last list visible until fresh data lands.
  void _pump() {
    final hasData = state.maybeMap(loaded: (_) => true, orElse: () => false);
    if (!hasData) emit(const AttendanceHistoryState.loading());
  }

  void _onStreamError(Object e, StackTrace st) {
    AppLog.error('attendance', 'history stream error', e, st);
    if (!isClosed) {
      emit(const AttendanceHistoryState.error('Failed to load attendance.'));
    }
  }

  void _emit() {
    if (isClosed) return;
    final now = _now();
    // Summary reflects the whole date window; the list applies every facet.
    final windowQuery = _query.copyWith(
      status: AttendanceStatusFilter.all,
      shifts: const <ScheduleShift>{},
      text: '',
    );
    final window = windowQuery.apply(_all, now: now);
    final list = _query.apply(_all, now: now);
    emit(AttendanceHistoryState.loaded(
      records: list,
      stats: AttendanceStats.from(window, asOf: now),
      query: _query,
      branchId: _branchId,
      offline: _offline,
      syncing: _syncing,
    ));
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
