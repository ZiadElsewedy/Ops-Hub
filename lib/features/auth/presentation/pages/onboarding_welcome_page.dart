import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opshub/core/extensions/context_extensions.dart';
import 'package:opshub/core/responsive/breakpoints.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/animated_opshub_logo.dart';
import 'package:opshub/core/widgets/opshub_logo.dart';
import 'package:opshub/features/auth/presentation/animations/fade_slide_transition.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_state.dart';
import 'package:opshub/features/auth/presentation/widgets/app_button.dart';

/// The one-time cinematic **Welcome** screen. The router confines an *employee*
/// whose profile is complete but `hasCompletedOnboarding == false` here — shown
/// exactly once per account, right after profile completion, before the role
/// home. Its "Get started" CTA flips the flag (`AuthCubit.completeOnboarding`),
/// after which the router advances to the employee home and it is never shown
/// again.
///
/// Strictly monochrome, single-screen, Apple/Linear-calm: a static light
/// atmosphere, the OpsHub brand as the hero (a static mark on tablet/desktop,
/// the animated light-sweep logo on phones), and a staggered reveal of a short
/// welcome that sets the tone: accountability, teamwork, one place for the work.
class OnboardingWelcomePage extends StatefulWidget {
  const OnboardingWelcomePage({super.key});

  @override
  State<OnboardingWelcomePage> createState() => _OnboardingWelcomePageState();
}

class _OnboardingWelcomePageState extends State<OnboardingWelcomePage> {
  bool _submitting = false;

  Future<void> _finish() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    // On success `completeOnboarding` re-emits the session and the router
    // redirects away (this page is disposed). A failure emits AuthState.error,
    // caught by the BlocListener below → re-enable + surface it.
    await context.read<AuthCubit>().completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < Breakpoints.tablet;

    final name = context.currentUser?.displayName?.trim();
    final firstName = (name != null && name.isNotEmpty)
        ? name.split(' ').first
        : null;
    final headline = firstName != null
        ? 'Welcome to OpsHub, $firstName.'
        : 'Welcome to OpsHub.';

    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          state.mapOrNull(
            error: (e) {
              if (!mounted) return;
              setState(() => _submitting = false);
              context.showError(e.message);
            },
          );
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _WelcomeAtmosphere(),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 40,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. The brand hero.
                        FadeSlideTransition(
                          delay: const Duration(milliseconds: 100),
                          beginOffset: const Offset(0, 10),
                          child: Center(child: _hero(width, isMobile)),
                        ),
                        SizedBox(height: isMobile ? 28 : 36),
                        // 2. Welcome headline (personalised).
                        FadeSlideTransition(
                          delay: const Duration(milliseconds: 300),
                          child: Text(
                            headline,
                            textAlign: TextAlign.center,
                            style: AppTypography.displayMedium.copyWith(
                              color: AppColors.textPrimary,
                              height: 1.15,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // 3. Sub — belonging.
                        FadeSlideTransition(
                          delay: const Duration(milliseconds: 420),
                          child: Text(
                            "You're part of the team now.",
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyLarge.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 34),
                        // 4. The three quiet expectations — accountability,
                        // teamwork, clarity. Icons left-aligned, block centred.
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _value(
                                Icons.check_circle_outline,
                                'Own your shifts and tasks.',
                                const Duration(milliseconds: 560),
                              ),
                              _value(
                                Icons.groups_outlined,
                                'Back each other up.',
                                const Duration(milliseconds: 650),
                              ),
                              _value(
                                Icons.dashboard_outlined,
                                'One place for everything.',
                                const Duration(milliseconds: 740),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        // 5. The single primary CTA.
                        FadeSlideTransition(
                          delay: const Duration(milliseconds: 900),
                          child: AppButton(
                            label: 'Get started',
                            isLoading: _submitting,
                            onPressed: _finish,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The brand hero: a static mark on tablet/desktop widths; the animated
  /// light-sweep logo on phones.
  Widget _hero(double width, bool isMobile) {
    if (isMobile) {
      final h = (width * 0.30).clamp(96.0, 120.0);
      return AnimatedOpsHubLogo(height: h);
    }
    return OpsHubLogo(height: (width * 0.12).clamp(120.0, 200.0));
  }

  Widget _value(IconData icon, String text, Duration delay) =>
      FadeSlideTransition(
        delay: delay,
        beginOffset: const Offset(0, 16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: AppColors.white.withAlpha(150)),
              const SizedBox(width: 14),
              Flexible(
                child: Text(
                  text,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

/// The static, strictly-monochrome light atmosphere behind the Welcome lockup —
/// a faint wide halo for depth plus a soft central pool where the hero sits.
/// Static (no breathing controller): the staggered entrance is the motion here,
/// and the screen is dismissed quickly, so perpetual animation would be noise.
class _WelcomeAtmosphere extends StatelessWidget {
  const _WelcomeAtmosphere();

  static const Alignment _origin = Alignment(0, -0.28);

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Colors.black),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: _origin,
              radius: 1.1,
              colors: [Color(0x06FFFFFF), Colors.transparent],
              stops: [0, 1],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: _origin,
              radius: 0.6,
              colors: [Color(0x14FFFFFF), Colors.transparent],
              stops: [0, 1],
            ),
          ),
        ),
      ],
    );
  }
}
