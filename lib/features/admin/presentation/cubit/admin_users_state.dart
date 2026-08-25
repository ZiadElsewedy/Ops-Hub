import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';

part 'admin_users_state.freezed.dart';

@freezed
class AdminUsersState with _$AdminUsersState {
  const factory AdminUsersState.initial() = _Initial;
  const factory AdminUsersState.loading() = _Loading;
  const factory AdminUsersState.loaded(
    List<UserEntity> users, {
    @Default(false) bool busy,
  }) = _Loaded;
  const factory AdminUsersState.error(String message) = _Error;
}
