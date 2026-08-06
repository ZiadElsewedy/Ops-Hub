import 'package:drop/features/sales/domain/repositories/sales_repository.dart';
class EditApprovedSalesSubmission { const EditApprovedSalesSubmission(this._repository); final SalesRepository _repository;
  Future<void> call({required String submissionId, required int amountPiastres, required String reason, required int expectedRevision}) => _repository.editApprovedSubmission(submissionId: submissionId, amountPiastres: amountPiastres, reason: reason, expectedRevision: expectedRevision); }
