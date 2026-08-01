/// What a report row hands to the branch-review ledger when it is opened.
///
/// A "By person" row is read *inside a period* — a specific branch and a
/// specific week or month. Carrying only the name would drop both, landing the
/// reviewer on their own branch's default window and quietly showing different
/// numbers than the row they tapped. This keeps the question intact: **this
/// person, this branch, these dates.**
///
/// Pure Dart (no Flutter, no Firestore) so the router, the screen and the tests
/// all share one shape.
class AttendanceReviewLink {
  const AttendanceReviewLink({
    required this.employeeName,
    this.branchId,
    this.start,
    this.end,
  });

  /// Matched case-insensitively against the record's denormalized `userName`.
  final String employeeName;

  /// The branch the report was read in. Null falls back to the viewer's own
  /// branch (a manager) or the first branch (an admin), as before.
  final String? branchId;

  /// The report period. Both must be present to pin the window; either one
  /// missing leaves the ledger on its default range rather than half-applying
  /// a bound.
  final DateTime? start;
  final DateTime? end;

  bool get hasWindow => start != null && end != null;
}
