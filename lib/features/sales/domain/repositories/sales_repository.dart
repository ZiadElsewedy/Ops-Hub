import 'package:opshub/features/sales/domain/entities/branch_sales_month_entity.dart';
import 'package:opshub/features/sales/domain/entities/daily_sales_submission_entity.dart';
import 'package:opshub/features/sales/domain/entities/sales_month_snapshot.dart';
import 'package:opshub/features/sales/domain/entities/sales_record_result.dart';

abstract class SalesRepository {
  Stream<BranchSalesMonthEntity?> watchMonth(String branchId, String monthKey);
  Stream<List<DailySalesSubmissionEntity>> watchSubmissions(
    String branchId,
    String monthKey,
  );
  Stream<List<DailySalesSubmissionEntity>> watchApprovedSubmissions(
    String branchId,
    String monthKey,
  );
  Stream<List<DailySalesSubmissionEntity>> watchOwnSubmissions(
    String branchId,
    String monthKey,
    String submittedById,
  );
  Stream<DailySalesSubmissionEntity?> watchSubmission(String id);
  Stream<List<SalesMonthSnapshot>> watchBranchMonthSummaries(String monthKey);
  Future<void> submitDailySales({required String branchId, required String monthKey, required String businessDateKey, required int amountPiastres, required String submittedById, required String submittedByName});
  Future<SalesRecordResult> recordDailySales({required String branchId, required int amountPiastres, String? businessDateKey, String? reason});
  Future<void> setBranchTarget({required String branchId, required String monthKey, required int targetPiastres, required String reason, int? expectedTargetRevision});
  Future<void> decideSubmission({required String submissionId, required String action, String? reason});
  Future<void> editApprovedSubmission({required String submissionId, required int amountPiastres, required String reason, required int expectedRevision});
  Future<void> resubmitCorrectedSales({required String submissionId, required int amountPiastres});
}
