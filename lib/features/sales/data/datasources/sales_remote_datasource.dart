import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:drop/core/constants/app_constants.dart';
import 'package:drop/core/errors/exceptions.dart';
import 'package:drop/features/sales/data/models/branch_sales_month_model.dart';
import 'package:drop/features/sales/data/models/daily_sales_submission_model.dart';
import 'package:drop/features/sales/domain/sales_submission_id.dart';

abstract class SalesRemoteDataSource {
  Stream<BranchSalesMonthModel?> watchMonth(String branchId, String monthKey);
  Stream<List<DailySalesSubmissionModel>> watchSubmissions(
    String branchId,
    String monthKey,
  );
  Stream<DailySalesSubmissionModel?> watchSubmission(String id);
  Stream<List<BranchSalesMonthModel>> watchMonths(String monthKey);
  Stream<List<DailySalesSubmissionModel>> watchMonthSubmissions(
    String monthKey,
  );
  Future<void> submitDailySales({required String branchId, required String monthKey, required String businessDateKey, required int amountPiastres, required String submittedById, required String submittedByName});
  Future<void> setBranchTarget({required String branchId, required String monthKey, required int targetPiastres, required String reason, int? expectedTargetRevision});
  Future<void> decideSubmission({required String submissionId, required String action, String? reason});
  Future<void> editApprovedSubmission({required String submissionId, required int amountPiastres, required String reason, required int expectedRevision});
  Future<void> resubmitCorrectedSales({required String submissionId, required int amountPiastres});
}

class SalesRemoteDataSourceImpl implements SalesRemoteDataSource {
  SalesRemoteDataSourceImpl(this._firestore, this._functions);
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _months =>
      _firestore.collection(AppConstants.branchSalesMonthsCollection);
  CollectionReference<Map<String, dynamic>> get _submissions =>
      _firestore.collection(AppConstants.branchSalesSubmissionsCollection);

  @override
  Stream<BranchSalesMonthModel?> watchMonth(String branchId, String monthKey) =>
      _withServerErrors(
        _months
            .doc('${branchId}_$monthKey')
            .snapshots()
            .map(
              (snapshot) => snapshot.exists
                  ? BranchSalesMonthModel.fromMap(
                      snapshot.data()!,
                      id: snapshot.id,
                    )
                  : null,
            ),
      );

  @override
  Stream<List<DailySalesSubmissionModel>> watchSubmissions(
    String branchId,
    String monthKey,
  ) => _withServerErrors(
    _submissions
        .where('branchId', isEqualTo: branchId)
        .where('monthKey', isEqualTo: monthKey)
        .orderBy('businessDateKey', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) =>
                    DailySalesSubmissionModel.fromMap(doc.data(), id: doc.id),
              )
              .toList(),
        ),
  );

  @override
  Stream<DailySalesSubmissionModel?> watchSubmission(String id) =>
      _withServerErrors(
        _submissions
            .doc(id)
            .snapshots()
            .map(
              (snapshot) => snapshot.exists
                  ? DailySalesSubmissionModel.fromMap(
                      snapshot.data()!,
                      id: snapshot.id,
                    )
                  : null,
            ),
      );

  @override
  Stream<List<BranchSalesMonthModel>> watchMonths(String monthKey) =>
      _withServerErrors(
        _months
            .where('monthKey', isEqualTo: monthKey)
            .snapshots()
            .map(
              (snapshot) => snapshot.docs
                  .map(
                    (doc) =>
                        BranchSalesMonthModel.fromMap(doc.data(), id: doc.id),
                  )
                  .toList(),
            ),
      );

  @override
  Stream<List<DailySalesSubmissionModel>> watchMonthSubmissions(
    String monthKey,
  ) => _withServerErrors(
    _submissions
        .where('monthKey', isEqualTo: monthKey)
        .orderBy('businessDateKey', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) =>
                    DailySalesSubmissionModel.fromMap(doc.data(), id: doc.id),
              )
              .toList(),
        ),
  );

  @override
  Future<void> submitDailySales({required String branchId, required String monthKey, required String businessDateKey, required int amountPiastres, required String submittedById, required String submittedByName}) async {
    final id = salesSubmissionId(branchId, businessDateKey);
    try {
      // This is deliberately the complete rules whitelist: do not add fields.
      await _submissions.doc(id).set({
        'id': id, 'branchId': branchId, 'monthKey': monthKey,
        'businessDateKey': businessDateKey, 'businessTimeZone': 'Africa/Cairo',
        'amountPiastres': amountPiastres, 'status': 'pending',
        'submittedById': submittedById, 'submittedByName': submittedByName,
        'submittedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp(),
        'schemaVersion': 1,
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw const ServerException('This day was already submitted or you are not allowed to submit it.');
      throw ServerException(e.message ?? 'Failed to submit daily sales.');
    }
  }

  @override
  Future<void> setBranchTarget({required String branchId, required String monthKey, required int targetPiastres, required String reason, int? expectedTargetRevision}) => _call('setBranchSalesTarget', {'branchId': branchId, 'monthKey': monthKey, 'targetPiastres': targetPiastres, 'reason': reason, 'expectedTargetRevision': ?expectedTargetRevision}, fallback: 'Couldn’t set the sales target right now. Please try again.');

  @override
  Future<void> decideSubmission({required String submissionId, required String action, String? reason}) => _call('decideDailySalesSubmission', {'submissionId': submissionId, 'action': action, 'reason': ?reason}, fallback: 'Couldn’t update the sales submission right now. Please try again.');

  @override
  Future<void> editApprovedSubmission({required String submissionId, required int amountPiastres, required String reason, required int expectedRevision}) => _call('editApprovedDailySalesSubmission', {'submissionId': submissionId, 'amountPiastres': amountPiastres, 'reason': reason, 'expectedRevision': expectedRevision}, fallback: 'Couldn’t edit the approved sales amount right now. Please try again.');

  @override
  Future<void> resubmitCorrectedSales({required String submissionId, required int amountPiastres}) => _call('resubmitCorrectedSales', {'submissionId': submissionId, 'amountPiastres': amountPiastres}, fallback: 'Couldn’t resubmit the corrected sales right now. Please try again.');

  Future<void> _call(String name, Map<String, dynamic> data, {required String fallback}) async {
    try {
      await _functions.httpsCallable(name).call<Map<String, dynamic>>(data);
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(_friendlyFunctionsError(e, fallback));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? fallback);
    }
  }

  String _friendlyFunctionsError(FirebaseFunctionsException e, String fallback) {
    final message = (e.message ?? '').trim();
    if (message.contains(' ')) return message;
    switch (e.code) {
      case 'unavailable': return 'Network problem — check your connection and try again.';
      case 'not-found': return 'The sales service isn’t available yet. Please try again later.';
      case 'unauthenticated':
      case 'permission-denied': return 'You are not allowed to make this sales change.';
      default: return fallback;
    }
  }

  Stream<T> _withServerErrors<T>(Stream<T> stream) =>
      stream.handleError((error) {
        if (error is FirebaseException) {
          throw ServerException(error.message ?? 'Failed to load sales data.');
        }
        throw error;
      });
}
