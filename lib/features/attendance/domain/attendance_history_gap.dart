import 'package:drop/core/enums/attendance_status_filter.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/features/attendance/domain/attendance_history_query.dart';
import 'package:drop/features/attendance/domain/attendance_id.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_ledger_row.dart';

/// A rostered shift that produced **no attendance record**.
///
/// Absences are deliberately never materialized — spec R13, *"Absent stays
/// virtual until a manager excuses/creates or an employee files a missed-punch.
/// No phantom documents."* That is the right storage decision and the wrong
/// reading decision: the History ledger lists records, so the one day a manager
/// is actually asking about is the one day that renders nothing.
///
/// The screen showed the contradiction plainly — the summary strip reads the
/// expectation ledger and said **"1 Absent"** while the list underneath said
/// **"No matches"** and advised widening the date range. Nothing was wrong with
/// the range.
///
/// A gap carries only what the ledger already knows, so it adds no read and no
/// minute math. It is not an [AttendanceEntity] and must never be written.
class AttendanceHistoryGap {
  const AttendanceHistoryGap({
    required this.userId,
    required this.userName,
    required this.date,
    required this.shift,
    required this.outcome,
  });

  final String userId;
  final String? userName;
  final DateTime date;
  final ScheduleShift shift;
  final AttendanceLedgerOutcome outcome;

  /// Plain language for the row. Never a code, never "no record found".
  String get label => switch (outcome) {
    AttendanceLedgerOutcome.absent => 'Absent',
    AttendanceLedgerOutcome.excused => 'Excused',
    AttendanceLedgerOutcome.onLeave => 'On leave',
    _ => 'No record',
  };
}

/// The rostered shifts in [ledger] that have no record, narrowed by the same
/// facets the record list uses so the two halves of the screen can never
/// disagree again.
///
/// Pure: no Flutter, no Firestore, no clock. The caller passes the already
/// streamed ledger rows (the summary strip is watching them anyway).
List<AttendanceHistoryGap> attendanceHistoryGaps({
  required List<AttendanceLedgerRow> ledger,
  required AttendanceHistoryQuery query,
}) {
  final text = query.text.trim().toLowerCase();
  final gaps = <AttendanceHistoryGap>[];

  for (final row in ledger) {
    // A row with a record is already in the list; showing it twice would be
    // worse than not showing it at all.
    if (row.recordId != null) continue;
    // Only a shift somebody was rostered for is a gap. An unexpected row with
    // no record describes nothing that happened.
    if (!row.expected) continue;
    if (!_outcomePassesStatus(row.outcome, query.status)) continue;
    if (query.shifts.isNotEmpty && !query.shifts.contains(row.shift)) continue;
    if (text.isNotEmpty && !(row.userName ?? '').toLowerCase().contains(text)) {
      continue;
    }

    final date = parseAttendanceDayKey(row.dayKey);
    if (date == null) continue;

    gaps.add(
      AttendanceHistoryGap(
        userId: row.userId,
        userName: row.userName,
        date: date,
        shift: row.shift,
        outcome: row.outcome,
      ),
    );
  }

  // Newest first, matching the record list's order.
  gaps.sort((a, b) => b.date.compareTo(a.date));
  return gaps;
}

/// A gap can only satisfy the facets that describe *not working*. Asking for
/// "Late" or "Overtime" is asking about a record, so gaps drop out entirely
/// rather than padding a filtered list with rows that cannot match it.
bool _outcomePassesStatus(
  AttendanceLedgerOutcome outcome,
  AttendanceStatusFilter status,
) => switch (status) {
  AttendanceStatusFilter.all => true,
  AttendanceStatusFilter.absent => outcome == AttendanceLedgerOutcome.absent,
  AttendanceStatusFilter.excused => outcome == AttendanceLedgerOutcome.excused,
  AttendanceStatusFilter.leave => outcome == AttendanceLedgerOutcome.onLeave,
  _ => false,
};
