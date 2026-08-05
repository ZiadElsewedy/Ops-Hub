import 'package:drop/features/sales/domain/repositories/sales_repository.dart';
class SubmitDailySales { const SubmitDailySales(this._repository); final SalesRepository _repository;
  Future<void> call({required String branchId, required String monthKey, required String businessDateKey, required int amountPiastres, required String submittedById, required String submittedByName}) => _repository.submitDailySales(branchId: branchId, monthKey: monthKey, businessDateKey: businessDateKey, amountPiastres: amountPiastres, submittedById: submittedById, submittedByName: submittedByName); }
