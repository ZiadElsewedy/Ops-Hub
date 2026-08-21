import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/auth/domain/repositories/auth_repository.dart';

class GetUser {
  final AuthRepository _repository;
  GetUser(this._repository);

  Future<UserEntity?> call(String uid) => _repository.getUser(uid);
}
