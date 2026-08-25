import 'package:opshub/features/cases/domain/entities/case_entity.dart';
import 'package:opshub/features/cases/domain/entities/case_identity.dart';
import 'package:opshub/features/cases/domain/repositories/case_repository.dart';

/// Opens a new case — persists the case doc and its private `reporter/identity`
/// subdoc atomically. Returns it with its generated id (the opening message is
/// written server-side by `onCaseCreated`).
class CreateCase {
  final CaseRepository _repository;
  const CreateCase(this._repository);

  Future<CaseEntity> call(CaseEntity newCase, CaseIdentity identity) =>
      _repository.createCase(newCase, identity);
}
