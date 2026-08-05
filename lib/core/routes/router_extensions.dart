import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Navigating a [GoRouter] safely from **outside the widget tree** — which is
/// where every push-notification tap runs.
///
/// The trap both helpers exist for: `createRouter` returns a usable object
/// immediately, but the router has no *stack* until the `Router` widget mounts
/// and parses `initialLocation`. A cold-start tap lands squarely in that
/// window — DROP holds the routed app behind BOTH the bootstrap and the splash
/// intro (~2s), while `getInitialMessage()` resolves in milliseconds — so at
/// cold start the tap handler almost always runs against an unattached router.
///
/// In that state:
/// * `router.state` throws `Bad state: No element` (it reads `.last` of an
///   empty match list), killing the tap handler mid-way, and
/// * `router.push(...)` has no stack to push onto, so the destination is lost,
/// * while `router.go(...)` *does* work — it writes through the route
///   information provider — which is why the old unresolved-tap fallback
///   `go('/notifications')` was the one path that "worked", and left the user
///   stranded on a page with nothing under it.
extension GoRouterSafeNavigation on GoRouter {
  /// The location currently on top, or `null` when this router has no stack yet.
  ///
  /// A `null` means "nothing is on screen", so a caller comparing against the
  /// current location should treat it as *not* a duplicate.
  String? get currentLocationOrNull {
    final configuration = routerDelegate.currentConfiguration;
    return configuration.isEmpty ? null : configuration.uri.path;
  }

  /// Runs [action] once this router actually has a stack to navigate, so an
  /// imperative `go`/`push` sequence cannot be swallowed by a cold start.
  ///
  /// Runs synchronously when the router is already attached (the ordinary
  /// foreground/background tap). Otherwise it retries once per frame — the
  /// splash is animating, so frames are being produced — and gives up after
  /// [maxFrames], because a tap is not worth leaking a permanent callback if
  /// the app never finishes mounting.
  void whenReady(VoidCallback action, {int maxFrames = 120}) {
    if (currentLocationOrNull != null) {
      action();
      return;
    }
    if (maxFrames <= 0) return;
    WidgetsBinding.instance
      ..addPostFrameCallback(
        (_) => whenReady(action, maxFrames: maxFrames - 1),
      )
      // A post-frame callback only runs if a frame is actually produced. The
      // splash is animating so one normally is, but asking for it explicitly
      // means the retry cannot stall on an idle frame scheduler.
      ..scheduleFrame();
  }
}
