import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:opshub/features/profile/domain/entities/profile_entity.dart';

part 'profile_state.freezed.dart';

@freezed
class ProfileState with _$ProfileState {
  const factory ProfileState.initial() = _Initial;
  const factory ProfileState.loading() = _Loading; // skeleton
  const factory ProfileState.loaded(ProfileEntity profile) = _Loaded;
  // [uploadProgress] is non-null (0.0–1.0) while an image is uploading, and
  // null during the final Firestore write.
  const factory ProfileState.saving(ProfileEntity profile,
      {double? uploadProgress}) = _Saving;
  const factory ProfileState.saved(ProfileEntity profile) = _Saved;
  const factory ProfileState.error(String message) = _Error;
}
