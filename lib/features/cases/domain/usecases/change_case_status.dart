import 'package:opshub/core/enums/case_status.dart';
import 'package:opshub/features/cases/domain/repositories/case_repository.dart';

/// Moves a case to a new [CaseStatus] — a single targeted doc update. The
/// `onCaseUpdated` Cloud Function appends the system message + notifies.
class ChangeCaseStatus {
  final CaseRepository _repository;
  const ChangeCaseStatus(this._repository);

  Future<void> call(String caseId, CaseStatus to) =>
      _repository.changeStatus(caseId, to);
}
