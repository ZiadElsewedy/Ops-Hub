import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:opshub/core/constants/app_constants.dart';
import 'package:opshub/core/responsive/breakpoints.dart';
import 'package:opshub/core/routes/route_names.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/theme/phosphor_icons.dart';
import 'package:opshub/core/widgets/hover_lift.dart';
import 'package:opshub/core/widgets/opshub_lockup.dart';
import 'package:opshub/core/widgets/animated_opshub_logo.dart';
import 'package:opshub/features/auth/presentation/animations/fade_slide_transition.dart';
import 'package:opshub/features/auth/presentation/widgets/app_button.dart';

/// Curated, downscaled captures of the real app (regenerated from
/// `docs/screenshots` — see `tool/` notes in the README). Shown in the
/// landing showcase carousel.
const List<String> _showcaseAssets = [
  'assets/showcase/home.png',
  'assets/showcase/tasks.png',
  'assets/showcase/sales.png',
  'assets/showcase/schedule.png',
  'assets/showcase/composer.png',
  'assets/showcase/admin.png',
];

/// The pre-login landing page — the product's front door.
///
/// A marketing-grade surface that brands the product before any credentials
/// appear: the animated hub mark, the positioning line, what's inside, and a
/// live showcase of the real app, closing with the single action this app
/// allows — signing in (access is admin-provisioned; there is no sign-up).
///
/// Strictly monochrome like every other surface: black, white, greys, motion.
class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.desktop;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _AmbientBackdrop(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: Breakpoints.contentMaxWidth,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pagePadding,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.lg),
                      const _TopBar(),
                      SizedBox(height: wide ? 72 : 56),
                      const _Hero(),
                      SizedBox(height: wide ? 80 : 64),
                      const _FeaturesSection(),
                      SizedBox(height: wide ? 80 : 64),
                      const _ShowcaseSection(),
                      SizedBox(height: wide ? 72 : 56),
                      const _Footer(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Chrome ─────────────────────────────────────────────────────────────────

/// Quiet top chrome: the brand lockup on the left, the version on the right.
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return FadeSlideTransition(
      delay: const Duration(milliseconds: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const OpsHubLockup(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: AppRadius.fullAll,
              border: Border.all(color: AppColors.darkBorder),
              color: AppColors.darkSurface.withAlpha(120),
            ),
            child: const Text('v1.0.0', style: AppTypography.caption),
          ),
        ],
      ),
    );
  }
}

