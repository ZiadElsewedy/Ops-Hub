import 'package:go_router/go_router.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/core/routes/route_names.dart';
import 'package:opshub/core/routes/router_extensions.dart';

/// Opens a notification tap's destination **with a back stack that reaches
/// Home**. Every push-tap surface (background, cold start, the foreground
/// banner's "View") goes through here.
///
/// The rule this exists to enforce: a notification tap must never `go` to a
/// leaf page. `go` replaces the whole stack, so that page becomes the *only*
/// route — `Navigator.canPop()` is false, the app bar draws no back button,
/// and on iOS there is no back gesture either (`core/routes/app_page_route.dart`).
/// Only the three role shells carry the bottom nav, so a leaf reached that way
/// has no way back to Home **at all**. That is exactly what the unresolved-tap
/// fallback used to do with `/notifications`: the user landed on the inbox and
/// was stuck there until they killed the app.
///
/// So every tap rebuilds the stack the way [openChatDeepLink] already does:
/// `go(home)` to establish the authenticated root, then `push` the target onto
/// it. Back — or the iOS swipe — always lands on Home.
///
/// This also settles two quieter faults of the old bare `push`: tapping several
/// notifications from the background stacked one page per tap (Back then walked
/// backwards through every notification you had ever opened), and re-tapping the
/// notification for the page already on screen pushed a duplicate of it.
void openNotificationDeepLink(
  GoRouter router, {
  required String? destination,
  required UserRole? role,
}) {
  // Not signed in, or the session has not been restored yet. The redirect gate
  // owns where this device belongs, and anything pushed here would only be
  // bounced to Login — so the tap is a deliberate no-op rather than a flicker.
  if (role == null) return;

  // No safe target — a stale payload, an unknown route, or a recipient who
  // cannot open it. The inbox is the honest destination (the notification is
  // readable there in full). It is a *destination* now, never a replacement
  // for the stack.
  final target = destination ?? RouteNames.notifications;
  final home = RouteNames.homeForRole(role);

  // Deferred until the router has a stack. A cold-start tap resolves long
  // before the routed app mounts, and an imperative `push` onto an unattached
  // router is simply dropped — which is why a notification tapped from a killed
  // app "sometimes did nothing at all".
  router.whenReady(() {
    // Compare against the DELEGATE's location, not `routeInformationProvider
    // .value`: an imperative `push` is delegate-level and never writes back to
    // the provider, so that value still reports whatever the last `go` set.
    // Guarding on it would compare against a stale location and stack a
    // duplicate of the page already open.
    if (router.currentLocationOrNull == target) return;

    router.go(home);
    // A destination that *is* the role home needs no second entry on the stack.
    if (target != home) router.push(target);
  });
}
