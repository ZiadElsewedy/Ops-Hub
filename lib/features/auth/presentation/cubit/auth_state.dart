import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';

part 'auth_state.freezed.dart';

/// Identifies which authentication action is currently in flight.
///
/// Carried on [AuthState.loading] so the UI can show a spinner ONLY on the
/// button that triggered the request, while disabling the others.
enum AuthAction {
  emailSignIn,
  forgotPassword,
  changePassword,
}

@freezed
class AuthState with _$AuthState {
  const factory AuthState.initial() = _Initial;
  const factory AuthState.loading(AuthAction action) = _Loading;
  const factory AuthState.authenticated(UserEntity user) = _Authenticated;

  /// No session. [signedOutReason] is set **only** when the app ended the
  /// session on the user's behalf and owes them an explanation — today that is
  /// single-active-session eviction (`kSessionTakenOverMessage`) and nothing
  /// else. It rides the state rather than a snackbar call because the eviction
  /// happens on whatever screen the user was on, and the message has to survive
  /// the router's redirect to Login before anything can show it.
  ///
  /// The Login screen consumes it once (`AuthCubit.acknowledgeSignOutReason`),
  /// so a reason is never shown twice.
  const factory AuthState.unauthenticated({String? signedOutReason}) =
      _Unauthenticated;
  const factory AuthState.passwordResetSent() = _PasswordResetSent;
  const factory AuthState.passwordChanged() = _PasswordChanged;
  const factory AuthState.error(String message) = _Error;
}
