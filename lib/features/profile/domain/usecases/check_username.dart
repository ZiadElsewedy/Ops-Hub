import 'package:opshub/features/profile/domain/repositories/profile_repository.dart';

class CheckUsername {
  final ProfileRepository _repository;
  const CheckUsername(this._repository);

  Future<bool> call(String username, {required String forUid}) =>
      _repository.isUsernameAvailable(username, forUid: forUid);
}
