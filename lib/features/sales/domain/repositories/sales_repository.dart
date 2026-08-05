import 'package:drop/features/sales/domain/entities/branch_sales_month_entity.dart';
import 'package:drop/features/sales/domain/entities/daily_sales_submission_entity.dart';
import 'package:drop/features/sales/domain/entities/sales_month_snapshot.dart';

abstract class SalesRepository {
  Stream<BranchSalesMonthEntity?> watchMonth(String branchId, String monthKey);
  Stream<List<DailySalesSubmissionEntity>> watchSubmissions(
    String branchId,
    String monthKey,
  );
  Stream<DailySalesSubmissionEntity?> watchSubmission(String id);
  Stream<List<SalesMonthSnapshot>> watchBranchMonthSummaries(String monthKey);
  Future<void> submitDailySales({required String branchId, required String monthKey, required String businessDateKey, required int amountPiastres, required String submittedById, required String submittedByName});
  Future<void> setBranchTarget({required String branchId, required String monthKey, required int targetPiastres, required String reason, int? expectedTargetRevision});
  Future<void> decideSubmission({required String submissionId, required String action, String? reason});
  Future<void> editApprovedSubmission({required String submissionId, required int amountPiastres, required String reason, required int expectedRevision});
  Future<void> resubmitCorrectedSales({required String submissionId, required int amountPiastres});
}
