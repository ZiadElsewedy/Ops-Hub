import 'package:opshub/features/cases/domain/entities/case_message.dart';
import 'package:opshub/features/cases/domain/repositories/case_repository.dart';

/// Appends one message to a case conversation — a single `add` of one document
/// (no whole-array read-modify-write). This is the structural fix for the old
/// reply-sending bug.
class SendCaseMessage {
  final CaseRepository _repository;
  const SendCaseMessage(this._repository);

  Future<void> call(String caseId, CaseMessage message) =>
      _repository.sendMessage(caseId, message);
}
