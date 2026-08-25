import 'package:flutter/widgets.dart';

/// The four layout classes OpsHub targets. The product is a macOS-first
/// desktop app, so the desktop/ultrawide tiers are first-class — not an
/// afterthought stretched up from mobile.
enum DeviceType { mobile, tablet, desktop, ultrawide }

/// Centralised responsive breakpoints. Keeping the thresholds in one place means
/// every surface (shells, dashboards, tables, dialogs) classifies width the same
/// way instead of sprinkling magic numbers across the codebase.
///
/// Thresholds are measured against the layout's max width (logical pixels):
///   • mobile      < 600
///   • tablet      600 – 1024
///   • desktop     1024 – 1600
///   • ultrawide   ≥ 1600
class Breakpoints {
  Breakpoints._();

  static const double tablet = 600;
  static const double desktop = 1024;
  static const double ultrawide = 1600;

  /// Comfortable maximum content width so dashboards and forms don't sprawl
  /// edge-to-edge on very wide windows (Linear/Notion-style centred column).
  /// Kept fairly tight so cards/heroes read premium rather than oversized.
  static const double contentMaxWidth = 1120;

  /// Width of the persistent desktop navigation sidebar.
  static const double sidebarWidth = 256;

  /// Collapsed (icon-only) sidebar width, used on the narrower desktop tier.
  static const double sidebarCollapsedWidth = 76;

  static DeviceType typeForWidth(double width) {
    if (width < tablet) return DeviceType.mobile;
    if (width < desktop) return DeviceType.tablet;
    if (width < ultrawide) return DeviceType.desktop;
    return DeviceType.ultrawide;
  }
}

/// Ergonomic responsive accessors off any [BuildContext].
extension ResponsiveContextX on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  DeviceType get deviceType => Breakpoints.typeForWidth(screenWidth);

  bool get isMobile => deviceType == DeviceType.mobile;
  bool get isTablet => deviceType == DeviceType.tablet;

  /// True for desktop *and* ultrawide — i.e. any window wide enough to deserve
  /// the persistent sidebar chrome instead of the mobile bottom-nav.
  bool get isDesktop =>
      deviceType == DeviceType.desktop || deviceType == DeviceType.ultrawide;

  bool get isUltrawide => deviceType == DeviceType.ultrawide;

  /// Generous, tier-aware horizontal page padding. Desktop gets the roomy
  /// gutters a native macOS app uses; mobile keeps the original 24.
  double get pagePadding {
    switch (deviceType) {
      case DeviceType.mobile:
        return 20;
      case DeviceType.tablet:
        return 32;
      case DeviceType.desktop:
        return 40;
      case DeviceType.ultrawide:
        return 56;
    }
  }

  /// Number of columns a metric/card grid should use at the current width.
  int get gridColumns {
    switch (deviceType) {
      case DeviceType.mobile:
        return 1;
      case DeviceType.tablet:
        return 2;
      case DeviceType.desktop:
        return 3;
      case DeviceType.ultrawide:
        return 4;
    }
  }
}

/// Builds a different widget per [DeviceType] without each call site repeating
/// the MediaQuery plumbing. Falls back to the nearest provided builder when a
/// specific tier isn't supplied (ultrawide→desktop→tablet→mobile).
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
    this.ultrawide,
  });

  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder? desktop;
  final WidgetBuilder? ultrawide;

  @override
  Widget build(BuildContext context) {
    switch (context.deviceType) {
      case DeviceType.ultrawide:
        return (ultrawide ?? desktop ?? tablet ?? mobile)(context);
      case DeviceType.desktop:
        return (desktop ?? tablet ?? mobile)(context);
      case DeviceType.tablet:
        return (tablet ?? mobile)(context);
      case DeviceType.mobile:
        return mobile(context);
    }
  }
}

/// Centres page content in a comfortable max-width column on wide windows while
/// staying full-bleed on mobile. Use it to wrap dashboard/form bodies so they
/// read like a desktop document, not a stretched phone screen.
class ContentConstraint extends StatelessWidget {
  const ContentConstraint({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.contentMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
