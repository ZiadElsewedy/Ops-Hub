import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/app_snackbar.dart';
import 'package:opshub/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:opshub/features/auth/presentation/animations/fade_slide_transition.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_state.dart';
import 'package:opshub/features/auth/presentation/widgets/app_button.dart';
import 'package:opshub/features/auth/presentation/widgets/app_text_field.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AuthScaffold(
      showBack: true,
      child: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          state.whenOrNull(
            passwordResetSent: () => _showSuccess(context),
            error: (msg) => _showError(context, msg),
          );
        },
        builder: (context, state) {
          final sent = state.maybeWhen(
            passwordResetSent: () => true,
            orElse: () => false,
          );

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: sent
                ? _SuccessView(
                    key: const ValueKey('success'),
                    email: _emailController.text.trim(),
                    onBack: () => context.pop(),
                  )
                : _FormView(
                    key: const ValueKey('form'),
                    emailController: _emailController,
                    formKey: _formKey,
                    isDark: isDark,
                  ),
          );
        },
      ),
    );
  }

  void _showError(BuildContext context, String msg) =>
      AppSnackbar.error(context, msg);

  void _showSuccess(BuildContext context) {
    // State transition to SuccessView is handled by the BlocConsumer builder.
  }
}

class _FormView extends StatelessWidget {
  final TextEditingController emailController;
  final GlobalKey<FormState> formKey;
  final bool isDark;

  const _FormView({
    super.key,
    required this.emailController,
    required this.formKey,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.xl),

            FadeSlideTransition(
              delay: const Duration(milliseconds: 50),
              child: Text(
                'Reset\nPassword',
                style: AppTypography.displayMedium.copyWith(
                  color: isDark ? AppColors.textPrimary : AppColors.textDark,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const FadeSlideTransition(
              delay: Duration(milliseconds: 120),
              child: Text(
                "Enter your email and we'll send you a link to reset your password.",
                style: AppTypography.bodyLarge,
              ),
            ),

            const SizedBox(height: AppSpacing.xxxl),

            FadeSlideTransition(
              delay: const Duration(milliseconds: 200),
              child: AppTextField(
                controller: emailController,
                label: 'Email Address',
                hint: 'example@gmail.com',
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter your email';
                  final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                  if (!emailRegex.hasMatch(v.trim())) return 'Enter a valid email';
                  return null;
                },
              ),
            ),

            const SizedBox(height: AppSpacing.xxxl),

            FadeSlideTransition(
              delay: const Duration(milliseconds: 280),
              beginOffset: const Offset(0, 16),
              child: BlocBuilder<AuthCubit, AuthState>(
                builder: (context, state) {
                  final isLoading =
                      state.maybeWhen(loading: (_) => true, orElse: () => false);
                  return AppButton(
                    label: 'Send Reset Link',
                    isLoading: isLoading,
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        context
                            .read<AuthCubit>()
                            .forgotPassword(emailController.text.trim());
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final String email;
  final VoidCallback onBack;

  const _SuccessView({super.key, required this.email, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xl),

          FadeSlideTransition(
            delay: const Duration(milliseconds: 50),
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.successSurface,
                borderRadius: AppRadius.cardAll,
              ),
              child: const Center(
                child: Icon(
                  Icons.mark_email_read_outlined,
                  color: AppColors.success,
                  size: 32,
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          const FadeSlideTransition(
            delay: Duration(milliseconds: 120),
            child: Text(
              'Check Your\nEmail',
              style: AppTypography.displayMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FadeSlideTransition(
            delay: const Duration(milliseconds: 180),
            child: RichText(
              text: TextSpan(
                style: AppTypography.bodyLarge,
                children: [
                  const TextSpan(text: 'We sent a password reset link to\n'),
                  TextSpan(
                    text: email,
                    style: AppTypography.label.copyWith(color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xxxl),

          FadeSlideTransition(
            delay: const Duration(milliseconds: 260),
            beginOffset: const Offset(0, 16),
            child: AppButton(label: 'Back to Sign In', onPressed: onBack),
          ),
        ],
      ),
    );
  }
}
