import 'package:opshub/features/requests/domain/entities/request_event.dart';
import 'package:opshub/features/requests/domain/repositories/request_repository.dart';

/// Appends one event (a comment / attachment-added) to a request's timeline — a
/// single `add` of one document (no whole-array read-modify-write).
/// `onRequestEventCreated` bumps the parent + notifies the other party.
class AddRequestComment {
  final RequestRepository _repository;
  const AddRequestComment(this._repository);

  Future<void> call(String requestId, RequestEvent event) =>
      _repository.addEvent(requestId, event);
}
