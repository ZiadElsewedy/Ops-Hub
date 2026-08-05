/// **How DROP goes back.** One decision, one home.
///
/// On **iOS** the app navigates back the way Apple's own apps do: the
/// interactive left-edge swipe is the affordance, and the app bar carries no
/// automatic back chevron. Every other platform keeps its own convention
/// untouched — Android keeps the app-bar back button, the system back gesture
/// and the Material transition; desktop keeps the in-header back control on
/// `AdaptiveScaffold`.
///
/// That contract is only safe if it holds on **both** sides at once:
///
/// * the chrome hides the chevron (see [showsBackChevron]), **and**
/// * the route actually carries the gesture — a route built on
///   `CupertinoRouteTransitionMixin` ([appPageRoute] here, `CupertinoPage` in
///   `app_router.dart`).
///
/// A screen pushed on a plain `PageRouteBuilder` under a chevron-less app bar
/// has neither a button nor a gesture: a dead end. So every imperative push of
/// a full **page** goes through [appPageRoute].
///
/// Deliberate exceptions, all of which match iOS itself:
///
/// * A **full-screen modal** (`fullscreenDialog: true`) has no back gesture on
///   iOS either — it keeps its explicit Close/Cancel control.
/// * A screen that blocks popping (`PopScope(canPop: false)`, e.g. the pending
///   review drill-down) disables the gesture, so it must supply its own
///   explicit `leading`.
/// * A media viewer keeps a visible dismiss control, because a zoomed
///   `InteractiveViewer` competes with the edge drag.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// True when [platform] navigates back by the iOS edge gesture alone.
bool isGestureBackPlatform(TargetPlatform platform) =>
    platform == TargetPlatform.iOS;

/// Whether the chrome around [context] should still draw a back chevron.
///
/// False on iOS — the swipe is the affordance there. Reads the platform off
/// the [Theme] so a test (or a platform override) can exercise both branches.
bool showsBackChevron(BuildContext context) =>
    !isGestureBackPlatform(Theme.of(context).platform);

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

/// A pushed full-page route that honours the platform's back contract.
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
