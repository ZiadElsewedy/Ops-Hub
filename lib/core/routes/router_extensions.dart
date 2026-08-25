import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Navigating a [GoRouter] safely from **outside the widget tree** — which is
/// where every push-notification tap runs.
///
/// The trap both helpers exist for: `createRouter` returns a usable object
/// immediately, but the router has no *stack* until the `Router` widget mounts
/// and parses `initialLocation`. A cold-start tap lands squarely in that
/// window — OpsHub holds the routed app behind BOTH the bootstrap and the splash
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

  /// The location of the route the user is actually **looking at**, or `null`
  /// when this router has no stack yet.
  ///
  /// Not the same question as [currentLocationOrNull], which reports the match
  /// list's own `uri` — the last location go_router *routed* to. An imperative
  /// `push` appends a match without rewriting that uri, so after the ordinary
  /// `go('/manager') → push('/chat')` the two disagree: `currentLocationOrNull`
  /// still says `/manager` while the inbox is on screen. Every chat destination
  /// in OpsHub is reached by `push` (the bottom nav, the notification deep link),
  /// so "is the user on Chat right now?" can only be answered here.
  ///
  /// Use [currentLocationOrNull] for the duplicate-push guard it was written
  /// for; use this one to decide whether a screen is already in front of the
  /// user.
  String? get topLocationOrNull {
    final configuration = routerDelegate.currentConfiguration;
    return configuration.isEmpty ? null : configuration.last.matchedLocation;
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
    // Already attached (the ordinary foreground/background tap): navigate now.
    if (currentLocationOrNull != null) {
      action();
      return;
    }
    if (maxFrames <= 0) return;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        if (currentLocationOrNull != null) {
          // The router attached THIS frame. Do NOT navigate synchronously here:
          // the `Router` widget is parsing `initialLocation` in the same frame,
          // so the Navigator + RouteConfiguration an imperative `go`/`push`
          // needs are not wired yet — pushing now is what surfaced as go_router
          // "no routes for location" on a cold-start notification tap (every
          // notification type, since every deep link funnels through here). Let
          // the mount frame finish, then navigate on the next one.
          WidgetsBinding.instance
            ..addPostFrameCallback((_) => action())
            ..scheduleFrame();
          return;
        }
        whenReady(action, maxFrames: maxFrames - 1);
      })
      // A post-frame callback only runs if a frame is actually produced. The
      // splash is animating so one normally is, but asking for it explicitly
      // means the retry cannot stall on an idle frame scheduler.
      ..scheduleFrame();
  }
}
