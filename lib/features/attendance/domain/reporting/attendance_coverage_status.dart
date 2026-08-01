/// The status a **manager** reads on a period report.
///
/// One vocabulary, shared by Weekly and Monthly, so the same situation cannot be
/// described in two different words on two surfaces.
///
/// This replaces the close-pipeline vocabulary (*Awaiting close · Partially
/// closed · Fully closed*) at the manager boundary. The pipeline states still
/// exist and are still what the close Function computes — they are simply not a
/// store manager's language, and one of them was actively misleading:
/// `isFullyClosed` is true whenever *any* row exists and no row carries a
/// blocking exception, so a week with rows on one day out of seven reported
/// **Fully closed**. A period that is mostly empty is not closed, and saying so
/// is a trust claim the data does not support.
///
/// [dataGap] is therefore a first-class status: it is the honest answer for a
/// period whose days are not all accounted for, and it is deliberately *not*
/// [needsAttention] — a gap is not a blocker a manager can resolve.
enum AttendanceCoverageStatus {
  /// No rows at all. Never a `0%` result — there is no denominator yet.
  noData,

  /// Rows exist and something in them needs a human decision.
  needsAttention,

  /// Rows exist, nothing is blocked, but some business dates have no rows.
  dataGap,

  /// Rows for every business date, nothing blocked.
  settled;

  /// The word a manager sees.
  String get label => switch (this) {
    AttendanceCoverageStatus.noData => 'No data yet',
    AttendanceCoverageStatus.needsAttention => 'Needs attention',
    AttendanceCoverageStatus.dataGap => 'In progress',
    AttendanceCoverageStatus.settled => 'Settled',
  };

  /// Whether the status should be toned rather than rendered monochrome.
  ///
  /// Only [needsAttention] earns colour: it is the one status with work behind
  /// it. A gap and an empty period are ordinary conditions of a roster that has
  /// not been fully published yet, and colouring them is what made a week with
  /// six unscheduled days read as a catastrophe.
  bool get isActionable => this == AttendanceCoverageStatus.needsAttention;

  static AttendanceCoverageStatus resolve({
    required bool hasRows,
    required int blockingRowCount,
    required bool hasDayGaps,
  }) {
    if (!hasRows) return AttendanceCoverageStatus.noData;
    if (blockingRowCount > 0) return AttendanceCoverageStatus.needsAttention;
    if (hasDayGaps) return AttendanceCoverageStatus.dataGap;
    return AttendanceCoverageStatus.settled;
  }
}
