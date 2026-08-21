import 'package:flutter/material.dart';
import 'package:opshub/core/responsive/breakpoints.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/animated_opshub_logo.dart';
import 'package:opshub/core/widgets/opshub_logo.dart';

const Duration _mobileIntroDuration = Duration(milliseconds: 1800);

/// How far above the phone's optical centre the mobile lockup rests — a mass
/// dead-centred reads slightly low to the eye, so the brand group is nudged up.
const double _mobileOpticalLift = 24;

/// Maps the master intro value [v] (0→1) to a single element's entrance
/// progress across its own [start, end] window, so the logo, wordmark and bar
/// reveal in a staggered sequence off one controller instead of all at once.
double _reveal(double v, double start, double end, Curve curve) {
  if (v <= start) return 0;
  if (v >= end) return 1;
  return curve.transform((v - start) / (end - start));
}

/// The cold-start visual surface.
///
/// Bootstrap is intentionally owned by the composition root (`LaunchApp` in
/// `main.dart`), not this page. Keeping this widget presentation-only lets the
/// Firebase/session work and the intro animation run independently, with the
/// parent acting as the two-condition rendezvous.
class SplashPage extends StatefulWidget {
  const SplashPage({
    required this.onAnimationComplete,
    required this.isBootstrapping,
    this.bootstrapError,
    this.onRetry,
    super.key,
  });

