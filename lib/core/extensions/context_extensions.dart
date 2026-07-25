import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/core/widgets/app_snackbar.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/presentation/cubit/auth_cubit.dart';

/// Convenience accessors for the signed-in user off any [BuildContext].
///
/// Collapses the repeated `AuthCubit` state lookup
/// (`maybeWhen(authenticated: ..., orElse: () => null)`) that appeared across
/// ~11 screens into a single getter. Uses `read` (one-shot, no rebuild) —
/// exactly the semantics every call site it replaced relied on; widgets that
/// need to rebuild on auth changes still use a `BlocBuilder` as before.
extension AuthContextX on BuildContext {
  /// The currently authenticated user, or `null` when not signed in / not yet
  /// authenticated (e.g. loading or error states).
  UserEntity? get currentUser => read<AuthCubit>().state.maybeWhen(
        authenticated: (u) => u,
        orElse: () => null,
      );

  /// Shorthand for `currentUser?.role`.
  UserRole? get currentRole => currentUser?.role;

  /// Role checks (default to `false` when not authenticated). Mirror the access
  /// model — `admin ⊇ manager` is intentionally NOT applied here; these are the
  /// user's *literal* role, like `UserRole.isAdmin`.
  bool get isAdmin => currentRole?.isAdmin ?? false;
  bool get isManager => currentRole?.isManager ?? false;
  bool get isEmployee => currentRole?.isEmployee ?? false;
}

/// Ergonomic feedback helpers — thin pass-throughs to [AppSnackbar] so screens
/// can call `context.showError(...)` instead of `AppSnackbar.error(context, ...)`.
extension MessagesContextX on BuildContext {
  void showSuccess(String message) => AppSnackbar.success(this, message);
  void showError(String message) => AppSnackbar.error(this, message);
  void showInfo(String message) => AppSnackbar.info(this, message);
}
