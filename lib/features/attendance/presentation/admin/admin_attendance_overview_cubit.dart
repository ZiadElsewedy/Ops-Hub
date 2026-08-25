import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opshub/core/utils/app_logger.dart';
import 'package:opshub/features/attendance/domain/attendance_id.dart';
import 'package:opshub/features/attendance/domain/reporting/admin_attendance_overview.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_ledger_row.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_period.dart';
import 'package:opshub/features/attendance/domain/repositories/attendance_reporting_repository.dart';

enum AdminOverviewStatus { initial, loading, loaded, error }

class AdminAttendanceOverviewState {
  const AdminAttendanceOverviewState({
    required this.status,
    this.overview,
    this.message,
  });

  const AdminAttendanceOverviewState.initial()
    : status = AdminOverviewStatus.initial,
      overview = null,
      message = null;

  final AdminOverviewStatus status;
  final AdminAttendanceOverview? overview;
  final String? message;
}

/// The admin cross-branch attendance read.
///
/// **Fans out one branch stream per branch and merges.** There is no
/// collection-wide ledger query and deliberately no new composite index: the
/// deployed `(branchId, dayKey)` index already serves each leg, and at this
/// product's scale a handful of parallel range reads is cheaper than a new
/// index plus the rules surface a cross-branch query would need.
///
/// Ledger-only, like every other reporting read (ADR-017). It never touches raw
/// attendance records, the roster, or the live board.
class AdminAttendanceOverviewCubit extends Cubit<AdminAttendanceOverviewState> {
  AdminAttendanceOverviewCubit({
    required AttendanceReportingRepository repository,
  })  // Named arg reads better at the DI call site than an underscored formal.
      // ignore: prefer_initializing_formals
      : _repository = repository,
        super(const AdminAttendanceOverviewState.initial());

  final AttendanceReportingRepository _repository;
  final _subs = <StreamSubscription<List<AttendanceLedgerRow>>>[];
  final _rowsByBranch = <String, List<AttendanceLedgerRow>>{};
  Map<String, String> _names = const {};
  AttendancePeriodWindow? _window;

  /// Watch [branchIds] over [window]. Re-calling replaces the whole fan-out.
  Future<void> watch({
    required List<String> branchIds,
    required Map<String, String> names,
    required AttendancePeriodWindow window,
  }) async {
    await _cancel();
    _window = window;
    _names = names;
    _rowsByBranch
      ..clear()
      // Seeded empty so a branch with no ledger rows at all still appears —
      // "this branch reported nothing" is the single most important thing this
      // surface exists to show, and a missing key would render as a missing
      // branch.
      ..addEntries(branchIds.map((id) => MapEntry(id, const [])));

    if (branchIds.isEmpty) {
      emit(_loaded());
      return;
    }

    emit(
      const AdminAttendanceOverviewState(status: AdminOverviewStatus.loading),
    );

    final start = attendanceDayKey(window.startDate);
    final end = attendanceDayKey(window.endDate);
    for (final branchId in branchIds) {
      _subs.add(
        _repository
            .watchBranchLedgerRange(
              branchId: branchId,
              startDayKey: start,
              endDayKey: end,
            )
            .listen(
              (rows) {
                _rowsByBranch[branchId] = rows;
                if (!isClosed) emit(_loaded());
              },
              onError: (Object e) {
                AppLog.error('attendance-admin-overview', branchId, e);
                if (!isClosed) {
                  emit(
                    AdminAttendanceOverviewState(
                      status: AdminOverviewStatus.error,
                      overview: state.overview,
                      message: _readable(e),
                    ),
                  );
                }
              },
            ),
      );
    }
  }

  AdminAttendanceOverviewState _loaded() => AdminAttendanceOverviewState(
    status: AdminOverviewStatus.loaded,
    overview: AdminAttendanceOverview.fromBranchRows(
      window: _window!,
      rowsByBranch: Map.of(_rowsByBranch),
      namesByBranchId: _names,
    ),
  );

  static String _readable(Object e) {
    final raw = e.toString().toLowerCase();
    if (raw.contains('failed-precondition') ||
        raw.contains('requires an index') ||
        raw.contains('composite index')) {
      return 'Attendance reports are not switched on yet — the branch/day '
          'index still needs deploying. Details: $e';
    }
    return 'Failed to load the attendance overview. $e';
  }

  Future<void> _cancel() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
  }

  @override
  Future<void> close() async {
    await _cancel();
    return super.close();
  }
}
