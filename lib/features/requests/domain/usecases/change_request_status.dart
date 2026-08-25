import 'package:opshub/core/enums/request_status.dart';
import 'package:opshub/features/requests/domain/repositories/request_repository.dart';

/// Moves a request to a new [RequestStatus] — a single targeted doc update. The
/// `onRequestUpdated` Cloud Function appends the lifecycle event + notifies.
/// [decidedBy]/[decidedByName] stamp the deciding actor for approve/reject.
class ChangeRequestStatus {
  final RequestRepository _repository;
  const ChangeRequestStatus(this._repository);

  Future<void> call(
    String requestId,
    RequestStatus to, {
    String? decidedBy,
    String? decidedByName,
  }) =>
      _repository.changeStatus(
        requestId,
        to,
        decidedBy: decidedBy,
        decidedByName: decidedByName,
      );
}
