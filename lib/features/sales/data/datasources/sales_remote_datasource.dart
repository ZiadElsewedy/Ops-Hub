import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drop/core/constants/app_constants.dart';
import 'package:drop/core/errors/exceptions.dart';
import 'package:drop/features/sales/data/models/branch_sales_month_model.dart';
import 'package:drop/features/sales/data/models/daily_sales_submission_model.dart';

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
}

class SalesRemoteDataSourceImpl implements SalesRemoteDataSource {
  SalesRemoteDataSourceImpl(this._firestore);
  final FirebaseFirestore _firestore;

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

  Stream<T> _withServerErrors<T>(Stream<T> stream) =>
      stream.handleError((error) {
        if (error is FirebaseException) {
          throw ServerException(error.message ?? 'Failed to load sales data.');
        }
        throw error;
      });
}
