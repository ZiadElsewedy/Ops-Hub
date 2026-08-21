import 'package:opshub/features/attendance/domain/attendance_id.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_coverage_status.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_ledger_row.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_period.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_report.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_weekly_report.dart';

/// One branch's week, as an admin reads it.
class AdminBranchWeek {
  const AdminBranchWeek({
    required this.branchId,
    required this.branchName,
    required this.report,
  });

  final String branchId;
  final String branchName;
  final WeeklyAttendanceReport report;

  AttendanceCoverageStatus get status => report.coverage.status;
  int get daysCovered => report.coverage.closedDayCount;
  int get daysTotal => report.coverage.totalDayCount;
  int get blockingRows => report.coverage.ledgerCoverage.blockingExceptionRowCount;

  /// Business dates with nothing recorded. **A gap, not a result** — the ledger
  /// cannot tell "nobody was scheduled" from "scheduled and never captured", so
  /// chasing it is exactly the admin's job and not the store's.
  List<String> get missingDayKeys => report.coverage.notClosedDayKeys;

  /// How stale the oldest unresolved blocker is, against [asOf]. Null when
  /// nothing is blocked.
  ///
  /// This is what turns "a branch has an open item" into "a branch has stopped
  /// settling its days", which is the only version of the fact an admin can act
  /// on — a manager cannot be chased for something they cleared yesterday.
  int? oldestBlockerAgeDays(DateTime asOf) {
    DateTime? oldest;
    for (final day in report.days) {
      if (day.blockingExceptionCount == 0) continue;
      if (oldest == null || day.date.isBefore(oldest)) oldest = day.date;
    }
    if (oldest == null) return null;
    final asOfDate = DateTime(asOf.year, asOf.month, asOf.day);
    return asOfDate.difference(oldest).inDays;
  }
}

/// The admin's cross-branch view of one week.
///
/// **This is where a rate finally earns its denominator.** Show-up rate left the
/// store surface in Phase 1 because at one expected shift `0%` is meaningless
/// and alarming (`ATTENDANCE_REPORTS_IA` §6.5). Across every branch there is
/// enough volume for a percentage to mean something, and comparing branches is a
/// question only an admin has.
///
/// Pure: folded from ledger rows that were already read. It adds no query, no
/// denominator of its own, and no minute math.
class AdminAttendanceOverview {
  const AdminAttendanceOverview({
    required this.window,
    required this.branches,
    required this.summary,
    required this.rows,
  });

  /// [rowsByBranch] is one branch's ledger rows per entry; [namesByBranchId]
  /// supplies display names, falling back to the id.
  factory AdminAttendanceOverview.fromBranchRows({
    required AttendancePeriodWindow window,
    required Map<String, List<AttendanceLedgerRow>> rowsByBranch,
    Map<String, String> namesByBranchId = const {},
  }) {
    final branches = <AdminBranchWeek>[];
    final all = <AttendanceLedgerRow>[];

    for (final entry in rowsByBranch.entries) {
      all.addAll(entry.value);
      branches.add(
        AdminBranchWeek(
          branchId: entry.key,
          branchName: namesByBranchId[entry.key] ?? entry.key,
          report: WeeklyAttendanceReport.fromLedger(
            rows: entry.value,
            window: window,
          ),
        ),
      );
    }

    // Worst first: blocked before incomplete before settled, then by how much
    // of the week is missing, then alphabetically. An admin opens this to find
    // the branch that needs help, not to read a directory.
    branches.sort((a, b) {
      final byStatus = _statusRank(a.status).compareTo(_statusRank(b.status));
      if (byStatus != 0) return byStatus;
      final byGap = b.missingDayKeys.length.compareTo(a.missingDayKeys.length);
      if (byGap != 0) return byGap;
      return a.branchName.toLowerCase().compareTo(b.branchName.toLowerCase());
    });

    return AdminAttendanceOverview(
      window: window,
      branches: List.unmodifiable(branches),
      // One summary over the union of every branch's rows — the same fold the
      // single-branch report uses, so the cross-branch rate cannot drift from
      // the per-branch ones.
      summary: AttendanceReportSummary.fromLedger(all),
      rows: List.unmodifiable(all..sort(_byDayThenBranch)),
    );
  }

  final AttendancePeriodWindow window;
  final List<AdminBranchWeek> branches;
  final AttendanceReportSummary summary;

  /// Every row in the period, across branches — the relocated evidence table.
  final List<AttendanceLedgerRow> rows;

  bool get hasRows => rows.isNotEmpty;

  /// Branches whose week is not yet whole. The count an admin is accountable
  /// for, and the reason this surface exists.
  List<AdminBranchWeek> get incompleteBranches => branches
      .where((b) => b.status != AttendanceCoverageStatus.settled)
      .toList();

  /// Branches that have stopped settling their days. [staleAfterDays] defaults
  /// to 2 — a manager gets the day itself plus the next one before an admin
  /// treats silence as a signal.
  List<AdminBranchWeek> escalations(DateTime asOf, {int staleAfterDays = 2}) => [
    for (final branch in branches)
      if ((branch.oldestBlockerAgeDays(asOf) ?? -1) >= staleAfterDays) branch,
  ];

  static int _statusRank(AttendanceCoverageStatus status) => switch (status) {
    AttendanceCoverageStatus.needsAttention => 0,
    AttendanceCoverageStatus.noData => 1,
    AttendanceCoverageStatus.dataGap => 2,
    AttendanceCoverageStatus.settled => 3,
  };

  static int _byDayThenBranch(AttendanceLedgerRow a, AttendanceLedgerRow b) {
    final byDay = a.dayKey.compareTo(b.dayKey);
    if (byDay != 0) return byDay;
    final byBranch = a.branchId.compareTo(b.branchId);
    if (byBranch != 0) return byBranch;
    return a.id.compareTo(b.id);
  }
}

/// The business dates in [window], as `yyyyMMdd` keys.
List<String> windowDayKeys(AttendancePeriodWindow window) {
  final out = <String>[];
  var date = DateTime(
    window.startDate.year,
    window.startDate.month,
    window.startDate.day,
  );
  final end = DateTime(
    window.endDate.year,
    window.endDate.month,
    window.endDate.day,
  );
  while (!date.isAfter(end)) {
    out.add(attendanceDayKey(date));
    date = DateTime(date.year, date.month, date.day + 1);
  }
  return out;
}
