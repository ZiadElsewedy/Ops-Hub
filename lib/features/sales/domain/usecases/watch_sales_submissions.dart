import 'package:opshub/features/sales/domain/entities/daily_sales_submission_entity.dart';
import 'package:opshub/features/sales/domain/repositories/sales_repository.dart';

/// Watches one branch-month's daily submissions.
class WatchSalesSubmissions {
  const WatchSalesSubmissions(this._repository);
  final SalesRepository _repository;

  Stream<List<DailySalesSubmissionEntity>> call(
    String branchId,
    String monthKey,
  ) => _repository.watchSubmissions(branchId, monthKey);
}