  final VoidCallback onAnimationComplete;
  final bool isBootstrapping;
  final Object? bootstrapError;
  final VoidCallback? onRetry;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late bool _isMobile;
  bool _displayModeResolved = false;
  bool _animationReported = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_displayModeResolved) return;
    _displayModeResolved = true;
    _isMobile = MediaQuery.sizeOf(context).width < Breakpoints.tablet;
    if (_isMobile) {
      _controller
        ..duration = _mobileIntroDuration
        ..forward().whenComplete(_reportAnimationComplete);
    } else {
      _controller
        ..duration = _introDuration
        ..forward().whenComplete(_reportAnimationComplete);
    }
  }

  /// The desktop cold-start intro — a short static-logo beat. The loading bar
  /// keeps animating on its own until bootstrap finishes independently.
  static const _introDuration = Duration(milliseconds: 1200);

  void _reportAnimationComplete() {
    if (!mounted || _animationReported) return;
    _animationReported = true;
    widget.onAnimationComplete();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showError = _animationReported && widget.bootstrapError != null;

    if (_isMobile) return _buildMobileSplash(showError);

    final logoHeight = (MediaQuery.sizeOf(context).width * 0.10).clamp(
      88.0,
      140.0,
    );
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OpsHubLogo(height: logoHeight),
            const SizedBox(height: 28),
            const _OperationsWordmark(),
            const SizedBox(height: 28),
            Center(
              child: showError
                  ? _StartupError(onRetry: widget.onRetry)
                  : const _PremiumLoadingBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileSplash(bool showError) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final logoHeight = (screenWidth * 0.32).clamp(108.0, 136.0);

    // The brand group reveals as one choreographed sequence off the single
    // intro controller: the logo blooms first, OPERATIONS rises in behind it,
    // then the loading bar draws in — instead of everything appearing at once.
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _AmbientBackdrop(),
          SafeArea(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -_mobileOpticalLift),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final v = _controller.value;
                    final logoFade = _reveal(v, 0, 0.42, Curves.easeOut);
                    final logoSettle = _reveal(v, 0, 0.72, Curves.easeOutCubic);
                    final opsReveal = _reveal(v, 0.34, 0.78, Curves.easeOut);
                    final barReveal = _reveal(v, 0.54, 0.96, Curves.easeOut);

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 1. The hero — the animated (light-sweep) wordmark,
                        // blooming up into place.
                        Opacity(
                          opacity: logoFade,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - logoSettle)),
                            child: Transform.scale(
                              scale: 0.9 + (0.1 * logoSettle),
                              child: Semantics(
                                label: 'OpsHub',
                                image: true,
                                child: RepaintBoundary(
                                  child: AnimatedOpsHubLogo(height: logoHeight),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // 2. OPERATIONS — rises in a beat after the logo.
                        Opacity(
                          opacity: opsReveal,
                          child: Transform.translate(
                            offset: Offset(0, 12 * (1 - opsReveal)),
                            child: const _OperationsWordmark(compact: true),
                          ),
                        ),
                        const SizedBox(height: 32),
                        // 3. The loading bar (or the startup error) — last in.
                        Opacity(
                          opacity: barReveal,
                          child: Transform.translate(
                            offset: Offset(0, 8 * (1 - barReveal)),
                            child: showError
                                ? _StartupError(onRetry: widget.onRetry)
                                : const _PremiumLoadingBar(compact: true),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The cold-start atmosphere behind the mobile lockup — layered, strictly
/// monochrome light on deep black. A faint wide halo gives the black depth, and
/// a soft central pool behind the logo **breathes** (slowly drifts in radius and
/// intensity) so the screen feels alive during the bootstrap wait rather than
/// frozen. No colour, no hard ring — just white light falling off into black.
class _AmbientBackdrop extends StatefulWidget {
  const _AmbientBackdrop();

  @override
  State<_AmbientBackdrop> createState() => _AmbientBackdropState();
}

class _AmbientBackdropState extends State<_AmbientBackdrop>
    with SingleTickerProviderStateMixin {
  // A long, gentle in-and-out cycle — a breath, never a pulse.
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5600),
  )..repeat(reverse: true);

  // The glow sits a touch above centre, where the logo lands.
  static const Alignment _origin = Alignment(0, -0.16);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final breath = Curves.easeInOut.transform(_ctrl.value);
          final glowAlpha = (14 + 8 * breath).round();
          final glowRadius = 0.52 + 0.06 * breath;
          return DecoratedBox(
            decoration: const BoxDecoration(color: Colors.black),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Faint wide halo — depth, so the black isn't flat.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: _origin,
                      radius: 1.15,
                      colors: [Color(0x06FFFFFF), Colors.transparent],
                      stops: [0, 1],
                    ),
                  ),
                ),
                // Breathing central pool behind the logo.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: _origin,
                      radius: glowRadius,
                      colors: [
                        AppColors.white.withAlpha(glowAlpha),
                        Colors.transparent,
                      ],
                      stops: const [0, 1],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The premium 'OPERATIONS' wordmark — wide-tracked caps in pure white with a
/// soft outer glow, a whisper of drop shadow for depth, and a very subtle
/// light sweep that passes every few seconds. Strictly monochrome: the glow
/// is white light, no colour.
class _OperationsWordmark extends StatefulWidget {
  const _OperationsWordmark({this.compact = false});

  final bool compact;

  @override
  State<_OperationsWordmark> createState() => _OperationsWordmarkState();
}

class _OperationsWordmarkState extends State<_OperationsWordmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4400),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tracking = widget.compact ? 8.0 : 12.0;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        // The sheen crosses during the first ~35% of the cycle, then rests —
        // a passing light, not a strobe.
        final t = (_ctrl.value / 0.35).clamp(0.0, 1.0);
        final x = -0.4 + Curves.easeInOut.transform(t) * 1.8;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: const Alignment(-1.0, -0.3),
            end: const Alignment(1.0, 0.3),
            colors: [
              Colors.transparent,
              AppColors.white.withAlpha(140),
              Colors.transparent,
            ],
            stops: [
              (x - 0.25).clamp(0.0, 1.0),
              x.clamp(0.0, 1.0),
              (x + 0.25).clamp(0.0, 1.0),
            ],
          ).createShader(rect),
          child: child,
        );
      },
      // Flutter adds letter-spacing AFTER every glyph, including the last —
      // which drags wide-tracked text visually left of centre. The leading
      // padding equal to one tracking unit rebalances it so the GLYPHS are
      // what's centred, not the text box.
      child: Padding(
        padding: EdgeInsets.only(left: tracking),
        child: Text(
          'OPERATIONS',
          // Built fresh (not copyWith) because a gradient `foreground` cannot
          // coexist with an inherited `color`. Strictly monochrome: the
          // metallic ramp is white → silver greys, the bloom is white light.
          style: TextStyle(
            fontSize: widget.compact ? 13 : 15,
            fontWeight: FontWeight.w600,
            letterSpacing: tracking,
            // Metallic glyphs: bright white top edge cooling to silver at the
            // baseline — reads as brushed metal under the passing sweep.
            foreground: Paint()
              ..shader = const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFFFFF),
                  Color(0xFFE9EAEE),
                  Color(0xFFB4B8C2),
                ],
                stops: [0.0, 0.55, 1.0],
              ).createShader(const Rect.fromLTWH(0, 0, 320, 20)),
            shadows: [
              // Bloom — a wide halo of light around the whole word.
              Shadow(color: AppColors.white.withAlpha(120), blurRadius: 30),
              // Glow — the tighter luminous edge.
              Shadow(color: AppColors.white.withAlpha(90), blurRadius: 12),
              // Core — crispness right at the glyph border.
              Shadow(color: AppColors.white.withAlpha(50), blurRadius: 4),
              // Soft drop shadow — grounds the glow with a hint of depth.
              Shadow(
                color: Colors.black.withAlpha(160),
                offset: const Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The premium indeterminate loading bar — thin, rounded, resting in a faint
/// halo of light, with a soft band sweeping left→right until bootstrap
/// completes. Monochrome white on the dim track.
class _PremiumLoadingBar extends StatefulWidget {
  const _PremiumLoadingBar({this.compact = false});

  final bool compact;

  static const double width = 240;
  static const double height = 3.5;

  @override
  State<_PremiumLoadingBar> createState() => _PremiumLoadingBarState();
}

class _PremiumLoadingBarState extends State<_PremiumLoadingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.compact ? 210.0 : _PremiumLoadingBar.width;
    return Container(
      width: width,
      height: _PremiumLoadingBar.height,
      // The halo: a soft white glow around the whole track (premium, quiet).
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_PremiumLoadingBar.height),
        boxShadow: [
          BoxShadow(
            color: AppColors.white.withAlpha(30),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          // The bright band's centre travels from just off the left edge to
          // just off the right edge each cycle, easing at both ends.
          final c = -0.3 + Curves.easeInOut.transform(_controller.value) * 1.6;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_PremiumLoadingBar.height),
              gradient: LinearGradient(
                colors: [
                  AppColors.white.withAlpha(26),
                  AppColors.white.withAlpha(255),
                  AppColors.white.withAlpha(26),
                ],
                stops: [
                  (c - 0.3).clamp(0.0, 1.0),
                  c.clamp(0.0, 1.0),
                  (c + 0.3).clamp(0.0, 1.0),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'OpsHub could not start. Check your connection and try again.',
        textAlign: TextAlign.center,
        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: 12),
      TextButton(
        onPressed: onRetry,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size(96, 44),
        ),
        child: const Text('Try again'),
      ),
    ],
  );
}
