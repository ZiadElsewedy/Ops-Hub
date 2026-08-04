import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:drop/core/enums/leave_type.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:drop/features/schedule/domain/schedule_week.dart';
import 'package:drop/features/schedule/presentation/widgets/schedule_helpers.dart';

/// The final weekly schedule as a **vector PDF** a manager can save and send
/// (the "save it as PDF" path), the print-native sibling of the on-screen
/// `FinalScheduleSheet` and the PNG export.
///
/// One employee per row, one day per column, a single scannable token per cell
/// (`M` · `N` · `M+N` · `OFF` · `LEAVE` · `VAC`) — the same information the
/// on-screen sheet publishes, so the document and the screen never disagree.
/// Only the people actually **on the schedule** appear ([scheduledRoster]); this
/// is a roster, not a directory.
///
/// Monochrome by design (ADR-004) and generated client-side — acceptable here
/// for the same reason the attendance PDF is (ADR-019): this is an operational
/// document, not a payroll artifact.
Future<Uint8List> buildScheduleFinalPdf({
  required WeeklyScheduleEntity schedule,
  required List<UserEntity> members,
  required String branchName,
  String? managerName,
  DateTime? generatedAt,
}) async {
  final gen = generatedAt ?? DateTime.now();
  final roster = scheduledRoster(schedule, members);
  final hasNotes = ScheduleDay.values.any((d) => schedule.noteFor(d) != null);

  final doc = pw.Document(title: 'Schedule — $branchName');

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 32),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 10),
        child: pw.Text(
          'DROP · OPERATIONS  ·  Page ${context.pageNumber} of ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ),
      build: (context) => [
        _header(
          branchName: branchName,
          schedule: schedule,
          managerName: managerName,
          generatedAt: gen,
        ),
        pw.SizedBox(height: 16),
        _table(schedule, roster),
        pw.SizedBox(height: 14),
        _legend(),
        if (hasNotes) ...[
          pw.SizedBox(height: 16),
          _notes(schedule),
        ],
      ],
    ),
  );

  return doc.save();
}

pw.Widget _header({
  required String branchName,
  required WeeklyScheduleEntity schedule,
  required String? managerName,
  required DateTime generatedAt,
}) {
  final meta = <String>[
    'Week of ${ScheduleWeek.rangeLabel(schedule.weekStart)}',
    'Generated ${AppDateFormatter.dayMonthYear(generatedAt)}',
    if (managerName != null && managerName.trim().isNotEmpty)
      'Manager · ${managerName.trim()}',
  ];
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'DROP',
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey600,
          letterSpacing: 3,
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        branchName,
        style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        'Weekly staff schedule',
        style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
      ),
      pw.SizedBox(height: 6),
      pw.Text(
        meta.join('   ·   '),
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
      ),
      pw.SizedBox(height: 10),
      pw.Divider(height: 1, color: PdfColors.grey400),
    ],
  );
}

pw.Widget _table(WeeklyScheduleEntity schedule, List<UserEntity> roster) {
  if (roster.isEmpty) {
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(vertical: 28),
      child: pw.Text(
        'No one is scheduled this week.',
        style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
      ),
    );
  }
  return pw.TableHelper.fromTextArray(
    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
    cellStyle: const pw.TextStyle(fontSize: 10),
    headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
    cellHeight: 24,
    cellAlignment: pw.Alignment.center,
    cellAlignments: {0: pw.Alignment.centerLeft},
    columnWidths: {
      0: const pw.FlexColumnWidth(2.6),
      for (var i = 1; i <= 7; i++) i: const pw.FlexColumnWidth(1),
    },
    headers: [
      'Employee',
      for (final day in ScheduleDay.values)
        '${day.shortLabel} ${schedule.weekStart.add(Duration(days: day.index)).day}',
    ],
    data: [
      for (final member in roster)
        [
          _rowLabel(member),
          for (final day in ScheduleDay.values)
            _cellToken(schedule, member.uid, day),
        ],
    ],
  );
}

String _rowLabel(UserEntity member) {
  final name = userDisplayName(member);
  final position = member.position?.trim();
  return (position == null || position.isEmpty) ? name : '$name\n$position';
}

/// Mirrors the on-screen sheet's cell logic, so the PDF and the sheet always
/// show the same token for a given slot.
String _cellToken(WeeklyScheduleEntity schedule, String uid, ScheduleDay day) {
  final shifts = schedule.shiftsFor(uid, day);
  if (shifts.isNotEmpty) {
    if (shifts.length >= 2) return 'M+N';
    return shifts.first == ScheduleShift.morning ? 'M' : 'N';
  }
  return switch (schedule.leaveTypeOf(uid, day)) {
    LeaveType.annual => 'VAC',
    LeaveType.sick || LeaveType.pending => 'LEAVE',
    _ => 'OFF',
  };
}

pw.Widget _legend() => pw.Text(
      'M Morning   ·   N Night   ·   M+N Both   ·   OFF Off   ·   '
      'LEAVE Leave   ·   VAC Vacation',
      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
    );

pw.Widget _notes(WeeklyScheduleEntity schedule) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Notes',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        for (final day in ScheduleDay.values)
          if (schedule.noteFor(day) != null)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Text(
                '${day.label}: ${schedule.noteLinesFor(day).join(' · ')}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
              ),
            ),
      ],
    );

/// Stable, filesystem-safe name for the exported schedule PDF — mirrors the PNG
/// export name so both land side by side and sort together in a folder.
String scheduleFinalPdfFilename(String branchName, DateTime weekStart) {
  final safe = branchName
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '')
      .toLowerCase();
  final y = weekStart.year.toString().padLeft(4, '0');
  final m = weekStart.month.toString().padLeft(2, '0');
  final d = weekStart.day.toString().padLeft(2, '0');
  return '${safe.isEmpty ? 'branch' : safe}_schedule_$y-$m-$d.pdf';
}
