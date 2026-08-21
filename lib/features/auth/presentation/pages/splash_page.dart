import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:opshub/core/responsive/breakpoints.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/animated_opshub_logo.dart';
import 'package:opshub/core/widgets/opshub_logo.dart';

/// Where the DROP artwork's visual centre actually sits inside the Lottie's
/// 720×405 composition, relative to the frame's geometric centre — the mean
/// of the settled tail frames' bright-pixel bounding boxes (the frames held
/// on screen during the bootstrap wait), measured and locked by
/// `test/splash_visual_centering_test.dart`. The splash applies the inverse
/// (scaled) so the ARTWORK is what lands on the window centre, not the frame
/// box. Mid-flight the camera move swings the artwork ±≈18px by design.
const Offset kLogoVisualCenterOffset = Offset(4, 21);

/// Where the DROP artwork's bright pixels BEGIN vertically inside the 720×405
/// frame (composition px, settled-tail mean) — i.e. the invisible dead space
/// baked into the top of every Lottie frame. Measured and locked by
/// `test/splash_visual_centering_test.dart`. Used to centre the lockup's
/// VISIBLE bounding box instead of its layout box.
const double kLogoArtworkTop = 59;

/// How far above the window's geometric centre the lockup's visible bounding
/// box sits. A mass dead-centred geometrically reads LOW to the eye, and the
/// owner's reference mock frames the lockup high with breathing room below.
///
/// **65.5, not 50.** This constant read 50 while the page actually rendered a
/// 65.5px lift at 1440×900 and 61.6px at 1024×720 — the lift formula predated
/// [kLogoManualScale] (owner-tuned by eye 2026-07-05) and never accounted for
/// it, so the real framing drifted with window size and no longer matched the
/// number. The owner tuned the *pixels*, so the pixels are the specification:
/// this is now the measured value of the framing they signed off at 1440×900,
/// and the formula below reproduces it at **every** window size.
const double kSplashOpticalLift = 65.5;

