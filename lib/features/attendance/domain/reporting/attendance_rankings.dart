import 'package:drop/features/attendance/domain/reporting/attendance_exception.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_ledger_row.dart';

/// The metric a ranked "who has the most X" board is sorted by.
///
/// Each is a question an HR manager asks out loud — *"who has the highest
/// overtime this month?"* — that the flat report could only answer by scanning a
/// table. The values all already live on the reporting ledger, so a ranking adds
/// no read and no minute math.
enum AttendanceRankingMetric {
  overtime,
  lateness,
  absence,
  missingPunch,
  workedHours;

  /// The chip / tab label.
  String get label => switch (this) {
    AttendanceRankingMetric.overtime => 'Overtime',
    AttendanceRankingMetric.lateness => 'Lateness',
    AttendanceRankingMetric.absence => 'Absences',
    AttendanceRankingMetric.missingPunch => 'Missing punches',
    AttendanceRankingMetric.workedHours => 'Hours worked',
  };

  /// The one-line question this board answers — the section lead-in and the
  /// empty-state sentence.
  String get question => switch (this) {
    AttendanceRankingMetric.overtime => 'Who worked the most overtime?',
    AttendanceRankingMetric.lateness => 'Who was late the most?',
    AttendanceRankingMetric.absence => 'Who was absent the most?',
    AttendanceRankingMetric.missingPunch =>
      'Who is missing the most clock-outs?',
    AttendanceRankingMetric.workedHours => 'Who worked the most hours?',
  };

  /// Whether the value is a **duration in minutes** (rendered as hours/minutes)
  /// or a **count of shifts**.
  bool get isMinutes => switch (this) {
    AttendanceRankingMetric.overtime ||
    AttendanceRankingMetric.lateness ||
    AttendanceRankingMetric.workedHours => true,
    AttendanceRankingMetric.absence ||
    AttendanceRankingMetric.missingPunch => false,
  };

  /// The noun for a count metric (the caller pluralizes). Empty for a minutes
  /// metric.
  String get countNoun => switch (this) {
    AttendanceRankingMetric.absence => 'absence',
    AttendanceRankingMetric.missingPunch => 'missing punch',
    _ => '',
  };

  /// This row's contribution to the metric total (minutes, or 1 per matching
  /// shift for a count metric).
  int valueOf(AttendanceLedgerRow row) => switch (this) {
    AttendanceRankingMetric.overtime => row.overtimeMinutes,
    AttendanceRankingMetric.lateness => row.lateMinutes,
    AttendanceRankingMetric.workedHours => row.workedMinutes,
    AttendanceRankingMetric.absence => row.outcome.countsAsAbsence ? 1 : 0,
    AttendanceRankingMetric.missingPunch =>
      row.exceptionCodes.contains(AttendanceExceptionCode.missingPunch) ? 1 : 0,
  };
}

/// One employee's place on a ranked board.
class AttendanceRankingEntry {
  const AttendanceRankingEntry({
    required this.rank,
    required this.userId,
    required this.userName,
    required this.value,
  });

  /// 1-based position on the board.
  final int rank;
  final String userId;
  final String? userName;

  /// The summed metric value — minutes, or a shift count, per the metric.
  final int value;

  /// The display name, falling back to the uid so a row never renders blank.
  String get displayName =>
      (userName != null && userName!.trim().isNotEmpty) ? userName!.trim() : userId;

  @override
  bool operator ==(Object other) =>
      other is AttendanceRankingEntry &&
      other.rank == rank &&
      other.userId == userId &&
      other.userName == userName &&
      other.value == value;

  @override
  int get hashCode => Object.hash(rank, userId, userName, value);

  @override
  String toString() =>
      'AttendanceRankingEntry(#$rank $userId "$userName" = $value)';
}

/// Rank employees by [metric] over [rows] — the ledger of any period (a week, a
/// month, a custom window). Values are summed per employee; anyone whose total is
/// **zero is left off the board entirely**, because a leaderboard shows who *has*
/// the thing, not everyone with a nil count. Sorted highest first, ties broken by
/// name then uid for a stable order, and capped at [limit] (`0` = no cap).
///
/// Pure — no Flutter, no Firestore, no clock — so it is unit-tested directly and
/// recomputes instantly as the report stream updates. Unscheduled rows are kept:
/// their overtime and hours are real work.
List<AttendanceRankingEntry> attendanceRankings({
  required List<AttendanceLedgerRow> rows,
  required AttendanceRankingMetric metric,
  int limit = 5,
}) {
  final totals = <String, int>{};
  final names = <String, String?>{};
  for (final row in rows) {
    totals[row.userId] = (totals[row.userId] ?? 0) + metric.valueOf(row);
    // Keep the first non-empty name we see for the uid; the ledger denormalizes
    // it per row, and a phantom no-show row may carry none.
    if ((names[row.userId] ?? '').trim().isEmpty) {
      names[row.userId] = row.userName;
    }
  }

  final scored = <AttendanceRankingEntry>[
    for (final entry in totals.entries)
      if (entry.value > 0)
        AttendanceRankingEntry(
          rank: 0, // assigned after the sort
          userId: entry.key,
          userName: names[entry.key],
          value: entry.value,
        ),
  ];

  scored.sort((a, b) {
    final byValue = b.value.compareTo(a.value);
    if (byValue != 0) return byValue;
    final byName = a.displayName.toLowerCase().compareTo(
      b.displayName.toLowerCase(),
    );
    return byName != 0 ? byName : a.userId.compareTo(b.userId);
  });

  final capped = limit > 0 ? scored.take(limit).toList() : scored;
  return [
    for (var i = 0; i < capped.length; i++)
      AttendanceRankingEntry(
        rank: i + 1,
        userId: capped[i].userId,
        userName: capped[i].userName,
        value: capped[i].value,
      ),
  ];
}
