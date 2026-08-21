import 'package:opshub/features/sales/domain/entities/sales_month_snapshot.dart';
import 'package:opshub/features/sales/domain/repositories/sales_repository.dart';
import 'package:opshub/features/sales/domain/sales_business_time.dart';

/// Watches a branch's target and daily ledger for the injected Cairo month.
class GetCurrentSalesMonth {
  const GetCurrentSalesMonth(this._repository);
  final SalesRepository _repository;

  Stream<SalesMonthSnapshot> call(String branchId, {required DateTime now}) {
    final monthKey = businessMonthKey(now);
    return _repository
        .watchMonth(branchId, monthKey)
        .asyncExpand(
          (target) => _repository
              .watchSubmissions(branchId, monthKey)
              .map(
                (submissions) => SalesMonthSnapshot(
                  target: target,
                  submissions: submissions,
                ),
              ),
        );
  }
}
