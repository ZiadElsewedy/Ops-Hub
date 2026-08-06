import 'package:drop/features/sales/domain/repositories/sales_repository.dart';
class ApproveSalesSubmission { const ApproveSalesSubmission(this._repository); final SalesRepository _repository;
  Future<void> call(String submissionId) => _repository.decideSubmission(submissionId: submissionId, action: 'approve'); }
