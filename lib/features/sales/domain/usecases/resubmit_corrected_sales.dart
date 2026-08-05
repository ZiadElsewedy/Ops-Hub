import 'package:drop/features/sales/domain/repositories/sales_repository.dart';
class ResubmitCorrectedSales { const ResubmitCorrectedSales(this._repository); final SalesRepository _repository;
  Future<void> call({required String submissionId, required int amountPiastres}) => _repository.resubmitCorrectedSales(submissionId: submissionId, amountPiastres: amountPiastres); }
