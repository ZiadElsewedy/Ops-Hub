import 'package:opshub/features/profile/domain/entities/profile_entity.dart';
import 'package:opshub/features/profile/domain/repositories/profile_repository.dart';

class UpdateProfile {
  final ProfileRepository _repository;
  const UpdateProfile(this._repository);

  Future<ProfileEntity> call({
    required String uid,
    String? fullName,
    String? username,
    String? bio,
    String? phoneNumber,
    String? country,
    String? city,
    String? website,
    String? gender,
    DateTime? birthDate,
    String? profileImage,
    String? coverImage,
    String? emergencyContact,
    String? address,
    String? paymentNumber,
  }) =>
      _repository.updateProfile(
        uid: uid,
        fullName: fullName,
        username: username,
        bio: bio,
        phoneNumber: phoneNumber,
        country: country,
        city: city,
        website: website,
        gender: gender,
        birthDate: birthDate,
        profileImage: profileImage,
        coverImage: coverImage,
        emergencyContact: emergencyContact,
        address: address,
        paymentNumber: paymentNumber,
      );
}
