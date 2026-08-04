import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_exception.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_ledger_row.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_timesheet_csv.dart';

void main() {
  AttendanceLedgerRow row({
    String userId = 'u1',
    String? userName = 'Amal',
    AttendanceLedgerOutcome outcome = AttendanceLedgerOutcome.worked,
    bool unscheduled = false,
    String? recordId = 'u1_20260729_morning',
    int workedMinutes = 472,
    int lateMinutes = 0,
    int earlyLeaveMinutes = 0,
    int overtimeMinutes = 0,
    List<AttendanceExceptionCode> exceptionCodes = const [],
  }) => AttendanceLedgerRow(
    id: '${userId}_20260729_morning',
    rowId: '${userId}_20260729_morning',
    userId: userId,
    userName: userName,
    branchId: 'b1',
    dayKey: '20260729',
    businessDate: '2026-07-29',
    shift: ScheduleShift.morning,
    scheduledStartAt: unscheduled ? null : DateTime(2026, 7, 29, 8, 30),
    scheduledEndAt: unscheduled ? null : DateTime(2026, 7, 29, 16, 30),
    outcome: outcome,
    expected: true,
    recordId: recordId,
    workedMinutes: workedMinutes,
    lateMinutes: lateMinutes,
    earlyLeaveMinutes: earlyLeaveMinutes,
    overtimeMinutes: overtimeMinutes,
    exceptionCodes: exceptionCodes,
    locked: false,
    version: 1,
    source: 'system',
  );

  /// A real RFC4180 line parser, so an escaped comma cannot fake a pass.
  List<String> cells(String line) {
    final out = <String>[];
    final field = StringBuffer();
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (quoted) {
        if (c == '"') {
          if (i + 1 < line.length && line[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            quoted = false;
          }
        } else {
          field.write(c);
        }
      } else if (c == '"') {
        quoted = true;
      } else if (c == ',') {
        out.add(field.toString());
        field.clear();
      } else {
        field.write(c);
      }
    }
    out.add(field.toString());
    return out;
  }

  List<String> lines(String csv) =>
      csv.trimRight().split('\r\n').where((l) => l.isNotEmpty).toList();

  String valueOf(String line, String column) =>
      cells(line)[attendanceTimesheetColumns.indexOf(column)];

  test('the header is the documented column set', () {
    final csv = buildAttendanceTimesheetCsv(const []);
    expect(lines(csv).single, attendanceTimesheetColumns.join(','));
    expect(attendanceTimesheetColumns, hasLength(11));
  });

  test('it is written for a person, not a payroll system', () {
    // The schema this replaced emitted ISO-UTC instants and raw minute counts
    // because a machine rounds for itself. A manager wants readable time.
    final line = lines(buildAttendanceTimesheetCsv([row()]))[1];

    expect(valueOf(line, 'Hours'), '7h 52m');
    expect(valueOf(line, 'Date'), contains('Jul'));
    expect(valueOf(line, 'Date'), isNot(contains('T')));
    expect(valueOf(line, 'Scheduled'), contains('–'));
    expect(valueOf(line, 'Outcome'), 'Worked');
  });

  test('an awkward name cannot shift the columns', () {
    // The one piece of the deleted payroll builder that had to survive: a
    // spreadsheet opens a shifted row without complaining.
    final line = lines(
      buildAttendanceTimesheetCsv([row(userName: 'Amal, "A"')]),
    )[1];
    final parsed = cells(line);

    expect(parsed, hasLength(attendanceTimesheetColumns.length));
    expect(
      parsed[attendanceTimesheetColumns.indexOf('Employee')],
      'Amal, "A"',
    );
  });

  test('a no-show says so, and says no clock-in was recorded', () {
    final line = lines(
      buildAttendanceTimesheetCsv([
        row(
          outcome: AttendanceLedgerOutcome.absent,
          recordId: null,
          workedMinutes: 0,
        ),
      ]),
    )[1];

    expect(valueOf(line, 'Outcome'), 'Absent');
    expect(valueOf(line, 'Hours'), '0h');
    expect(valueOf(line, 'Clock-in recorded'), 'No');
  });

  test('an unscheduled shift is named, not left blank', () {
    // The absence of a scheduled window is what marks it (ADR-018); a blank
    // cell would read as missing data instead.
    final line = lines(
      buildAttendanceTimesheetCsv([
        row(unscheduled: true),
      ]),
    )[1];

    expect(valueOf(line, 'Scheduled'), 'Unscheduled');
  });

  test('issues are readable labels, never wire codes', () {
    final line = lines(
      buildAttendanceTimesheetCsv([
        row(
          exceptionCodes: const [
            AttendanceExceptionCode.late,
            AttendanceExceptionCode.overtime,
          ],
        ),
      ]),
    )[1];

    expect(valueOf(line, 'Issues'), 'Late · Overtime');
  });

  test('a uid stands in when a row carries no name', () {
    final line = lines(
      buildAttendanceTimesheetCsv([row(userName: null, userId: 'uid-9')]),
    )[1];
    expect(valueOf(line, 'Employee'), 'uid-9');
  });

  test('the file is CRLF-terminated with one line per shift', () {
    final csv = buildAttendanceTimesheetCsv([row(), row(userId: 'u2')]);
    expect(csv.endsWith('\r\n'), isTrue);
    expect(lines(csv), hasLength(3));
  });

  test('the filename is findable and safe', () {
    final name = attendanceTimesheetFilename(
      'Drop The Shop | Arkan',
      DateTime(2026, 7, 26),
    );
    expect(name, 'attendance-Drop-The-Shop-Arkan-20260726.csv');
    expect(
      attendanceTimesheetFilename('   ', DateTime(2026, 7, 26)),
      'attendance-branch-20260726.csv',
    );
  });

  test('csvEscape handles the cases that corrupt a spreadsheet', () {
    expect(csvEscape('Amal, A'), '"Amal, A"');
    expect(csvEscape('He said "hi"'), '"He said ""hi"""');
    expect(csvEscape('line\nbreak'), '"line\nbreak"');
    expect(csvEscape(null), '');
    expect(csvEscape(0), '0');
  });
}
