import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:opshub/core/utils/app_date_formatter.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_weekly_report.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_week_review.dart';

/// The weekly report as a document a manager can send to an owner ([ADR-019]).
///
/// **The same five sections as the screen, in the same order** — needs
/// attention, the week in one line, the four numbers, by person, by day. A PDF
/// that reorganised the report would be a second information architecture to
/// keep in sync, and the screen's order was argued for once already.
///
/// Deliberately monochrome, matching the app (ADR-004). Colour appears only
/// where it does on screen: an unworked scheduled shift.
///
/// Generated client-side. That is only acceptable because this is an
/// operational document — ADR-005's server-authoring requirement applied to
/// payroll artifacts, and there are none.
Future<Uint8List> buildWeeklyAttendancePdf({
  required WeeklyAttendanceReport report,
  required String branchName,
  AttendanceWeekReviewState reviewState = const AttendanceWeekReviewState.none(),
  DateTime? generatedAt,
}) async {
  final doc = pw.Document(title: 'Attendance — $branchName');
  final blocking = report.coverage.ledgerCoverage.blockingExceptionRowCount;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(32, 36, 32, 36),
      // A page number on every sheet: a printed report that loses its order is
      // worse than one that was never printed.
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 12),
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ),
      build: (context) => [
        _header(
          branchName: branchName,
          report: report,
          reviewState: reviewState,
          generatedAt: generatedAt ?? DateTime.now(),
        ),
        pw.SizedBox(height: 18),

        if (blocking > 0) ...[
          _needsAttention(blocking),
          pw.SizedBox(height: 14),
        ],

        _oneLine(report),
        pw.SizedBox(height: 14),

        _numbers(report),
        pw.SizedBox(height: 20),

        _byPerson(report),
        pw.SizedBox(height: 20),

        _byDay(report),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _header({
  required String branchName,
  required WeeklyAttendanceReport report,
  required AttendanceWeekReviewState reviewState,
  required DateTime generatedAt,
}) {
  final w = report.window;
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        branchName,
        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        'Attendance · Sun ${AppDateFormatter.dayMonth(w.startDate)} – '
        'Sat ${AppDateFormatter.dayMonth(w.endDate)}',
        style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
      ),
      pw.SizedBox(height: 6),
      // Both states, never merged into one verdict — the same rule the screen
      // follows. Coverage is computed; review is asserted by a person.
      pw.Text(
        '${report.coverage.statusLabel} · ${reviewState.label}',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
      ),
      pw.Text(
        'Generated ${AppDateFormatter.weekdayDayMonth(generatedAt)} · '
        'Africa/Cairo',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
      ),
      pw.SizedBox(height: 10),
      pw.Divider(height: 1, color: PdfColors.grey400),
    ],
  );
}

pw.Widget _needsAttention(int blocking) => pw.Container(
  width: double.infinity,
  padding: const pw.EdgeInsets.all(10),
  decoration: pw.BoxDecoration(
    border: pw.Border.all(color: PdfColors.grey600),
    borderRadius: pw.BorderRadius.circular(4),
  ),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'Needs attention',
        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        '$blocking ${blocking == 1 ? 'shift needs' : 'shifts need'} a decision '
        'before this week is done.',
        style: const pw.TextStyle(fontSize: 9),
      ),
    ],
  ),
);

pw.Widget _oneLine(WeeklyAttendanceReport report) {
  final worked = report.shiftsWorked;
  final scheduled = report.shiftsScheduled;
  final parts = <String>[
    '$worked of $scheduled ${scheduled == 1 ? 'shift' : 'shifts'} worked',
    _hours(report.summary.workedMinutes),
    if (report.summary.overtimeMinutes > 0)
      '${_hours(report.summary.overtimeMinutes)} overtime',
  ];
  return pw.Text(
    report.coverage.awaitingClose ? 'Nothing recorded yet' : parts.join(' · '),
    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
  );
}

/// The same four the screen shows. Show-up rate is absent here for the same
/// reason it is absent there: at store volumes a percentage is the least
/// reliable figure on the page.
pw.Widget _numbers(WeeklyAttendanceReport report) {
  final s = report.summary;
  return pw.Row(
    children: [
      _stat('Hours worked', _hours(s.workedMinutes)),
      _stat('Overtime', _hours(s.overtimeMinutes)),
      _stat('Unexcused absences', '${s.absent}'),
      _stat('Late arrivals', '${s.lateArrivals}'),
    ],
  );
}

pw.Widget _stat(String label, String value) => pw.Expanded(
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        value,
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
      ),
      pw.Text(
        label,
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
      ),
    ],
  ),
);

pw.Widget _byPerson(WeeklyAttendanceReport report) {
  if (report.employees.isEmpty) {
    return _section(
      'By person',
      pw.Text(
        'Nobody has a recorded shift this week.',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
      ),
    );
  }
  return _section(
    'By person',
    pw.TableHelper.fromTextArray(
      cellStyle: const pw.TextStyle(fontSize: 8),
      headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellAlignment: pw.Alignment.centerLeft,
      headers: const [
        'Employee',
        'Scheduled',
        'Worked',
        'Absent',
        'Late min',
        'Hours',
        'Overtime',
        'Status',
      ],
      // Order is preserved from the report: exceptions first, then
      // alphabetical. Re-sorting here would quietly undo that decision.
      data: [
        for (final e in report.employees)
          [
            e.displayName,
            '${e.expected}',
            '${e.present}',
            '${e.absent}',
            '${e.lateMinutes}',
            _hours(e.workedMinutes),
            _hours(e.overtimeMinutes),
            e.attentionBand.label,
          ],
      ],
    ),
  );
}

pw.Widget _byDay(WeeklyAttendanceReport report) => _section(
  'By day',
  pw.TableHelper.fromTextArray(
    cellStyle: const pw.TextStyle(fontSize: 8),
    headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
    cellAlignment: pw.Alignment.centerLeft,
    headers: const [
      'Day',
      'Recorded',
      'Scheduled',
      'Worked',
      'Absent',
      'Late min',
    ],
    data: [
      for (final day in report.days)
        [
          '${AppDateFormatter.weekdayDayMonth(day.date).split(',').first} '
              '${AppDateFormatter.dayMonth(day.date)}',
          // "No data" is an unknown, not a zero — the distinction the whole
          // redesign turned on, so it survives into print.
          day.hasRows
              ? '${day.rows.length} ${day.rows.length == 1 ? 'shift' : 'shifts'}'
              : 'No data',
          day.hasRows ? '${day.expected}' : '—',
          day.hasRows ? '${day.present}' : '—',
          day.hasRows ? '${day.absent}' : '—',
          day.hasRows ? '${day.lateMinutes}' : '—',
        ],
    ],
  ),
);

pw.Widget _section(String title, pw.Widget child) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Text(title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
    pw.SizedBox(height: 6),
    child,
  ],
);

String _hours(int minutes) {
  if (minutes <= 0) return '0h';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

/// Mirrors [attendanceTimesheetFilename] so both exports land side by side and
/// sort together in a folder.
String attendanceWeeklyPdfFilename(String branchName, DateTime weekStart) {
  final safe = branchName
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final y = weekStart.year.toString().padLeft(4, '0');
  final m = weekStart.month.toString().padLeft(2, '0');
  final d = weekStart.day.toString().padLeft(2, '0');
  return 'attendance-${safe.isEmpty ? 'branch' : safe}-$y$m$d.pdf';
}
