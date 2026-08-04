import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drop/core/constants/app_constants.dart';
import 'package:drop/core/errors/exceptions.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_week_review.dart';
import 'package:drop/features/attendance/domain/repositories/attendance_week_review_repository.dart';

/// Firestore-backed week review.
///
/// **No separate datasource on purpose.** The document is five fields with no
/// mapping complexity and no query surface; a datasource layer here would be
/// indirection without a decision behind it. If it ever grows queries, split it
/// then.
class AttendanceWeekReviewRepositoryImpl
    implements AttendanceWeekReviewRepository {
  AttendanceWeekReviewRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(AppConstants.attendanceWeekReviewsCollection);

  @override
  Stream<AttendanceWeekReview?> watchWeekReview({
    required String branchId,
    required DateTime weekStart,
  }) {
    try {
      return _col
          .doc(AttendanceWeekReview.idFor(branchId, weekStart))
          .snapshots()
          .map((snap) {
            final data = snap.data();
            if (!snap.exists || data == null) return null;
            return _fromMap(data);
          });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to read the week review.');
    }
  }

  @override
  Future<void> markReviewed(AttendanceWeekReview review) async {
    try {
      await _col.doc(review.id).set({
        'branchId': review.branchId,
        'weekStartKey': review.weekStartKey,
        'reviewedBy': review.reviewedBy,
        'reviewedByName': review.reviewedByName,
        // The server clock decides when a review happened, exactly as it does
        // for a clock-in (spec R18) — a device clock must not be able to place
        // a sign-off before a change it actually followed.
        'reviewedAt': FieldValue.serverTimestamp(),
        'note': review.note,
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to save the review.');
    }
  }

  @override
  Future<void> reopen({
    required String branchId,
    required DateTime weekStart,
  }) async {
    try {
      await _col.doc(AttendanceWeekReview.idFor(branchId, weekStart)).delete();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to reopen the week.');
    }
  }

  static AttendanceWeekReview _fromMap(Map<String, dynamic> map) {
    final at = map['reviewedAt'];
    return AttendanceWeekReview(
      branchId: (map['branchId'] ?? '') as String,
      weekStartKey: (map['weekStartKey'] ?? '') as String,
      reviewedBy: (map['reviewedBy'] ?? '') as String,
      reviewedByName: map['reviewedByName'] as String?,
      // Null only in the instant between a local write and the server stamp
      // landing; treating that as "now" keeps the UI from flickering to
      // "Not reviewed" straight after a manager taps Review.
      reviewedAt: at is Timestamp ? at.toDate() : DateTime.now(),
      note: map['note'] as String?,
    );
  }
}
