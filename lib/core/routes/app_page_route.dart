/// **How a pushed screen animates in, and how the user gets back out of it.**
///
/// On **iOS** a pushed page must carry the native interactive left-edge
/// swipe-back, exactly as in Apple's own apps — *in addition to* the app bar's
/// back button, never instead of it. Both affordances are always present.
///
/// The gesture is not free: it exists only on routes built on
/// `CupertinoRouteTransitionMixin` — [appPageRoute] here, `CupertinoPage` in
/// `app_router.dart`, and any `MaterialPageRoute` under the
/// `CupertinoPageTransitionsBuilder` that `AppTheme` installs for iOS. A screen
/// pushed on a hand-rolled `PageRouteBuilder` silently has **no** gesture, and
/// the app is then inconsistent about the most basic interaction it has. So
/// every imperative push of a full **page** goes through [appPageRoute].
///
/// Every other platform keeps its own convention untouched: Android keeps the
/// Material transition and the system back gesture; desktop keeps
/// `AdaptiveScaffold`'s in-header back control.
///
/// Places iOS itself gives no back gesture, so they rely on their button alone:
/// a full-screen modal (`fullscreenDialog: true`), a media viewer (a zoomed
/// `InteractiveViewer` competes with the edge drag), and any screen blocking
/// pop with `PopScope(canPop: false)`.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

/// True when [platform] carries the iOS interactive edge-swipe back gesture.
bool isGestureBackPlatform(TargetPlatform platform) =>
    platform == TargetPlatform.iOS;

/// The default non-iOS page push: slide in from the trailing edge with a short
/// fade, matching the mobile transition `app_router.dart` already uses.
Widget _defaultTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) => SlideTransition(
  position: Tween<Offset>(
    begin: const Offset(1, 0),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
  child: FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: const Interval(0, 0.6)),
    child: child,
  ),
);

/// A pushed full-page route that behaves the way the platform expects.
///
/// * **iOS** → a [CupertinoPageRoute]: the native parallax transition plus the
///   interactive left-edge swipe-back. [transitionsBuilder] and
///   [transitionDuration] are ignored, on purpose — the whole point is that the
///   gesture drives the animation.
/// * **Everywhere else** → a [PageRouteBuilder] running [transitionsBuilder]
///   (default: slide + fade), so existing Android/desktop motion is unchanged.
PageRoute<T> appPageRoute<T>({
  required WidgetBuilder builder,
  RouteTransitionsBuilder? transitionsBuilder,
  Duration transitionDuration = const Duration(milliseconds: 320),
  RouteSettings? settings,
  bool fullscreenDialog = false,
}) {
  if (isGestureBackPlatform(defaultTargetPlatform)) {
    return CupertinoPageRoute<T>(
      builder: builder,
      settings: settings,
      fullscreenDialog: fullscreenDialog,
    );
  }
  return PageRouteBuilder<T>(
    settings: settings,
    fullscreenDialog: fullscreenDialog,
    transitionDuration: transitionDuration,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: transitionsBuilder ?? _defaultTransition,
  );
}
