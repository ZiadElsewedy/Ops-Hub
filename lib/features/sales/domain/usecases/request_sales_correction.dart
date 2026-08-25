import 'package:opshub/features/sales/domain/repositories/sales_repository.dart';
class RequestSalesCorrection { const RequestSalesCorrection(this._repository); final SalesRepository _repository;
  Future<void> call({required String submissionId, required String reason}) => _repository.decideSubmission(submissionId: submissionId, action: 'requestCorrection', reason: reason); }
