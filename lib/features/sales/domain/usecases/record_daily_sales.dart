import 'package:drop/features/sales/domain/entities/sales_record_result.dart';
import 'package:drop/features/sales/domain/repositories/sales_repository.dart';

/// A manager/admin records a day's sales directly — the record lands already
/// approved and counts toward the target immediately. [businessDateKey] defaults
/// to today (server-resolved) when omitted; [reason] is an optional note.
class RecordDailySales {
  const RecordDailySales(this._repository);
  final SalesRepository _repository;
  Future<SalesRecordResult> call({
    required String branchId,
    required int amountPiastres,
    String? businessDateKey,
    String? reason,
  }) => _repository.recordDailySales(
    branchId: branchId,
    amountPiastres: amountPiastres,
    businessDateKey: businessDateKey,
    reason: reason,
  );
}
