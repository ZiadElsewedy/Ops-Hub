import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/adaptive_scaffold.dart';
import 'package:opshub/core/widgets/app_snackbar.dart';
import 'package:opshub/features/auth/presentation/animations/fade_slide_transition.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_state.dart';
import 'package:opshub/features/auth/presentation/widgets/app_button.dart';
import 'package:opshub/features/auth/presentation/widgets/app_password_field.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: 'Change Password',
      contentMaxWidth: 560,
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          state.whenOrNull(
            passwordChanged: () {
              AppSnackbar.success(context, 'Password changed successfully');
              context.pop();
            },
            error: (msg) => AppSnackbar.error(context, msg),
          );
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xl),

                const FadeSlideTransition(
                  delay: Duration(milliseconds: 50),
                  child: Text(
                    'Enter your current password and choose a new one.',
                    style: AppTypography.bodyLarge,
                  ),
                ),

                const SizedBox(height: AppSpacing.xxxl),

                FadeSlideTransition(
                  delay: const Duration(milliseconds: 180),
                  child: AppPasswordField(
                    controller: _currentPasswordController,
                    label: 'Current Password',
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Enter your current password' : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                FadeSlideTransition(
                  delay: const Duration(milliseconds: 230),
                  child: AppPasswordField(
                    controller: _newPasswordController,
                    label: 'New Password',
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      if (v == _currentPasswordController.text) {
                        return 'New password must be different from current';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                FadeSlideTransition(
                  delay: const Duration(milliseconds: 280),
                  child: AppPasswordField(
                    controller: _confirmPasswordController,
                    label: 'Confirm New Password',
                    validator: (v) {
                      if (v != _newPasswordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                ),

                const SizedBox(height: AppSpacing.xxxl),

                FadeSlideTransition(
                  delay: const Duration(milliseconds: 340),
                  beginOffset: const Offset(0, 16),
                  child: BlocBuilder<AuthCubit, AuthState>(
                    builder: (context, state) {
                      final isLoading =
                          state.maybeWhen(loading: (_) => true, orElse: () => false);
                      return AppButton(
                        label: 'Update Password',
                        isLoading: isLoading,
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            context.read<AuthCubit>().changePassword(
                                  currentPassword:
                                      _currentPasswordController.text,
                                  newPassword: _newPasswordController.text,
                                );
                          }
                        },
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
