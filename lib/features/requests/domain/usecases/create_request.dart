import 'package:opshub/features/requests/domain/entities/request_entity.dart';
import 'package:opshub/features/requests/domain/repositories/request_repository.dart';

/// Files a new operations request (single doc write). Returns it with its
/// generated id; the opening `submitted` event + `refCode` are written
/// server-side by `onRequestCreated`.
class CreateRequest {
  final RequestRepository _repository;
  const CreateRequest(this._repository);

  Future<RequestEntity> call(RequestEntity request) =>
      _repository.createRequest(request);
}
