import 'package:opshub/features/attendance/domain/attendance_id.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_ledger_row.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_period.dart';

/// A manager's statement that they looked at a branch-week ([ADR-019]).
///
/// **An assertion, not a lock.** Nothing is restricted by it: no write is
/// rejected, no rule enforces it, no period becomes immutable. It records that a
/// named person reviewed this week on this date — and that is the whole feature.
///
/// **Orthogonal to `AttendanceCoverageStatus`, and never to be merged with it.**
/// Coverage answers *is the record complete?* and is computed. Review answers
/// *has a person signed off?* and cannot be computed — a week can be Settled and
/// never opened by anyone. Letting either imply the other is the exact defect
/// this redesign started from, where "Fully closed" was rendered over a week
/// that was 86% empty.
class AttendanceWeekReview {
  const AttendanceWeekReview({
    required this.branchId,
    required this.weekStartKey,
    required this.reviewedBy,
    required this.reviewedByName,
    required this.reviewedAt,
    this.note,
  });

  final String branchId;

  /// `yyyyMMdd` of the week's Sunday — the roster week, so review lines up with
  /// the denominator the report is built on.
  final String weekStartKey;

  final String reviewedBy;
  final String? reviewedByName;
  final DateTime reviewedAt;
  final String? note;

  /// Deterministic id, so reviewing twice updates rather than duplicates.
  static String idFor(String branchId, DateTime weekStart) =>
      '${branchId}_${attendanceDayKey(weekStart)}';

  String get id => idFor(branchId, weekStart);

  DateTime get weekStart =>
      parseAttendanceDayKey(weekStartKey) ?? DateTime.fromMillisecondsSinceEpoch(0);

  /// Who to show. Falls back to the uid rather than an empty string: an
  /// unreadable attribution still beats an anonymous one.
  String get displayName {
    final name = reviewedByName?.trim();
    return (name == null || name.isEmpty) ? reviewedBy : name;
  }
}

/// The review state of one week, as the report renders it.
class AttendanceWeekReviewState {
  const AttendanceWeekReviewState({
    required this.review,
    required this.changedSinceReview,
  });

  /// Never reviewed.
  const AttendanceWeekReviewState.none()
    : review = null,
      changedSinceReview = 0;

  final AttendanceWeekReview? review;

  /// Ledger rows touched after the review was recorded.
  final int changedSinceReview;

  bool get isReviewed => review != null;
  bool get hasChangedSince => changedSinceReview > 0;

  /// Resolve against the week's rows.
  ///
  /// **Post-review change detection is derived, not versioned** ([ADR-019]).
  /// A row whose `restatedAt`/`closedAt` is later than `reviewedAt` was touched
  /// after the sign-off. That is a timestamp comparison over data already
  /// stored, and it delivers *"later changes are intentional and visible"*
  /// without a history collection.
  factory AttendanceWeekReviewState.resolve({
    required AttendanceWeekReview? review,
    required List<AttendanceLedgerRow> rows,
  }) {
    if (review == null) return const AttendanceWeekReviewState.none();
    final at = review.reviewedAt;
    var changed = 0;
    for (final row in rows) {
      final touched = row.restatedAt ?? row.closedAt;
      if (touched != null && touched.isAfter(at)) changed++;
    }
    return AttendanceWeekReviewState(review: review, changedSinceReview: changed);
  }

  /// The line under the week's title. Deliberately states the review and the
  /// changes as two facts, never as one verdict.
  String get label {
    final r = review;
    if (r == null) return 'Not reviewed yet';
    if (changedSinceReview == 0) return 'Reviewed by ${r.displayName}';
    return 'Reviewed by ${r.displayName} · $changedSinceReview '
        '${changedSinceReview == 1 ? 'change' : 'changes'} since';
  }
}

/// The review id for the week containing [date].
String weekReviewIdFor(String branchId, DateTime date) =>
    AttendanceWeekReview.idFor(branchId, weeklyWindow(date).startDate);
