import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:drop/features/schedule/domain/reporting/final_schedule_grid.dart';
import 'package:drop/features/schedule/domain/schedule_week.dart';

/// The final weekly schedule as a real **Excel workbook** (`.xlsx`) a manager
/// can open, print, or drop into payroll — the shift-row × day-column grid from
/// [buildFinalScheduleGrid], laid out exactly like the on-screen sheet and the
/// PDF (Morning · Night · Off rows, days across, names in the cells).
///
/// There is no pure-Dart xlsx writer we can depend on (the `excel` package pins
/// an `archive` major that conflicts with `lottie`), so the OOXML
/// (SpreadsheetML) parts are hand-written and zipped with `archive` — the same
/// dependency-light path the schedule/attendance PDF took over `printing`. The
/// output is a minimal but valid single-sheet workbook with inline strings,
/// bold/bordered headers, merged title cells and wrapped multi-name cells.
Uint8List buildScheduleFinalXlsx({
  required WeeklyScheduleEntity schedule,
  required List<UserEntity> members,
  required String branchName,
  String? managerName,
  DateTime? generatedAt,
}) {
  final grid = buildFinalScheduleGrid(schedule, members);
  final gen = generatedAt ?? DateTime.now();

  final sheet = _sheetXml(
    grid: grid,
    branchName: branchName,
    managerName: managerName,
    generatedAt: gen,
  );

  final archive = Archive()
    ..addFile(ArchiveFile.string('[Content_Types].xml', _contentTypes))
    ..addFile(ArchiveFile.string('_rels/.rels', _rootRels))
    ..addFile(ArchiveFile.string('xl/workbook.xml', _workbook))
    ..addFile(ArchiveFile.string('xl/_rels/workbook.xml.rels', _workbookRels))
    ..addFile(ArchiveFile.string('xl/styles.xml', _styles))
    ..addFile(ArchiveFile.string('xl/worksheets/sheet1.xml', sheet));

  return Uint8List.fromList(ZipEncoder().encode(archive));
}

// ── Worksheet ────────────────────────────────────────────────────
// Style ids (indices into cellXfs in [_styles]):
const _sTitle = 1; // big bold, left
const _sMeta = 2; // small grey, left
const _sHeader = 3; // bold, filled, bordered, centered, wrapped
const _sShift = 4; // bold, filled, bordered, top-left, wrapped
const _sBody = 5; // bordered, top-left, wrapped
const _sNoteLabel = 6; // bold, top-left
const _sNoteText = 7; // top-left, wrapped

// 8 columns: A (shift label) + B…H (Sun…Sat).
const _lastCol = 'H';

