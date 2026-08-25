import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opshub/core/errors/failures.dart';
import 'package:opshub/core/utils/app_logger.dart';
import 'package:opshub/features/attendance/domain/attendance_id.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_ledger_row.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_period.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_report.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/features/attendance/domain/repositories/attendance_reporting_repository.dart';
import 'package:opshub/features/auth/domain/usecases/get_users_by_branch.dart';
import 'attendance_report_state.dart';

class AttendanceReportCubit extends Cubit<AttendanceReportState> {
  AttendanceReportCubit({
    required AttendanceReportingRepository repository,
    GetUsersByBranch? getUsersByBranch,
  })
    // Named args read better at the DI call site than an underscored
    // initializing formal.
    // ignore: prefer_initializing_formals
    : _repository = repository,
      // ignore: prefer_initializing_formals
      _getUsersByBranch = getUsersByBranch,
      super(const AttendanceReportState.initial());

  final AttendanceReportingRepository _repository;

  /// Optional on purpose: without it the report simply falls back to the uid,
  /// which is the behaviour every existing caller and test already expects.
  final GetUsersByBranch? _getUsersByBranch;
  Map<String, String> _namesByUid = const {};

  /// uid → role for the branch, resolved alongside the names. Drives the
  /// manager-viewer visibility filter: a manager's branch report shows their
  /// employees plus their own row, never a peer manager/admin. Client-side only
  /// — the ledger read rules stay branch-scoped.
  Map<String, UserRole> _roleByUid = const {};

  /// The last raw ledger rows, kept so the filter can be re-applied once the
  /// role directory finishes loading (it may arrive after the first rows).
  List<AttendanceLedgerRow> _lastRows = const [];
  bool _employeesOnly = false;
  String? _viewerUid;

  StreamSubscription<List<AttendanceLedgerRow>>? _sub;
  _ReportRequest? _activeRequest;

  /// [employeesOnly] + [viewerUid] scope a MANAGER's branch report to their
  /// employees (plus their own row). Both default off, so admin callers and
  /// every existing test keep the full-branch view unchanged.
  void watchBranchWindow({
    required String? branchId,
    required AttendancePeriodWindow window,
    String? viewerUid,
    bool employeesOnly = false,
  }) {
    _viewerUid = viewerUid;
    _employeesOnly = employeesOnly;
    final id = branchId?.trim();
    if (id == null || id.isEmpty) {
      _clearWithEmpty();
      return;
    }
    _watch(
      _ReportRequest.branch(
        id,
        attendanceDayKey(window.startDate),
        attendanceDayKey(window.endDate),
      ),
    );
    _loadBranchNames(id);
  }

  void watchUserWindow({
    required String? userId,
    required AttendancePeriodWindow window,
  }) {
    final id = userId?.trim();
    if (id == null || id.isEmpty) {
      _clearWithEmpty();
      return;
    }
    _watch(
      _ReportRequest.user(
        id,
        attendanceDayKey(window.startDate),
        attendanceDayKey(window.endDate),
      ),
    );
  }

  Future<void> refresh() async {
    final request = _activeRequest;
    if (request == null) return;
    _activeRequest = null;
    _watch(request);
  }

  void _watch(_ReportRequest request) {
    if (_activeRequest == request) return;
    _activeRequest = request;
    final previous = state.status == AttendanceReportStatus.loaded
        ? state
        : const AttendanceReportState.initial();
    emit(
      AttendanceReportState.loading(
        rows: previous.rows,
        summary: previous.summary,
        coverage: previous.coverage,
      ),
    );
    _sub?.cancel();
    final stream = request.isBranch
        ? _repository.watchBranchLedgerRange(
            branchId: request.scopeId,
            startDayKey: request.startDayKey,
            endDayKey: request.endDayKey,
          )
        : _repository.watchUserLedgerRange(
            userId: request.scopeId,
            startDayKey: request.startDayKey,
            endDayKey: request.endDayKey,
          );
    _sub = stream.listen(_emitRows, onError: _onStreamError);
  }

