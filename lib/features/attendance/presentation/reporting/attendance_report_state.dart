import 'package:opshub/features/attendance/domain/reporting/attendance_ledger_row.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_report.dart';

enum AttendanceReportStatus { initial, loading, loaded, error }

class AttendanceReportState {
  const AttendanceReportState({
    required this.status,
    required this.rows,
    required this.summary,
    required this.coverage,
    this.message,
    this.namesByUid = const {},
  });

  const AttendanceReportState.initial()
    : status = AttendanceReportStatus.initial,
      rows = const [],
      summary = AttendanceReportSummary.empty,
      coverage = LedgerCoverage.empty,
      message = null,
      namesByUid = const {};

  const AttendanceReportState.loading({
    this.rows = const [],
    this.summary = AttendanceReportSummary.empty,
    this.coverage = LedgerCoverage.empty,
    this.namesByUid = const {},
  }) : status = AttendanceReportStatus.loading,
       message = null;

  const AttendanceReportState.loaded({
    required this.rows,
    required this.summary,
    required this.coverage,
    this.namesByUid = const {},
  }) : status = AttendanceReportStatus.loaded,
       message = null;

  const AttendanceReportState.error(
    String this.message, {
    this.rows = const [],
    this.summary = AttendanceReportSummary.empty,
    this.coverage = LedgerCoverage.empty,
    this.namesByUid = const {},
  }) : status = AttendanceReportStatus.error;

  final AttendanceReportStatus status;
  final List<AttendanceLedgerRow> rows;
  final AttendanceReportSummary summary;
  final LedgerCoverage coverage;
  final String? message;

  /// uid -> display name for the report's branch, used only when a ledger row
  /// carries no frozen `userName`. A phantom no-show has no attendance record to
  /// copy a name from, so without this an absence renders as a raw Firebase uid.
  /// Purely a label: every denominator still comes from the ledger alone.
  final Map<String, String> namesByUid;

  bool get isAwaitingClose =>
      status == AttendanceReportStatus.loaded && coverage.awaitingClose;

  AttendanceReportState copyWith({
    AttendanceReportStatus? status,
    List<AttendanceLedgerRow>? rows,
    AttendanceReportSummary? summary,
    LedgerCoverage? coverage,
    String? message,
  }) => AttendanceReportState(
    status: status ?? this.status,
    rows: rows ?? this.rows,
    summary: summary ?? this.summary,
    coverage: coverage ?? this.coverage,
    message: message ?? this.message,
  );

  @override
  bool operator ==(Object other) =>
      other is AttendanceReportState &&
      other.status == status &&
      _listEquals(other.rows, rows) &&
      other.summary == summary &&
      other.coverage == coverage &&
      other.message == message;

  @override
  int get hashCode =>
      Object.hash(status, Object.hashAll(rows), summary, coverage, message);
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
