import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/app_snackbar.dart';
import 'package:opshub/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:opshub/features/auth/presentation/animations/fade_slide_transition.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_state.dart';
import 'package:opshub/features/auth/presentation/widgets/app_button.dart';
import 'package:opshub/features/auth/presentation/widgets/app_password_field.dart';

/// First-login forced password change. Shown (and confined to by the router) when
/// the signed-in account still has `mustChangePassword == true` — the user must
/// replace the admin-issued temporary password before continuing. On success the
/// flag is cleared and the router advances to Profile Completion (or Home).
class ForcePasswordChangePage extends StatefulWidget {
  const ForcePasswordChangePage({super.key});

  @override
  State<ForcePasswordChangePage> createState() =>
      _ForcePasswordChangePageState();
}

class _ForcePasswordChangePageState extends State<ForcePasswordChangePage> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      context.read<AuthCubit>().forcePasswordChange(
            currentPassword: _currentController.text,
            newPassword: _newController.text,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AuthScaffold(
      actions: [
        TextButton(
          onPressed: () => context.read<AuthCubit>().signOut(),
          child: Text('Sign out',
              style: AppTypography.label
                  .copyWith(color: AppColors.textSecondary)),
        ),
      ],
      child: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          state.whenOrNull(error: (msg) => AppSnackbar.error(context, msg));
        },
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.lg),
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 40),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.darkSurfaceElevated,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.darkBorder),
                    ),
                    child: const Icon(Icons.lock_reset_rounded,
                        color: AppColors.textPrimary, size: 26),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 80),
                  child: Text(
                    'Set a new password',
                    style: AppTypography.displayMedium.copyWith(
                      color:
                          isDark ? AppColors.textPrimary : AppColors.textDark,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const FadeSlideTransition(
                  delay: Duration(milliseconds: 130),
                  child: Text(
                    'For security, replace the temporary password you were given '
                    'before continuing.',
                    style: AppTypography.bodyLarge,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxxl),
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 180),
                  child: AppPasswordField(
                    controller: _currentController,
                    label: 'Temporary password',
                    textInputAction: TextInputAction.next,
                    validator: (v) => v == null || v.isEmpty
                        ? 'Enter your temporary password'
                        : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 220),
                  child: AppPasswordField(
                    controller: _newController,
                    label: 'New password',
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      if (v == _currentController.text) {
                        return 'New password must be different';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 260),
                  child: AppPasswordField(
                    controller: _confirmController,
                    label: 'Confirm new password',
                    onSubmitted: (_) => _submit(),
                    validator: (v) =>
                        v != _newController.text ? 'Passwords do not match' : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxxl),
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 320),
                  beginOffset: const Offset(0, 16),
                  child: BlocBuilder<AuthCubit, AuthState>(
                    builder: (context, state) {
                      final busy = state.maybeWhen(
                          loading: (_) => true, orElse: () => false);
                      return AppButton(
                        label: 'Update password',
                        isLoading: busy,
                        onPressed: busy ? null : _submit,
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
