import 'package:drop/features/sales/domain/entities/branch_sales_month_entity.dart';
import 'package:drop/features/sales/domain/entities/daily_sales_submission_entity.dart';
import 'package:drop/features/sales/domain/entities/sales_month_snapshot.dart';

/// Read surface for the branch monthly-sales ledger. Writes arrive in P2/P3.
abstract class SalesRepository {
  Stream<BranchSalesMonthEntity?> watchMonth(String branchId, String monthKey);
  Stream<List<DailySalesSubmissionEntity>> watchSubmissions(
    String branchId,
    String monthKey,
  );
  Stream<DailySalesSubmissionEntity?> watchSubmission(String id);
  Stream<List<SalesMonthSnapshot>> watchBranchMonthSummaries(String monthKey);
}
