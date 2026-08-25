import 'package:opshub/features/profile/domain/entities/profile_entity.dart';
import 'package:opshub/features/profile/domain/repositories/profile_repository.dart';

class GetProfile {
  final ProfileRepository _repository;
  const GetProfile(this._repository);

  Future<ProfileEntity?> call(String uid) => _repository.getProfile(uid);
}
