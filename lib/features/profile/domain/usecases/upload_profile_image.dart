import 'dart:io';

import 'package:opshub/features/profile/domain/repositories/profile_repository.dart';

class UploadProfileImage {
  final ProfileRepository _repository;
  const UploadProfileImage(this._repository);

  /// Uploads the avatar and returns its download URL.
  Future<String> call(String uid, File file,
          {void Function(double progress)? onProgress}) =>
      _repository.uploadProfileImage(uid, file, onProgress: onProgress);
}
