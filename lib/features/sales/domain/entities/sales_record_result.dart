/// The outcome of a manager/admin recording a day's sales directly, returned by
/// the `recordApprovedDailySales` callable. It drives the celebratory
/// confirmation: how much was added, the new approved total, and whether this
/// record is the one that reached the monthly target.
class SalesRecordResult {
  const SalesRecordResult({
    required this.amountPiastres,
    required this.achievedPiastres,
    required this.targetPiastres,
    required this.crossedTarget,
  });

  /// What was just added to the branch total.
  final int amountPiastres;

  /// The branch's approved total *after* this record.
  final int achievedPiastres;

  /// The month's target, for framing the confirmation.
  final int targetPiastres;

  /// True only when this record moved the branch from below to at/over target.
  final bool crossedTarget;
}
