import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/attendance_status_filter.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/features/attendance/domain/attendance_history_gap.dart';
import 'package:drop/features/attendance/domain/attendance_history_query.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_ledger_row.dart';

/// The reported bug, exactly: an admin searched "ziad", the summary strip said
/// **1 Absent**, and the list underneath said **"No matches — try widening the
/// date range"**. The range was fine. Absences are never materialized (spec
/// R13), so a list built only from records cannot show the day being asked
/// about.
void main() {
  AttendanceLedgerRow row({
    String userId = 'ziad',
    String? userName = 'Ziad Elsewedy',
    String dayKey = '20260731',
    ScheduleShift shift = ScheduleShift.morning,
    AttendanceLedgerOutcome outcome = AttendanceLedgerOutcome.absent,
    bool expected = true,
    String? recordId,
  }) => AttendanceLedgerRow(
    id: '${userId}_${dayKey}_${shift.name}',
    rowId: '${userId}_${dayKey}_${shift.name}',
    userId: userId,
    userName: userName,
    branchId: 'arkan',
    dayKey: dayKey,
    businessDate: '2026-07-31',
    shift: shift,
    outcome: outcome,
    expected: expected,
    recordId: recordId,
    workedMinutes: 0,
    exceptionCodes: const [],
    locked: false,
    version: 1,
    source: 'system',
  );

  List<AttendanceHistoryGap> gaps(
    List<AttendanceLedgerRow> ledger, {
    AttendanceHistoryQuery query = const AttendanceHistoryQuery(),
  }) => attendanceHistoryGaps(ledger: ledger, query: query);

  test('an absence with no record still shows up', () {
    final result = gaps([row()]);

    expect(result, hasLength(1));
    expect(result.single.userName, 'Ziad Elsewedy');
    expect(result.single.label, 'Absent');
    expect(result.single.date, DateTime(2026, 7, 31));
  });

  test('searching that person by name finds the absence', () {
    // The exact reproduction: the owner typed "ziad" and got nothing.
    final result = gaps([
      row(),
      row(userId: 'salama', userName: 'Salama', dayKey: '20260730'),
    ], query: const AttendanceHistoryQuery(text: 'ziad'));

    expect(result, hasLength(1));
    expect(result.single.userId, 'ziad');
  });

  test('a shift that produced a record is never duplicated', () {
    // It is already in the record list; showing it twice is worse than not
    // showing it at all.
    expect(gaps([row(recordId: 'ziad_20260731_morning')]), isEmpty);
  });

  test('an unrostered row with no record describes nothing', () {
    expect(gaps([row(expected: false)]), isEmpty);
  });

  test('the status facet still narrows', () {
    final ledger = [
      row(),
      row(dayKey: '20260730', outcome: AttendanceLedgerOutcome.excused),
      row(dayKey: '20260729', outcome: AttendanceLedgerOutcome.onLeave),
    ];

    expect(
      gaps(
        ledger,
        query: const AttendanceHistoryQuery(
          statuses: {AttendanceStatusFilter.absent},
        ),
      ).map((g) => g.label),
      ['Absent'],
    );
    expect(
      gaps(
        ledger,
        query: const AttendanceHistoryQuery(
          statuses: {AttendanceStatusFilter.excused},
        ),
      ).map((g) => g.label),
      ['Excused'],
    );
    // Asking for "Late" is asking about a record, so no gap can answer it.
    expect(
      gaps(
        ledger,
        query: const AttendanceHistoryQuery(
          statuses: {AttendanceStatusFilter.late},
        ),
      ),
      isEmpty,
    );
    // OR across the set: Absent + Excused surfaces both kinds of gap.
    expect(
      gaps(
        ledger,
        query: const AttendanceHistoryQuery(
          statuses: {
            AttendanceStatusFilter.absent,
            AttendanceStatusFilter.excused,
          },
        ),
      ).map((g) => g.label).toSet(),
      {'Absent', 'Excused'},
    );
  });

  test('the shift facet still narrows', () {
    final ledger = [
      row(),
      row(dayKey: '20260730', shift: ScheduleShift.night),
    ];

    expect(
      gaps(
        ledger,
        query: const AttendanceHistoryQuery(shifts: {ScheduleShift.night}),
      ).single.shift,
      ScheduleShift.night,
    );
  });

  test('newest first, matching the record list', () {
    final result = gaps([
      row(dayKey: '20260729'),
      row(dayKey: '20260731'),
      row(dayKey: '20260730'),
    ]);

    expect(
      result.map((g) => g.date.day).toList(),
      [31, 30, 29],
    );
  });

  test('a malformed day key is skipped rather than crashing the ledger', () {
    expect(gaps([row(dayKey: 'not-a-day')]), isEmpty);
  });
}
