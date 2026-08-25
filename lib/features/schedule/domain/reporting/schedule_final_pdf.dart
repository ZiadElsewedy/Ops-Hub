import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:opshub/core/utils/app_date_formatter.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:opshub/features/schedule/domain/reporting/final_schedule_grid.dart';
import 'package:opshub/features/schedule/domain/schedule_week.dart';

/// The final weekly schedule as a **vector PDF** a manager can save and send —
/// the print-native sibling of the on-screen `FinalScheduleSheet` and the Excel
/// export, all rendered from the one [buildFinalScheduleGrid].
///
/// Owner-directed layout (2026-08-05): **shifts down the side (Morning · Night ·
/// Off), days across the top, people named inside each cell** — the same shape
/// the manager keeps in a spreadsheet, so the document and the screen never
/// disagree. Only people actually **on the schedule** appear; an orphaned
/// assignment is dropped.
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
  final grid = buildFinalScheduleGrid(schedule, members);

  final doc = pw.Document(title: 'Schedule — $branchName');

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 32),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 10),
        child: pw.Text(
          'OpsHub  ·  Page ${context.pageNumber} of ${context.pagesCount}',
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
        _table(grid),
        pw.SizedBox(height: 14),
        _legend(grid),
        if (grid.hasNotes) ...[
          pw.SizedBox(height: 16),
          _notes(grid),
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
        'OpsHub',
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

pw.Widget _table(FinalScheduleGrid grid) {
  if (grid.isEmpty) {
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
    cellStyle: const pw.TextStyle(fontSize: 9),
    headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
    cellAlignment: pw.Alignment.topCenter,
    cellAlignments: {0: pw.Alignment.topLeft},
    columnWidths: {
      0: const pw.FlexColumnWidth(1.7),
      for (var i = 1; i <= 7; i++) i: const pw.FlexColumnWidth(1),
    },
    headers: [
      'Shift',
      for (final d in grid.days) '${d.day.shortLabel} ${d.date.day}',
    ],
    data: [
      [
        'Morning\n${grid.morningHours.format()}',
        for (final d in grid.days) _joinNames(d.morning),
      ],
      [
        'Night\n${_nightLabel(grid)}',
        for (final d in grid.days) _joinNames(d.night),
      ],
      if (grid.hasOff)
        [
          'Off',
          for (final d in grid.days)
            _joinNames([
              for (final p in d.off)
                p.tag.isEmpty ? p.name : '${p.name} (${p.tag})',
            ]),
        ],
    ],
  );
}

/// One name per line; an empty cell reads as a quiet dash, matching the sheet.
String _joinNames(List<String> names) => names.isEmpty ? '—' : names.join('\n');

/// The Night hours label — weekday hours, plus the weekend range when it differs.
String _nightLabel(FinalScheduleGrid grid) => grid.weekendNightDiffers
    ? '${grid.nightHours.format()}  ·  Wknd ${grid.weekendNightHours.format()}'
    : grid.nightHours.format();

pw.Widget _legend(FinalScheduleGrid grid) => pw.Text(
      'Morning ${grid.morningHours.format()}   ·   '
      'Night ${_nightLabel(grid)}'
      '${grid.hasOff ? '   ·   Off Marked off / on leave' : ''}'
      '   ·   (V) On vacation   ·   (L) On leave',
      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
    );

pw.Widget _notes(FinalScheduleGrid grid) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Notes',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        for (final d in grid.days)
          if (d.notes.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Text(
                '${d.day.label}: ${d.notes.join(' · ')}',
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
