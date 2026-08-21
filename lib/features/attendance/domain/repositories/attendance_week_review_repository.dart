import 'package:opshub/features/attendance/domain/reporting/attendance_week_review.dart';

/// Read/write contract for the week-review assertion ([ADR-019]).
///
/// Deliberately tiny: state a review, withdraw it, watch it. There is no
/// lifecycle, no versioning and no history — the moment this interface grows
/// those, the assertion has become the period lock ADR-019 declined to build.
abstract class AttendanceWeekReviewRepository {
  /// The review for one branch-week, or null when nobody has signed off.
  Stream<AttendanceWeekReview?> watchWeekReview({
    required String branchId,
    required DateTime weekStart,
  });

  /// State (or restate) the review. Idempotent on the deterministic id.
  Future<void> markReviewed(AttendanceWeekReview review);

  /// **Reopen** — withdraw the assertion. As legitimate as making it.
  Future<void> reopen({required String branchId, required DateTime weekStart});
}
