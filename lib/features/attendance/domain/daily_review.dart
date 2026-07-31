import 'package:drop/features/attendance/domain/attendance_board.dart';

/// What kind of decision a Daily Review row is asking for.
///
/// **Ordered by cost of being wrong**, and the enum order *is* the display
/// order. A missing clock-in means real work may go unpaid; a no-show is a
/// coverage fact someone already noticed. Priority is expressed by position, not
/// by a severity label — a manager never needs to read the word "blocking".
enum DailyReviewKind {
  /// Auto-closed or flagged: the system does not know when the shift ended, so
  /// the hours are unknown. Unknown hours are a payroll problem.
  missingClockOut,

  /// Rostered, the shift is over, nobody clocked in. Either they worked and
  /// forgot, or they did not come.
  noShow,
}

/// One thing a manager has to decide about one person.
class DailyReviewItem {
  const DailyReviewItem({
    required this.kind,
    required this.row,
    required this.headline,
    required this.detail,
  });

  final DailyReviewKind kind;
  final AttendanceBoardRow row;

  /// Names a person and states a plain fact. Never a record id, never a code.
  final String headline;
  final String detail;
}

/// The day, reduced to what a manager has to do about it.
///
/// Pure: derived from an already-computed [AttendanceBoard], so it adds no read,
/// no denominator, and no minute math. `AttendanceCalculator` remains the only
/// source of minutes.
class DailyReview {
  const DailyReview({
    required this.items,
    required this.scheduled,
    required this.worked,
    required this.lateArrivals,
  });

  factory DailyReview.fromBoard(AttendanceBoard board) {
    final items = <DailyReviewItem>[];

    for (final row in board.rows) {
      if (row.status == AttendanceBoardStatus.pendingReview) {
        items.add(
          DailyReviewItem(
            kind: DailyReviewKind.missingClockOut,
            row: row,
            headline: "${row.name} didn't clock out",
            detail: 'We do not know when this shift ended, so the hours are '
                'unconfirmed.',
          ),
        );
      } else if (row.status == AttendanceBoardStatus.absent) {
        items.add(
          DailyReviewItem(
            kind: DailyReviewKind.noShow,
            row: row,
            headline: '${row.name} was scheduled but never clocked in',
            detail: 'Either they worked and forgot to clock in, or they were '
                'absent.',
          ),
        );
      }
    }

    items.sort((a, b) {
      final byKind = a.kind.index.compareTo(b.kind.index);
      if (byKind != 0) return byKind;
      return a.row.name.toLowerCase().compareTo(b.row.name.toLowerCase());
    });

    // Excused and on-leave rows are not expected to work, so they are not part
    // of the day's denominator — the same exclusion the reporting summary makes.
    final scheduled = board.rows
        .where(
          (r) =>
              r.status != AttendanceBoardStatus.onLeave &&
              r.status != AttendanceBoardStatus.excused,
        )
        .length;
    final worked = board.rows
        .where(
          (r) =>
              r.status == AttendanceBoardStatus.working ||
              r.status == AttendanceBoardStatus.completed ||
              r.status == AttendanceBoardStatus.pendingReview,
        )
        .length;

    return DailyReview(
      items: List.unmodifiable(items),
      scheduled: scheduled,
      worked: worked,
      lateArrivals: board.rows
          .where((r) => r.isLate && r.record != null)
          .length,
    );
  }

  final List<DailyReviewItem> items;
  final int scheduled;
  final int worked;
  final int lateArrivals;

  bool get isClean => items.isEmpty;

  /// Counts, never a percentage — a single store-day is the smallest sample in
  /// the product, and a rate over it is the least trustworthy number we could
  /// show (`ATTENDANCE_REPORTS_IA` §6.5).
  String get summaryLine {
    if (scheduled == 0) return 'No shifts scheduled';
    return '$worked of $scheduled ${scheduled == 1 ? 'shift' : 'shifts'} '
        'worked';
  }
}

/// The outcome word for one person in the collapsed "Everyone" list.
String dailyOutcomeLabel(AttendanceBoardRow row) => switch (row.status) {
  AttendanceBoardStatus.completed => row.isLate ? 'Worked, late' : 'Worked',
  AttendanceBoardStatus.working => 'Still clocked in',
  AttendanceBoardStatus.pendingReview => 'Needs review',
  AttendanceBoardStatus.absent => 'Absent',
  AttendanceBoardStatus.excused => 'Excused',
  AttendanceBoardStatus.onLeave => 'On leave',
  AttendanceBoardStatus.late => 'Late, not in yet',
  AttendanceBoardStatus.notStarted => 'Not started',
};