/// MANUAL visual correction (owner-tuned by eye, 2026-07-05): the whole Lottie
/// box is nudged right and scaled up. Paint-only — OPERATIONS, the bar and
/// all spacing are untouched. Tune these two numbers to taste.
const double kLogoManualNudgeX = 120;
const double kLogoManualScale = 1.50;
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
/// Firebase/session work and the Lottie playback run independently, with the
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
    }
  }

  /// The cold-start intro always plays over this exact wall-clock duration,
  /// regardless of the Lottie asset's native frame length — swapping the
  /// composition later never silently changes how long the launch feels.
  static const _introDuration = Duration(seconds: 5);

  void _play(LottieComposition composition) {
    if (_controller.isAnimating || _animationReported) return;
    _controller
      ..duration = _introDuration
      ..forward().whenComplete(_reportAnimationComplete);
  }

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

    // ── DEBUG (debug builds only): prove the centering math on this platform.
    // Prints the render-surface size, its geometric centre, and the safe-area
    // insets — so a macOS title-bar / notch offset would show up here as
    // non-zero padding instead of being guessed at. Compare `size/2` against
    // where the lockup actually lands on screen.
    assert(() {
      final mq = MediaQuery.of(context);
      debugPrint(
        '[SplashPage] size=${mq.size} '
        'centre=(${(mq.size.width / 2).toStringAsFixed(1)}, '
        '${(mq.size.height / 2).toStringAsFixed(1)}) '
        'padding=${mq.padding} viewPadding=${mq.viewPadding} '
        'viewInsets=${mq.viewInsets} dpr=${mq.devicePixelRatio}',
      );
      return true;
    }());

    // Logo scales with the window but is clamped so it never gets huge or
    // tiny; height follows the source 16:9 frame. The layout is exactly
    // Center → Column(min) → [logo, OPERATIONS, bar] — no SafeArea, Stack,
    // Align, Positioned, ConstrainedBox, or Padding — so nothing but Center
    // decides where the lockup sits. The Lottie box itself receives only the
    // owner-tuned manual translation and scale inside _logoLockup.
    final logoWidth = (MediaQuery.sizeOf(context).width * 0.32).clamp(
      240.0,
      440.0,
    );

    // ── Centre the lockup's VISIBLE bounding box, not its layout box. ──
    // The Lottie frame bakes dead space above the artwork (kLogoArtworkTop),
    // which drags the visible mass low when the layout box is centred; and a
    // geometrically-centred mass reads low to the eye anyway
    // (kSplashOpticalLift). The bottom balancer SizedBox raises the visible
    // group by `lift` while keeping the layout pure Center → Column — the
    // combined artwork→bar bbox then sits kSplashOpticalLift above the
    // window's geometric centre.
    // The lockup's VISIBLE top is the artwork's first bright pixel, which is
    // not the top of the layout box. Two things separate them, and the old
    // formula only knew about the first:
    //   1. the Lottie frame bakes `kLogoArtworkTop` of dead space above the
    //      artwork, and
    //   2. `kLogoManualScale` magnifies the box about its own centre — so the
    //      box's painted top rises by half its growth, while the dead space
    //      inside it is magnified too.
    // Leaving (2) out is what made the real lift drift with window size.
    final boxH = logoWidth * 9 / 16;
    final artworkInset = kLogoArtworkTop / 405 * boxH;
    final scaleRise = boxH * (kLogoManualScale - 1) / 2;
    final visibleTopVsLayoutTop = artworkInset * kLogoManualScale - scaleRise;
    final lift = kSplashOpticalLift + visibleTopVsLayoutTop / 2;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Logo — manually positioned by eye.
            Center(child: _logoLockup(logoWidth)),
            const SizedBox(height: 24),
            // 2. OPERATIONS — the premium wordmark.
            const Center(child: _OperationsWordmark()),
            const SizedBox(height: 28),
            // 3. Loading bar (or the startup error, animation-gated).
            Center(
              child: showError
                  ? _StartupError(onRetry: widget.onRetry)
                  : const _PremiumLoadingBar(),
            ),
            // 4. Balancer — shifts the visible group up by `lift` within
            // the Center, with zero transforms (pure layout).
            SizedBox(height: 2 * lift),
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

  /// The logo box, MANUALLY corrected by eye (owner ruling — no automatic
  /// bbox centering): the whole Lottie container is nudged right by
  /// [kLogoManualNudgeX] and scaled up by [kLogoManualScale]. Both transforms
  /// are paint-only, so OPERATIONS, the bar and all spacing are untouched.
  /// The soft radial light behind the mark paints under the child.
  Widget _logoLockup(double logoWidth) {
    return Transform.translate(
      offset: const Offset(kLogoManualNudgeX, 0),
      child: Transform.scale(
        scale: kLogoManualScale,
        child: SizedBox(
          width: logoWidth,
          height: logoWidth * 9 / 16,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 0.6,
                colors: [AppColors.white.withAlpha(16), Colors.transparent],
              ),
            ),
            child: RepaintBoundary(child: _logo()),
          ),
        ),
      ),
    );
  }

  /// The cold-start Lottie — the animated DROP logo. A malformed/missing asset
  /// falls back to the static wordmark and releases the animation gate so it
  /// can never deadlock startup.
  Widget _logo() => Semantics(
    label: 'OpsHub',
    image: true,
    child: LottieBuilder(
      // This export contains 102 embedded 720×405 WebP image assets (not
      // lightweight vector paths). Load the JSON off the UI isolate and
      // decode the images at a bounded size to avoid a ~113 MiB cold-start
      // decoded-image footprint.
      lottie: _LaunchAssetLottie('assets/0704.json'),
      controller: _controller,
      fit: BoxFit.contain,
      repeat: false,
      animate: false,
      onLoaded: _play,
      errorBuilder: (context, error, stackTrace) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _reportAnimationComplete(),
        );
        return const OpsHubLogo(height: 88);
      },
    ),
  );
}

/// Asset provider that keeps the supplied Lottie intact while bounding its
/// embedded raster-frame decode size. `AssetLottie` otherwise resolves data URI
/// images at their full 720×405 source dimensions before playback begins.
class _LaunchAssetLottie extends AssetLottie {
  // The explicit forward keeps the private provider's fixed loading policy
  // visible at the call site.
  // ignore: use_super_parameters
  _LaunchAssetLottie(String assetName)
    : super(assetName, backgroundLoading: true);

  static const _decodedWidth = 480;

  @override
  ImageProvider<Object>? getImageProvider(LottieImageAsset lottieImage) {
    final provider = super.getImageProvider(lottieImage);
    return provider == null
        ? null
        : ResizeImage(provider, width: _decodedWidth, allowUpscaling: false);
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
