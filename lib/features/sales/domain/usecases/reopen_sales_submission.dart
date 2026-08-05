import 'package:drop/features/sales/domain/repositories/sales_repository.dart';
class ReopenSalesSubmission { const ReopenSalesSubmission(this._repository); final SalesRepository _repository;
  Future<void> call({required String submissionId, required String reason}) => _repository.decideSubmission(submissionId: submissionId, action: 'reopen', reason: reason); }
