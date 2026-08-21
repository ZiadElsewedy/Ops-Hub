import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:opshub/core/routes/route_names.dart';

import 'package:opshub/core/responsive/breakpoints.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/app_snackbar.dart';
import 'package:opshub/core/widgets/opshub_auth_mark.dart';
import 'package:opshub/core/widgets/animated_opshub_logo.dart';
import 'package:opshub/features/auth/presentation/animations/fade_slide_transition.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_state.dart';
import 'package:opshub/features/auth/presentation/widgets/app_button.dart';
import 'package:opshub/features/auth/presentation/widgets/app_text_field.dart';
import 'package:opshub/features/auth/presentation/widgets/app_password_field.dart';

/// The DROP sign-in screen. DROP is **admin-provisioned**: there is no public
/// registration, Google sign-in, or phone/OTP — only email + password, plus a
/// Forgot Password path. Premium, strictly monochrome (white accent, no indigo).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // A session the app ended on the user's behalf — today only
    // single-active-session eviction — sets `signedOutReason` on
    // `unauthenticated`, and the router then redirects here. That state change
    // happened BEFORE this page mounted, so the `BlocListener` below can never
    // see it; the reason has to be read off the current state on the first
    // frame. Consumed immediately so it shows exactly once.
    WidgetsBinding.instance.addPostFrameCallback((_) => _showSignOutReason());
  }

  /// Surfaces `AuthState.unauthenticated.signedOutReason` once, then clears it.
  void _showSignOutReason() {
    if (!mounted) return;
    final cubit = context.read<AuthCubit>();
    final reason = cubit.state.maybeWhen(
      unauthenticated: (reason) => reason,
      orElse: () => null,
    );
    if (reason == null) return;
    AppSnackbar.error(context, reason);
    cubit.acknowledgeSignOutReason();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      context.read<AuthCubit>().signInWithEmail(
            _emailController.text.trim(),
            _passwordController.text,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          state.whenOrNull(
            error: (msg) => AppSnackbar.error(context, msg),
            // The eviction path normally lands before this page mounts (handled
            // in `initState`), but it can also arrive while Login is already on
            // screen — a takeover during a cold start that had not yet routed.
            unauthenticated: (reason) {
              if (reason == null) return;
              AppSnackbar.error(context, reason);
              context.read<AuthCubit>().acknowledgeSignOutReason();
            },
          );
        },
        child: context.isDesktop ? _buildDesktop(context) : _buildMobile(context),
      ),
    );
  }

  // ─── Mobile / tablet: the original centred lockup ───────────────────────────
  Widget _buildMobile(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.darkSurface, AppColors.darkBg],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xxxl),
                const FadeSlideTransition(
                  delay: Duration(milliseconds: 30),
                  child: Center(child: OpsHubAuthMark()),
                ),
                const SizedBox(height: AppSpacing.xxxl),
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 80),
                  child: Text(
                    'Welcome back',
                    textAlign: TextAlign.center,
                    style: AppTypography.displayMedium.copyWith(
                      color:
                          isDark ? AppColors.textPrimary : AppColors.textDark,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const FadeSlideTransition(
                  delay: Duration(milliseconds: 140),
                  child: Text(
                    'Sign in to your Drop Operations account',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyLarge,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxxl),
                ..._formFields(staggered: true),
                const SizedBox(height: AppSpacing.xxl),
                _adminNote(centered: true),
                const SizedBox(height: AppSpacing.xxxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Desktop / macOS: premium split — brand panel + sign-in panel ───────────
  Widget _buildDesktop(BuildContext context) {
    return Row(
      children: [
        // Left: quiet brand canvas.
        Expanded(flex: 5, child: _brandPanel()),
        // Right: the sign-in panel.
        Container(
          width: 540,
          height: double.infinity,
          color: AppColors.darkBg,
          alignment: Alignment.center,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 72, vertical: 48),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 396),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Welcome back', style: AppTypography.h1),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Sign in to your Drop Operations account',
                      style: AppTypography.body,
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    ..._formFields(staggered: false),
                    const SizedBox(height: AppSpacing.xxl),
                    _adminNote(centered: false),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _brandPanel() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.darkSurfaceElevated, AppColors.darkSurface],
        ),
        border: Border(right: BorderSide(color: AppColors.darkBorder)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(64),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // The DROP brand logo artwork (assets/opshub_logo.png), tinted
            // white, with the shimmer sweep — the brand hero of the panel.
            const AnimatedOpsHubLogo(height: 88),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Operations Management System',
              style: AppTypography.h2.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: const Text(
                'Run daily branch operations end to end — tasks, schedules, '
                'shift swaps and team communications — from one premium control '
                'surface for DROP THE SHOP.',
                style: AppTypography.bodyLarge,
              ),
            ),
            const SizedBox(height: AppSpacing.xxxl),
            const Row(
              children: [
                Icon(Icons.shield_outlined,
                    size: 15, color: AppColors.textTertiary),
                SizedBox(width: 8),
                Text('Secure, admin-provisioned access',
                    style: AppTypography.caption),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// The shared form controls (email, password, forgot link, sign-in button).
  /// [staggered] toggles the entrance animation used on mobile.
  List<Widget> _formFields({required bool staggered}) {
    Widget wrap(int ms, Widget child) => staggered
        ? FadeSlideTransition(delay: Duration(milliseconds: ms), child: child)
        : child;
    return [
      wrap(
        200,
        AppTextField(
          controller: _emailController,
          label: 'Email address',
          hint: 'you@company.com',
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Enter your email' : null,
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      wrap(
        250,
        AppPasswordField(
          controller: _passwordController,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          validator: (v) =>
              v == null || v.length < 6 ? 'Min 6 characters' : null,
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      wrap(
        290,
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => context.push(RouteNames.forgotPassword),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Forgot password?',
              style: AppTypography.label.copyWith(color: AppColors.accent),
            ),
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.xxl),
      wrap(
        340,
        BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) {
            final busy =
                state.maybeWhen(loading: (_) => true, orElse: () => false);
            return AppButton(
              label: 'Sign in',
              isLoading: busy,
              onPressed: busy ? null : _submit,
            );
          },
        ),
      ),
    ];
  }

  Widget _adminNote({required bool centered}) {
    return Row(
      mainAxisAlignment:
          centered ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        const Icon(Icons.shield_outlined,
            size: 14, color: AppColors.textTertiary),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Accounts are created by your administrator.',
            style: AppTypography.caption,
            textAlign: centered ? TextAlign.center : TextAlign.start,
          ),
        ),
      ],
    );
  }
}
