import 'package:opshub/core/utils/app_date_formatter.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_ledger_row.dart';

/// The timesheet a manager opens in a spreadsheet ([ADR-019]).
///
/// **Written for a person, not a payroll system.** The payroll schema this
/// replaces emitted `2026-07-29T05:30:00.000Z` and `487`, because a machine
/// rounds and prices for itself. A manager checking someone's week wants
/// `29 Jul`, `08:37` and `7h 52m`. Same facts, opposite formatting — which is
/// why this is a different artifact rather than a trimmed one.
///
/// Eleven columns instead of thirty-seven. Everything dropped was either
/// machine plumbing (period ids, row ids, scope kind, timezone on every row) or
/// a field no manager reads (GPS distances, correction ids, restatement links).
///
/// Pure and dependency-free: it returns a string. Writing it to disk is the
/// caller's job, using the same `path_provider` path the Schedule PNG export
/// already uses.

const List<String> attendanceTimesheetColumns = [
  'Date',
  'Employee',
  'Shift',
  'Outcome',
  'Scheduled',
  'Hours',
  'Late (min)',
  'Early leave (min)',
  'Overtime',
  'Issues',
  'Clock-in recorded',
];

/// RFC4180 escaping.
///
/// Not cosmetic, and the one piece of the deleted payroll builder that had to
/// survive intact: an employee named `Amal, "A"` silently shifts every later
/// column by one, and a spreadsheet opens the shifted row without complaining.
String csvEscape(Object? value) {
  if (value == null) return '';
  final s = '$value';
  if (s.contains(RegExp(r'[",\r\n]'))) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

String _hours(int minutes) {
  if (minutes <= 0) return '0h';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

String _time(DateTime? at) => at == null ? '' : AppDateFormatter.time(at);

String _scheduled(AttendanceLedgerRow row) {
  final start = row.scheduledStartAt;
  final end = row.scheduledEndAt;
  // No scheduled window is exactly what marks an unscheduled shift (ADR-018),
  // so it is stated rather than left blank and ambiguous.
  if (start == null && end == null) return 'Unscheduled';
  return '${_time(start)}–${_time(end)}';
}

String _readableDate(AttendanceLedgerRow row) {
  final date = DateTime.tryParse(row.businessDate);
  if (date == null) return row.businessDate;
  return AppDateFormatter.weekdayDayMonth(date);
}

List<String> _cellsFor(AttendanceLedgerRow row) {
  final issues = [
    ...row.exceptionCodes.map((c) => c.label),
    ...row.unknownExceptionCodes,
  ];
  return [
    _readableDate(row),
    row.userName?.trim().isNotEmpty ?? false ? row.userName!.trim() : row.userId,
    row.shift.label,
    row.outcome.label,
    _scheduled(row),
    _hours(row.workedMinutes),
    '${row.lateMinutes}',
    '${row.earlyLeaveMinutes}',
    _hours(row.overtimeMinutes),
    issues.join(' · '),
    row.recordId == null ? 'No' : 'Yes',
  ];
}

/// Header plus one line per shift, CRLF-terminated per RFC4180.
///
/// Rows are emitted in the order given — the report already sorts them by date,
/// which is how a manager reads a week.
String buildAttendanceTimesheetCsv(List<AttendanceLedgerRow> rows) {
  final out = <String>[attendanceTimesheetColumns.map(csvEscape).join(',')];
  for (final row in rows) {
    out.add(_cellsFor(row).map(csvEscape).join(','));
  }
  return '${out.join('\r\n')}\r\n';
}

/// A filename a manager can find again, mirroring `scheduleExportFilename`.
String attendanceTimesheetFilename(String branchName, DateTime weekStart) {
  final safe = branchName
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final y = weekStart.year.toString().padLeft(4, '0');
  final m = weekStart.month.toString().padLeft(2, '0');
  final d = weekStart.day.toString().padLeft(2, '0');
  return 'attendance-${safe.isEmpty ? 'branch' : safe}-$y$m$d.csv';
}