  /// Best-effort: a directory failure must never take down a report whose
  /// numbers are already correct, so it leaves the uid fallback in place and
  /// logs rather than emitting an error state.
  Future<void> _loadBranchNames(String branchId) async {
    final resolve = _getUsersByBranch;
    if (resolve == null) return;
    try {
      final users = await resolve(branchId);
      if (isClosed) return;
      final names = <String, String>{};
      for (final user in users) {
        final name = (user.displayName ?? user.email).trim();
        if (name.isNotEmpty) names[user.uid] = name;
      }
      _namesByUid = Map.unmodifiable(names);
      _roleByUid = {for (final user in users) user.uid: user.role};
      if (state.status == AttendanceReportStatus.loaded) {
        // Re-emit from the raw rows so the freshly-loaded roles are applied (the
        // first rows may have arrived before this directory fetch finished).
        _emitVisible();
      }
    } catch (e, st) {
      AppLog.error('attendance', 'report name directory failed', e, st);
    }
  }

  void _emitRows(List<AttendanceLedgerRow> rows) {
    if (isClosed) return;
    _lastRows = rows;
    _emitVisible();
  }

  /// Emit the loaded state from the last raw rows, applying the manager-viewer
  /// visibility filter and recomputing the summary/coverage from the filtered
  /// rows (so a manager's totals reflect their employees only).
  void _emitVisible() {
    if (isClosed) return;
    final rows = _visibleRows(_lastRows);
    emit(
      AttendanceReportState.loaded(
        rows: rows,
        summary: AttendanceReportSummary.fromLedger(rows),
        coverage: LedgerCoverage.fromRows(rows),
        namesByUid: _namesByUid,
      ),
    );
  }

  /// A MANAGER viewer (opted in via [watchBranchWindow]) sees only their
  /// employees plus their own row — never a peer manager/admin. Unknown uids
  /// default to visible so a real employee is never hidden by a missing
  /// directory entry. A no-op for admin callers (feature off).
  List<AttendanceLedgerRow> _visibleRows(List<AttendanceLedgerRow> rows) {
    if (!_employeesOnly) return rows;
    final self = _viewerUid;
    return rows.where((row) {
      if (row.userId == self) return true;
      final role = _roleByUid[row.userId];
      return role != UserRole.manager && role != UserRole.admin;
    }).toList();
  }

  void _clearWithEmpty() {
    _activeRequest = null;
    _lastRows = const [];
    _sub?.cancel();
    emit(
      const AttendanceReportState.loaded(
        rows: [],
        summary: AttendanceReportSummary.empty,
        coverage: LedgerCoverage.empty,
      ),
    );
  }

  void _onStreamError(Object e, StackTrace st) {
    AppLog.error('attendance', 'report ledger stream error', e, st);
    if (!isClosed) {
      final message = _messageForError(e);
      emit(AttendanceReportState.error(message));
    }
  }

  String _messageForError(Object e) {
    if (e is Failure) return e.message;
    final raw = e.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('failed-precondition') ||
        lower.contains('requires an index') ||
        lower.contains('composite index')) {
      // Lead with what the reader can act on; keep the raw cause for whoever
      // actually runs the deploy.
      return 'Attendance reports are not switched on yet — an administrator '
          'needs to finish setting them up. Details: $raw';
    }
    return 'Failed to load attendance report. $raw';
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}

class _ReportRequest {
  const _ReportRequest._({
    required this.kind,
    required this.scopeId,
    required this.startDayKey,
    required this.endDayKey,
  });

  factory _ReportRequest.branch(
    String branchId,
    String startDayKey,
    String endDayKey,
  ) => _ReportRequest._(
    kind: _ReportRequestKind.branch,
    scopeId: branchId,
    startDayKey: startDayKey,
    endDayKey: endDayKey,
  );

  factory _ReportRequest.user(
    String userId,
    String startDayKey,
    String endDayKey,
  ) => _ReportRequest._(
    kind: _ReportRequestKind.user,
    scopeId: userId,
    startDayKey: startDayKey,
    endDayKey: endDayKey,
  );

  final _ReportRequestKind kind;
  final String scopeId;
  final String startDayKey;
  final String endDayKey;

  bool get isBranch => kind == _ReportRequestKind.branch;

  @override
  bool operator ==(Object other) =>
      other is _ReportRequest &&
      other.kind == kind &&
      other.scopeId == scopeId &&
      other.startDayKey == startDayKey &&
      other.endDayKey == endDayKey;

  @override
  int get hashCode => Object.hash(kind, scopeId, startDayKey, endDayKey);
}

enum _ReportRequestKind { branch, user }