// ─── Hero ───────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 1 · The mark — blooming into place with its light-sweep shimmer.
        FadeSlideTransition(
          delay: const Duration(milliseconds: 100),
          beginOffset: const Offset(0, 18),
          child: Semantics(
            label: AppConstants.appName,
            image: true,
            child: const AnimatedOpsHubLogo(height: 92),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // 2 · OPERATIONS — the tracked-caps brand line from the splash.
        const FadeSlideTransition(
          delay: Duration(milliseconds: 220),
          child: _OperationsLine(),
        ),
        const SizedBox(height: AppSpacing.xxl),
        // 3 · The positioning headline.
        const FadeSlideTransition(
          delay: Duration(milliseconds: 300),
          child: Text(
            'Every branch.\nOne hub.',
            textAlign: TextAlign.center,
            style: AppTypography.display,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // 4 · The supporting line.
        FadeSlideTransition(
          delay: const Duration(milliseconds: 380),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              'Tasks, GPS attendance, scheduling, approvals and sales — the '
              'daily operations of your business, running from one premium '
              'control surface.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyLarge,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        // 5 · The single action this app allows.
        FadeSlideTransition(
          delay: const Duration(milliseconds: 460),
          child: Column(
            children: [
              SizedBox(
                width: 280,
                child: AppButton(
                  label: 'Sign in',
                  onPressed: () => context.push(RouteNames.login),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_outlined,
                      size: 13, color: AppColors.textQuaternary),
                  SizedBox(width: 6),
                  Text(
                    'Private workspace · accounts are created by your administrator',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The tracked-caps 'OPERATIONS' brand line — the splash wordmark's little
/// sibling, static here (the logo above carries the motion).
class _OperationsLine extends StatelessWidget {
  const _OperationsLine();

  @override
  Widget build(BuildContext context) {
    const tracking = 7.0;
    // Trailing letter-spacing drags the glyphs left of centre — rebalance with
    // a leading padding of one tracking unit (see SplashPage's wordmark).
    return Padding(
      padding: const EdgeInsets.only(left: tracking),
      child: Text(
        'OPERATIONS',
        textAlign: TextAlign.center,
        style: AppTypography.labelSmall.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: tracking,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}

// ─── Features ───────────────────────────────────────────────────────────────

class _Feature {
  const _Feature(this.icon, this.title, this.body);

  final IconData icon;
  final String title;
  final String body;
}

const List<_Feature> _features = [
  _Feature(
    PhosphorIconsRegular.listChecks,
    'Tasks with proof',
    'Assign, execute and review work — with photos, notes and checklists '
    'attached to every close.',
  ),
  _Feature(
    PhosphorIconsRegular.fingerprint,
    'GPS attendance',
    'Clock in and out from the branch floor, verified against the branch '
    'geofence.',
  ),
  _Feature(
    PhosphorIconsRegular.calendarDots,
    'Schedules & swaps',
    'Weekly rosters, shift templates and attributed swap approvals — '
    'coverage at a glance.',
  ),
  _Feature(
    PhosphorIconsRegular.stamp,
    'Instant approvals',
    'Requests travel employee → manager with one tap, every decision '
    'audited.',
  ),
  _Feature(
    PhosphorIconsRegular.chatsCircle,
    'Chat & cases',
    'Direct messages and private cases — realtime, with an offline cache.',
  ),
  _Feature(
    PhosphorIconsRegular.trendUp,
    'Sales targets',
    'Per-branch monthly targets with live pace, daily closes and '
    'manager approval.',
  ),
];

class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= Breakpoints.desktop ? 3 : 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FadeSlideTransition(
          delay: Duration(milliseconds: 540),
          child: _SectionLabel(icon: PhosphorIconsRegular.squaresFour, title: "WHAT'S INSIDE"),
        ),
        const SizedBox(height: AppSpacing.xl),
        FadeSlideTransition(
          delay: const Duration(milliseconds: 600),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const gap = AppSpacing.lg;
              final cardWidth =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final feature in _features)
                    SizedBox(
                      width: cardWidth,
                      child: _FeatureCard(feature: feature),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.feature});

  final _Feature feature;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(feature.icon, size: 22, color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(feature.title, style: AppTypography.h3),
          const SizedBox(height: AppSpacing.sm),
          Text(feature.body, style: AppTypography.body),
        ],
      ),
    );

    // Desktop gets pointer feedback; touch keeps the flat card.
    final isDesktop =
        MediaQuery.sizeOf(context).width >= Breakpoints.desktop;
    if (!isDesktop) return card;
    return HoverLift(borderRadius: AppRadius.cardAll, child: card);
  }
}

// ─── Showcase carousel ──────────────────────────────────────────────────────

class _ShowcaseSection extends StatelessWidget {
  const _ShowcaseSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FadeSlideTransition(
          delay: Duration(milliseconds: 660),
          child: _SectionLabel(
            icon: PhosphorIconsRegular.house,
            title: 'INSIDE THE APP',
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const FadeSlideTransition(
          delay: Duration(milliseconds: 720),
          child: _ShowcaseCarousel(),
        ),
      ],
    );
  }
}

/// Auto-advancing, snap-scrolling carousel of the real app. Neighbouring cards
/// dim and shrink by distance from the centre; a drag pauses the auto-advance
/// for a beat, then hands control back. Wraps around at the ends.
class _ShowcaseCarousel extends StatefulWidget {
  const _ShowcaseCarousel();

  @override
  State<_ShowcaseCarousel> createState() => _ShowcaseCarouselState();
}

class _ShowcaseCarouselState extends State<_ShowcaseCarousel> {
  static const _autoAdvance = Duration(milliseconds: 3600);
  static const _resumeAfterDrag = Duration(milliseconds: 4200);

  /// Width ÷ height of an iPhone capture — every showcase asset shares it.
  static const double _cardAspect = 0.46;

  late PageController _controller = PageController();
  double _fraction = 1.0;
  double _cardHeight = 460;
  Timer? _autoTimer;
  Timer? _resumeTimer;
  bool _dragging = false;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _startAutoAdvance();
  }

  /// The page fraction follows the card size, which follows the breakpoint —
  /// mobile shows one tall card with peeks, desktop a wider filmstrip. The
  /// fraction is baked into a PageController, so a change swaps in a fresh
  /// controller (keeping the current page) and retires the old one after the
  /// frame, once the viewport has detached from it.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= Breakpoints.desktop;
    final cardHeight = isDesktop ? 540.0 : 460.0;
    final cardWidth = cardHeight * _cardAspect;
    final contentWidth =
        math.min(screenWidth, Breakpoints.contentMaxWidth) -
        AppSpacing.pagePadding * 2;
    final fraction =
        ((cardWidth + 24) / contentWidth).clamp(0.18, 0.92);
    if ((fraction - _fraction).abs() < 0.001) return;

    _fraction = fraction;
    _cardHeight = cardHeight;
    final old = _controller;
    _controller = PageController(viewportFraction: fraction, initialPage: _page);
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _resumeTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startAutoAdvance() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(_autoAdvance, (_) {
      if (!mounted || !_controller.hasClients || _dragging) return;
      final next = (_page + 1) % _showcaseAssets.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  /// A user drag silences the auto-advance until the page has rested a beat.
  bool _onScroll(ScrollNotification notification) {
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _dragging = true;
      _autoTimer?.cancel();
      _resumeTimer?.cancel();
    } else if (notification is ScrollEndNotification && _dragging) {
      _dragging = false;
      _resumeTimer?.cancel();
      _resumeTimer = Timer(_resumeAfterDrag, _startAutoAdvance);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: SizedBox(
            height: _cardHeight,
            child: PageView.builder(
              controller: _controller,
              itemCount: _showcaseAssets.length,
              onPageChanged: (page) => setState(() => _page = page),
              itemBuilder: (context, index) {
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    // Distance of this card from the resting centre,
                    // smoothed as the page settles.
                    var delta = 0.0;
                    if (_controller.hasClients &&
                        _controller.position.haveDimensions) {
                      delta = _controller.page! - index;
                    } else {
                      delta = (_page - index).toDouble();
                    }
                    final distance = delta.abs().clamp(0.0, 1.0);
                    final scale = 1 - 0.06 * distance;
                    final opacity = 1 - 0.45 * distance;
                    return Center(
                      child: Transform.scale(
                        scale: scale,
                        child: Opacity(opacity: opacity, child: child),
                      ),
                    );
                  },
                  child: _ShowcaseCard(asset: _showcaseAssets[index]),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        // Dots — tappable, animated.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _showcaseAssets.length; i++)
              GestureDetector(
                onTap: () => _controller.animateToPage(
                  i,
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutCubic,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOut,
                    width: i == _page ? 22 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? AppColors.textPrimary
                          : AppColors.textQuaternary,
                      borderRadius: AppRadius.fullAll,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// One framed capture: rounded, hairline border, a whisper of depth.
class _ShowcaseCard extends StatelessWidget {
  const _ShowcaseCard({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.darkBorder),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withAlpha(120),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(27),
          child: Image.asset(
            asset,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            // The screenshots ship with the app; a missing asset is a build
            // error, but a graceful frame beats a red screen in a profile run.
            errorBuilder: (_, _, _) => Container(
              color: AppColors.darkSurface,
              alignment: Alignment.center,
              child: const Icon(
                PhosphorIconsRegular.squaresFour,
                size: 32,
                color: AppColors.textQuaternary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shared pieces ──────────────────────────────────────────────────────────

/// Section header in the app's house style — small glyph, tracked caps, then
/// a hairline running out to the right edge.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textTertiary),
        const SizedBox(width: 10),
        Text(
          title,
          style: AppTypography.labelSmall.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 2.4,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        const Expanded(
          child: Divider(color: AppColors.darkBorder, height: 1),
        ),
      ],
    );
  }
}

/// The quiet sign-off at the foot of the page.
class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return FadeSlideTransition(
      delay: const Duration(milliseconds: 800),
      child: Column(
        children: [
          const Divider(color: AppColors.darkBorder, height: 1),
          const SizedBox(height: AppSpacing.xl),
          Text(
            '${AppConstants.appName} · Operations management for multi-branch teams',
            textAlign: TextAlign.center,
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}

// ─── Atmosphere ─────────────────────────────────────────────────────────────

/// The landing atmosphere — the splash's ambient light language: a faint wide
/// halo for depth plus a soft central pool behind the hero that slowly
/// breathes, so the page feels alive before anything is touched. Strictly
/// monochrome (white light falling off into black), and repainted only inside
/// a RepaintBoundary so the scroll above never re-triggers the gradient.
class _AmbientBackdrop extends StatefulWidget {
  const _AmbientBackdrop();

  @override
  State<_AmbientBackdrop> createState() => _AmbientBackdropState();
}

class _AmbientBackdropState extends State<_AmbientBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 6400),
  )..repeat(reverse: true);

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
          final glowAlpha = (10 + 7 * breath).round();
          // Two pools of light: the hero glow near the top, and a fainter one
          // low in the page so the scroll journey never hits flat black.
          return DecoratedBox(
            decoration: const BoxDecoration(color: AppColors.black),
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.55),
                      radius: 0.9 + 0.08 * breath,
                      colors: [
                        AppColors.white.withAlpha(glowAlpha),
                        AppColors.transparent,
                      ],
                      stops: const [0, 1],
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.6, 0.85),
                      radius: 0.7 + 0.06 * breath,
                      colors: [
                        AppColors.white.withAlpha((glowAlpha * 0.5).round()),
                        AppColors.transparent,
                      ],
                      stops: const [0, 1],
                    ),
                  ),
                ),
                // A barely-there vertical sheen so large black fields read as
                // composed rather than empty.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.transparent,
                        Color(0x03FFFFFF),
                        AppColors.transparent,
                      ],
                      stops: [0, 0.5, 1],
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
