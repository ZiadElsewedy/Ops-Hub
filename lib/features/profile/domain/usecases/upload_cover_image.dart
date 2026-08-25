import 'dart:io';

import 'package:opshub/features/profile/domain/repositories/profile_repository.dart';

class UploadCoverImage {
  final ProfileRepository _repository;
  const UploadCoverImage(this._repository);

  /// Uploads the cover image and returns its download URL.
  Future<String> call(String uid, File file,
          {void Function(double progress)? onProgress}) =>
      _repository.uploadCoverImage(uid, file, onProgress: onProgress);
}
