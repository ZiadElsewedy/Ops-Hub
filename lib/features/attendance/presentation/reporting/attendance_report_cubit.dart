import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/core/utils/app_logger.dart';
import 'package:drop/features/attendance/domain/attendance_id.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_ledger_row.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_period.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_report.dart';
import 'package:drop/features/attendance/domain/repositories/attendance_reporting_repository.dart';
import 'attendance_report_state.dart';

class AttendanceReportCubit extends Cubit<AttendanceReportState> {
  AttendanceReportCubit({required AttendanceReportingRepository repository})
    // Named args read better at the DI call site than an underscored
    // initializing formal.
    // ignore: prefer_initializing_formals
    : _repository = repository,
      super(const AttendanceReportState.initial());

  final AttendanceReportingRepository _repository;
  StreamSubscription<List<AttendanceLedgerRow>>? _sub;
  _ReportRequest? _activeRequest;

  void watchBranchWindow({
    required String? branchId,
    required AttendancePeriodWindow window,
  }) {
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

  void _emitRows(List<AttendanceLedgerRow> rows) {
    if (isClosed) return;
    emit(
      AttendanceReportState.loaded(
        rows: rows,
        summary: AttendanceReportSummary.fromLedger(rows),
        coverage: LedgerCoverage.fromRows(rows),
      ),
    );
  }

  void _clearWithEmpty() {
    _activeRequest = null;
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
      return 'Attendance report query requires the deployed '
          'attendance_expectations branch/dayKey or user/dayKey composite '
          'index. Deploy firestore.indexes.json, then reload. $raw';
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