String _sheetXml({
  required FinalScheduleGrid grid,
  required String branchName,
  required String? managerName,
  required DateTime generatedAt,
}) {
  final rows = StringBuffer();
  final merges = <String>[];
  var r = 1;

  String cell(int col, int row, String text, int style) =>
      '<c r="${_ref(col, row)}" s="$style" t="inlineStr">'
      '<is><t xml:space="preserve">${_esc(text)}</t></is></c>';

  // Title block (rows 1–3), each merged across the full width.
  rows.write('<row r="$r" ht="26" customHeight="1">'
      '${cell(0, r, branchName, _sTitle)}</row>');
  merges.add('A$r:$_lastCol$r');
  r++;
  rows.write('<row r="$r" ht="16" customHeight="1">'
      '${cell(0, r, 'Weekly staff schedule', _sMeta)}</row>');
  merges.add('A$r:$_lastCol$r');
  r++;
  final meta = <String>[
    'Week of ${ScheduleWeek.rangeLabel(grid.weekStart)}',
    'Generated ${AppDateFormatter.dayMonthYear(generatedAt)}',
    if (managerName != null && managerName.trim().isNotEmpty)
      'Manager: ${managerName.trim()}',
  ].join('    ·    ');
  rows.write('<row r="$r" ht="16" customHeight="1">'
      '${cell(0, r, meta, _sMeta)}</row>');
  merges.add('A$r:$_lastCol$r');
  r++;

  // Spacer.
  rows.write('<row r="$r" ht="8" customHeight="1"/>');
  r++;

  // Column header: Shift | Sun 5 | Mon 6 | …
  final headerRow = StringBuffer('<row r="$r" ht="22" customHeight="1">');
  headerRow.write(cell(0, r, 'Shift', _sHeader));
  for (var i = 0; i < grid.days.length; i++) {
    final d = grid.days[i];
    headerRow.write(cell(
      i + 1,
      r,
      '${d.day.shortLabel}  ${d.date.day}',
      _sHeader,
    ));
  }
  headerRow.write('</row>');
  rows.write(headerRow);
  r++;

  // Morning · Night · Off shift rows.
  rows.write(_shiftRow(
    row: r++,
    label: 'Morning\n${grid.morningHours.format()}',
    days: grid.days,
    cellsFor: (d) => d.morning,
  ));
  rows.write(_shiftRow(
    row: r++,
    label: 'Night\n${_nightLabel(grid)}',
    cellsFor: (d) => d.night,
    days: grid.days,
  ));
  if (grid.hasOff) {
    rows.write(_shiftRow(
      row: r++,
      label: 'Off',
      days: grid.days,
      cellsFor: (d) => [
        for (final p in d.off) p.tag.isEmpty ? p.name : '${p.name} (${p.tag})',
      ],
    ));
  }

  // Notes (optional) — one row per day that carries a note.
  if (grid.hasNotes) {
    rows.write('<row r="$r" ht="8" customHeight="1"/>');
    r++;
    rows.write('<row r="$r" ht="18" customHeight="1">'
        '${cell(0, r, 'Notes', _sNoteLabel)}</row>');
    r++;
    for (final d in grid.days) {
      if (d.notes.isEmpty) continue;
      rows.write('<row r="$r">'
          '${cell(0, r, d.day.label, _sNoteLabel)}'
          '${cell(1, r, d.notes.join(' · '), _sNoteText)}</row>');
      merges.add('B$r:$_lastCol$r');
      r++;
    }
  }

  final mergeXml = merges.isEmpty
      ? ''
      : '<mergeCells count="${merges.length}">'
          '${merges.map((m) => '<mergeCell ref="$m"/>').join()}'
          '</mergeCells>';

  return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<cols>'
      '<col min="1" max="1" width="20" customWidth="1"/>'
      '<col min="2" max="8" width="17" customWidth="1"/>'
      '</cols>'
      '<sheetData>$rows</sheetData>'
      '$mergeXml'
      '</worksheet>';
}

/// A shift row (Morning / Night / Off): a bold label cell followed by one
/// wrapped, newline-joined name cell per day. Row height grows with the busiest
/// cell so every name is visible without the reader resizing the row.
String _shiftRow({
  required int row,
  required String label,
  required List<FinalScheduleDay> days,
  required List<String> Function(FinalScheduleDay) cellsFor,
}) {
  // The height must cover the busiest cell (and the two-line label).
  final labelLines = '\n'.allMatches(label).length + 1;
  var maxLines = labelLines;
  final cells = <String>[
    '<c r="${_ref(0, row)}" s="$_sShift" t="inlineStr">'
        '<is><t xml:space="preserve">${_esc(label)}</t></is></c>',
  ];
  for (var i = 0; i < days.length; i++) {
    final names = cellsFor(days[i]);
    if (names.length > maxLines) maxLines = names.length;
    cells.add('<c r="${_ref(i + 1, row)}" s="$_sBody" t="inlineStr">'
        '<is><t xml:space="preserve">${_esc(names.join('\n'))}</t></is></c>');
  }
  final ht = (maxLines * 15 + 8).clamp(22, 400);
  return '<row r="$row" ht="$ht" customHeight="1">${cells.join()}</row>';
}

