import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/auth/domain/repositories/auth_repository.dart';

class SignInWithEmail {
  final AuthRepository _repository;
  const SignInWithEmail(this._repository);

  Future<UserEntity> call({
    required String email,
    required String password,
  }) =>
      _repository.signInWithEmail(email: email, password: password);
}
