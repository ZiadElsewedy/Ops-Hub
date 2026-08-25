import 'package:opshub/features/auth/domain/repositories/auth_repository.dart';

class ChangePassword {
  final AuthRepository _repository;
  const ChangePassword(this._repository);

  Future<void> call({
    required String currentPassword,
    required String newPassword,
  }) =>
      _repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
}