/// The Night row's hours label — weekday hours, plus the weekend range when it
/// differs (the operational weekend runs later).
String _nightLabel(FinalScheduleGrid grid) => grid.weekendNightDiffers
    ? '${grid.nightHours.format()}\nWknd ${grid.weekendNightHours.format()}'
    : grid.nightHours.format();

/// `A1`-style reference for a 0-based [col] (0…7 → A…H) and 1-based [row].
String _ref(int col, int row) => '${String.fromCharCode(65 + col)}$row';

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

// ── Static package parts ─────────────────────────────────────────
const _contentTypes = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
    '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
    '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
    '</Types>';

const _rootRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
    '</Relationships>';

const _workbook = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
    '<sheets><sheet name="Schedule" sheetId="1" r:id="rId1"/></sheets>'
    '</workbook>';

const _workbookRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
    '</Relationships>';

// Fonts 0 normal · 1 bold · 2 title · 3 small-grey.
// Fills 0 none · 1 gray125 (reserved) · 2 light header fill.
// Borders 0 none · 1 thin grey all-sides.
// cellXfs indexed by the _s* constants above.
const _styles = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
    '<fonts count="4">'
    '<font><sz val="11"/><name val="Calibri"/></font>'
    '<font><b/><sz val="11"/><name val="Calibri"/></font>'
    '<font><b/><sz val="18"/><name val="Calibri"/></font>'
    '<font><sz val="9"/><color rgb="FF6E6E77"/><name val="Calibri"/></font>'
    '</fonts>'
    '<fills count="3">'
    '<fill><patternFill patternType="none"/></fill>'
    '<fill><patternFill patternType="gray125"/></fill>'
    '<fill><patternFill patternType="solid"><fgColor rgb="FFF2F2F4"/><bgColor indexed="64"/></patternFill></fill>'
    '</fills>'
    '<borders count="2">'
    '<border><left/><right/><top/><bottom/><diagonal/></border>'
    '<border>'
    '<left style="thin"><color rgb="FFBFBFBF"/></left>'
    '<right style="thin"><color rgb="FFBFBFBF"/></right>'
    '<top style="thin"><color rgb="FFBFBFBF"/></top>'
    '<bottom style="thin"><color rgb="FFBFBFBF"/></bottom>'
    '<diagonal/></border>'
    '</borders>'
    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
    '<cellXfs count="8">'
    // 0 normal
    '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
    // 1 title
    '<xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1" applyAlignment="1"><alignment horizontal="left" vertical="center"/></xf>'
    // 2 meta
    '<xf numFmtId="0" fontId="3" fillId="0" borderId="0" xfId="0" applyFont="1" applyAlignment="1"><alignment horizontal="left" vertical="center"/></xf>'
    // 3 header
    '<xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf>'
    // 4 shift label
    '<xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="left" vertical="top" wrapText="1"/></xf>'
    // 5 body
    '<xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1" applyAlignment="1"><alignment horizontal="left" vertical="top" wrapText="1"/></xf>'
    // 6 note label
    '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1" applyAlignment="1"><alignment horizontal="left" vertical="top"/></xf>'
    // 7 note text
    '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0" applyAlignment="1"><alignment horizontal="left" vertical="top" wrapText="1"/></xf>'
    '</cellXfs>'
    '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
    '</styleSheet>';

/// Stable, filesystem-safe name for the exported schedule workbook — mirrors the
/// PNG/PDF export names so all three land side by side and sort together.
String scheduleFinalXlsxFilename(String branchName, DateTime weekStart) {
  final safe = branchName
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '')
      .toLowerCase();
  final y = weekStart.year.toString().padLeft(4, '0');
  final m = weekStart.month.toString().padLeft(2, '0');
  final d = weekStart.day.toString().padLeft(2, '0');
  return '${safe.isEmpty ? 'branch' : safe}_schedule_$y-$m-$d.xlsx';
}
