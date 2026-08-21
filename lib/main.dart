import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:opshub/core/config/app_environment.dart';
import 'package:opshub/core/di/injection.dart';
import 'package:opshub/core/observability/crash_reporter.dart';
import 'package:opshub/core/routes/app_router.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/core/routes/route_names.dart';
import 'package:opshub/core/services/usage_tracker.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/utils/app_logger.dart';
import 'package:opshub/core/utils/platform_capabilities.dart';
import 'package:opshub/core/theme/app_theme.dart';
import 'package:opshub/core/widgets/connectivity_scope.dart';
import 'package:opshub/core/widgets/dismiss_keyboard.dart';
import 'package:opshub/core/widgets/in_app_notification_host.dart';
import 'package:opshub/features/chat/presentation/widgets/chat_notification_listener.dart';
import 'package:opshub/features/chat/presentation/widgets/chat_unread_launch_hint.dart';
import 'package:opshub/features/chat/presentation/chat_deep_link_navigation.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:opshub/features/auth/presentation/cubit/auth_state.dart';
import 'package:opshub/features/auth/presentation/pages/splash_page.dart';
import 'package:opshub/features/sales/presentation/cubit/sales_month_cubit.dart';
import 'package:opshub/features/notifications/domain/notification_deep_link.dart';
import 'package:opshub/features/notifications/presentation/notification_navigation.dart';
import 'package:opshub/firebase_options.dart';

/// Background FCM handler. The push carries a `notification` block, so the OS
/// renders it while the app is backgrounded/terminated — no background data
/// processing is needed here. Must be a top-level, vm:entry-point function.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Lets the notification service surface foreground pushes as in-app snackbars.
final GlobalKey<ScaffoldMessengerState> _messengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// The app router, created once so the FCM tap handler can navigate.
GoRouter? _router;

/// Firebase/DI are initialized lazily after Flutter has painted the first black
/// frame. This keeps retries idempotent if startup fails before the router is
/// ready.
bool _dependenciesInitialized = false;

void main() {
  // Everything — including ensureInitialized and runApp — lives inside ONE
  // guarded zone, so a zone-level uncaught error is always captured (4th
  // crash funnel, alongside FlutterError.onError / PlatformDispatcher.onError
  // / the isolate listener installed below).
  runZonedGuarded<Future<void>>(_bootstrap, CrashReporter.recordZoneError);
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Crash capture FIRST — everything after this line is covered.
  CrashReporter.install();
  // Global debug logging (debug builds only): cubit lifecycle + state changes
  // via the observer; navigation via the router observers; function/timing
  // logs via AppLog at call sites. (Breadcrumbs + crash persistence stay on
  // in release.)
  if (kDebugMode) Bloc.observer = AppBlocObserver();
  // Paint the native-matching black frame immediately. Firebase, DI, session
  // restore, and home-critical cache warm-up start after that first frame while
  // the platform-appropriate launch intro is already visible.
  runApp(const LaunchApp());

  // If the previous session crashed, surface the persisted report for export
  // (fire-and-forget — never delays startup).
  unawaited(_surfacePendingCrashReport());
}

/// Owns the cold-start rendezvous: the routed app is mounted only after both
/// the platform intro and the app bootstrap have completed.
class LaunchApp extends StatefulWidget {
  const LaunchApp({super.key});

  @override
  State<LaunchApp> createState() => _LaunchAppState();
}

class _LaunchAppState extends State<LaunchApp> {
  GoRouter? _readyRouter;
  Object? _bootstrapError;
  bool _animationFinished = false;
  bool _bootstrapping = false;

  bool get _canEnterApp => _animationFinished && _readyRouter != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startBootstrap());
  }

  void _startBootstrap() {
    if (_bootstrapping) return;
    setState(() {
      _bootstrapping = true;
      _bootstrapError = null;
    });
    _initializeRuntime()
        .then((router) {
          if (!mounted) return;
          setState(() {
            _readyRouter = router;
            _bootstrapping = false;
          });
        })
        .catchError((Object error, StackTrace stackTrace) {
          AppLog.error('boot', 'startup failed', error, stackTrace);
          if (!mounted) return;
          setState(() {
            _bootstrapError = error;
            _bootstrapping = false;
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    if (_canEnterApp) return App(router: _readyRouter!);

    return MaterialApp(
      title: 'OpsHub',
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      home: SplashPage(
        bootstrapError: _bootstrapError,
        isBootstrapping: _bootstrapping,
        onRetry: _startBootstrap,
        onAnimationComplete: () {
          if (!mounted || _animationFinished) return;
          setState(() => _animationFinished = true);
        },
      ),
    );
  }
}

/// Ceilings for the cold-start bootstrap so a slow or unreachable backend can
/// never freeze the launch screen on its final static frame. The splash is
/// shown until `_initializeRuntime` returns a router (main's rendezvous), so an
/// unbounded await here is an indefinite hang on the frozen logo. Each phase
/// either degrades (session/warm-up: enter the app anyway and let the auth
/// stream + lazy screens catch up) or surfaces the retryable startup-error
/// screen (Firebase: the one hard precondition) — never an endless hang.
const Duration _firebaseInitTimeout = Duration(seconds: 20);
const Duration _sessionRestoreTimeout = Duration(seconds: 10);
const Duration _warmupTimeout = Duration(seconds: 8);

Future<GoRouter> _initializeRuntime() async {
  // Startup banner — states which backend this build targets. The URL is a pure
  // function of build mode (see AppEnvironment), so this is the ground truth:
  // "Development / Debug / localhost" for `flutter run`, "Production / Release /
  // Railway" for any release artifact.
  debugPrint(AppEnvironment.current.startupBanner);

  if (Firebase.apps.isEmpty) {
    // Firebase is the one true precondition — everything downstream needs it.
    // Bound it so it can't hang the splash forever; on timeout the throw flows
    // to `_startBootstrap`'s catchError and surfaces the startup-error screen
    // (with Try again), never an endless static logo.
    await AppLog.time(
      'boot',
      'Firebase.initializeApp',
      () => Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ),
    ).timeout(_firebaseInitTimeout);
  }

  if (!_dependenciesInitialized) {
    // Must be configured before the first Firestore operation.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    AppDependencies.init();
    UsageTracker.init(FirebaseFirestore.instance);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    _dependenciesInitialized = true;
  }

  // Session restore is best-effort *for rendering*: a stalled profile read must
  // not freeze the splash. On timeout we enter the app with whatever auth state
  // exists (worst case the router lands on login); the AuthCubit finishes the
  // read on its own and the router — refreshed by the auth stream — re-routes to
  // the correct home once it lands.
  try {
    await AppLog.time(
      'auth',
      'restoreSession',
      AppDependencies.authCubit.restoreSession,
    ).timeout(_sessionRestoreTimeout);
  } on TimeoutException {
    AppLog.warning('boot', 'restoreSession timed out — entering app anyway');
  }

  final user = AppDependencies.authCubit.state.maybeWhen(
    authenticated: (value) => value,
    orElse: () => null,
  );
  if (user != null && user.hasAppAccess) {
    // Only the existing home-critical, cache-backed scopes are warmed. Feature
    // screens such as schedule, swaps, cases, and templates remain lazy.
    //
    // Warm-up is an optimization, never a gate: bound it so a slow backend can't
    // hold the splash on its final static frame. On timeout we enter the app
    // anyway — these scopes keep loading in the background and their screens
    // render as soon as they land. A genuine load *error* (not a hang) still
    // propagates to the startup-error screen, exactly as before.
    final warmup = Future.wait<void>([
      AppDependencies.statisticsCubit.load(user),
      AppDependencies.taskCubit.load(user),
      AppDependencies.branchCubit.loadIfNeeded(),
    ]);
    // Observe the combined future independently so a failure that lands *after*
    // the timeout branch has already moved on can't become an unobserved async
    // error (which the zone funnel would report as a crash). `ignore()` silences
    // only this listener; the `await` below still surfaces an error that arrives
    // *before* the timeout, exactly as the original unguarded
    // `await Future.wait(...)` did.
    warmup.ignore();
    try {
      await warmup.timeout(_warmupTimeout);
    } on TimeoutException {
      AppLog.warning('boot', 'home-critical warm-up timed out — entering app');
    }
  }

  final router = _router ??= createRouter(
    AppDependencies.authCubit,
    initialLocation: _initialLocationFor(AppDependencies.authCubit.state),
  );
  _configureNotificationService();
  _handleAuthState(AppDependencies.authCubit.state);
  return router;
}

String _initialLocationFor(AuthState state) => state.maybeWhen(
  authenticated: (user) {
    if (!user.isActive) return RouteNames.login;
    if (user.mustChangePassword) return RouteNames.forcePasswordChange;
    if (!user.isProfileCompleted) return RouteNames.profileCompletion;
    return RouteNames.homeForRole(user.role);
  },
  orElse: () => RouteNames.login,
);

void _configureNotificationService() {
  // In-app foreground notification: while the user is inside the app, a
  // triggered notification (task approval, swap request, …) raises a polished
  // **top banner** (`InAppNotificationHost`), NOT the old ugly bottom snackbar.
  // A tap deep-links to the same destination a background tap would.
  //
  // Apple platforms are skipped: iOS draws its OWN foreground banner
  // (`setForegroundNotificationPresentationOptions`, set in
  // NotificationService.init), so showing this one as well would double-notify.
  // Android delivers a foreground push to `onMessage` only and the OS shows
  // nothing, so the in-app banner is the whole of the signal there. Chat
  // messages never reach here — they are suppressed in NotificationService and
  // handled by ChatNotificationListener's own banner.
  AppDependencies.notificationService
    ..onForeground = (title, body, data) {
      if (requiresApnsToken) return; // iOS OS banner covers it
      final resolvedTitle = (title == null || title.trim().isEmpty)
          ? 'Notification'
          : title.trim();
      InAppNotificationHost.show(InAppNotification(
        title: resolvedTitle,
        body: body,
        data: data,
      ));
    }
    ..onMessageTap = (data) {
      developer.log(
        'Notification tapped — type=${data['type']} task=${data['taskId']} '
        'route=${data['route']}',
        name: 'fcm',
      );
      final router = _router;
      if (router == null) return;
      // One shared resolver for every tap surface (foreground / background /
      // cold-start / in-app), then one shared *navigator*. Both the resolved
      // target and the unresolved fallback are opened on top of the role home,
      // so a tap can never strand the user on a page with no way back — which
      // is what the old `go(notifications)` fallback did.
      _openTapDestination(router, _resolveTapLocation(data));
    };
  unawaited(AppDependencies.notificationService.init());
}

bool _isChatDestination(String destination) =>
    destination.startsWith('${RouteNames.chat}/');

/// The single navigator behind every push-notification tap. [destination] is
/// whatever [_resolveTapLocation] produced — `null` when nothing safe resolved.
///
/// A chat thread keeps its own opener (its natural parent is the inbox, so it
/// builds home ← inbox ← thread); everything else goes through
/// [openNotificationDeepLink], which guarantees Home sits under the target.
void _openTapDestination(GoRouter router, String? destination) {
  if (destination != null && _isChatDestination(destination)) {
    _openChatNotification(router, destination);
    return;
  }
  openNotificationDeepLink(
    router,
    destination: destination,
    role: _currentRole(),
  );
}

/// The signed-in user's role, or `null` when no session is restored.
UserRole? _currentRole() => AppDependencies.authCubit.state.maybeWhen(
  authenticated: (user) => user.role,
  orElse: () => null,
);

void _openChatNotification(GoRouter router, String destination) {
  final conversationId = Uri.parse(destination).pathSegments.last;
  final role = _currentRole();
  if (role == null) return;
  openChatDeepLink(
    router,
    conversationId,
    role: role,
    args: chatThreadArgsFor(conversationId),
  );
}

/// Resolves an FCM push `data` map to a deep-link location for the signed-in
/// user's role, via the shared [resolveNotificationRoute] resolver. Returns
/// `null` when there is no safe destination.
String? _resolveTapLocation(Map<String, dynamic> data) {
  final role = AppDependencies.authCubit.state.maybeWhen(
    authenticated: (user) => user.role,
    orElse: () => null,
  );
  return resolveNotificationRoute(
    route: data['route']?.toString(),
    payload: data,
    role: role,
  );
}

void _handleAuthState(AuthState state) {
  state.maybeWhen(
    authenticated: (u) {
      CrashContext.userId = u.uid;
      CrashContext.userRole = u.role.value;
      unawaited(AppDependencies.notificationService.registerToken(u.uid));
      AppDependencies.notificationCubit.load(u.uid);
      if (u.hasAppAccess) {
        // Idempotent: cold start has already awaited these; later sign-ins warm
        // the same home-critical scopes while the router advances.
        AppDependencies.statisticsCubit.load(u);
        AppDependencies.taskCubit.load(u);
        AppDependencies.branchCubit.loadIfNeeded();
      }
    },
    unauthenticated: (_) {
      CrashContext.userId = null;
      CrashContext.userRole = null;
      unawaited(AppDependencies.notificationService.forgetUser());
      AppDependencies.notificationCubit.clear();
    },
    orElse: () {},
  );
}

/// Next-launch crash detection (Part 6): when a persisted crash report exists,
/// show a banner offering to copy the full report to the clipboard. Both
/// actions clear the file so the banner appears once per crash.
Future<void> _surfacePendingCrashReport() async {
  final report = await CrashReporter.pendingReport();
  if (report == null) return;
  AppLog.warning('crash', 'previous session crashed — report pending export');

  // Wait for the app's ScaffoldMessenger to mount (first frames).
  ScaffoldMessengerState? messenger;
  for (var i = 0; i < 20 && messenger == null; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    messenger = _messengerKey.currentState;
  }
  if (messenger == null) return;

  messenger.showMaterialBanner(
    MaterialBanner(
      backgroundColor: AppColors.darkSurfaceElevated,
      leading: const Icon(Icons.bug_report_outlined, color: AppColors.error),
      content: const Text(
        'Drop Operations quit unexpectedly last time. You can export the crash report '
        'for debugging.',
        style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: report));
            messenger!
              ..hideCurrentMaterialBanner()
              ..showSnackBar(
                const SnackBar(
                  content: Text('Crash report copied to clipboard'),
                ),
              );
            await CrashReporter.clearPendingReport();
          },
          child: const Text('Copy report'),
        ),
        TextButton(
          onPressed: () async {
            messenger!.hideCurrentMaterialBanner();
            await CrashReporter.clearPendingReport();
          },
          child: const Text('Dismiss'),
        ),
      ],
    ),
  );
}

class App extends StatelessWidget {
  const App({required this.router, super.key});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: AppDependencies.authCubit),
        BlocProvider.value(value: AppDependencies.profileCubit),
        BlocProvider.value(value: AppDependencies.taskCubit),
        BlocProvider.value(value: AppDependencies.branchCubit),
        BlocProvider.value(value: AppDependencies.adminUsersCubit),
        BlocProvider.value(value: AppDependencies.statisticsCubit),
        BlocProvider.value(value: AppDependencies.scheduleCubit),
        BlocProvider.value(value: AppDependencies.todayCoverageCubit),
        BlocProvider.value(value: AppDependencies.shiftSwapCubit),
        BlocProvider.value(value: AppDependencies.branchOperationsCubit),
        BlocProvider.value(value: AppDependencies.broadcastCubit),
        BlocProvider.value(value: AppDependencies.broadcastTemplateCubit),
        BlocProvider.value(value: AppDependencies.broadcastScheduleCubit),
        BlocProvider.value(value: AppDependencies.notificationCubit),
        BlocProvider.value(value: AppDependencies.caseListCubit),
        BlocProvider.value(value: AppDependencies.chatListCubit),
        BlocProvider.value(value: AppDependencies.requestsListCubit),
        BlocProvider.value(value: AppDependencies.attendanceCubit),
        BlocProvider.value(value: AppDependencies.attendanceAdminCubit),
        BlocProvider<SalesMonthCubit>.value(
          value: AppDependencies.salesMonthCubit,
        ),
      ],
      // Register / clear the FCM token as the auth session changes.
      child: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) => _handleAuthState(state),
        child: MaterialApp.router(
          title: 'OpsHub',
          theme: AppTheme.dark,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          scaffoldMessengerKey: _messengerKey,
          routerConfig: router,
          debugShowCheckedModeBanner: false,
          // Above the router so a new chat message can raise an in-app banner
          // from any screen (suppressed for the conversation on screen).
          //
          // `ConnectivityScope` is outermost so every screen — and every
          // `requireOnline` call inside one — can read the connection state.
          // It does not block the app: the offline rule is "gate the actions,
          // never the app" (see the class doc for why).
          builder: (context, child) => ConnectivityScope(
            child: OfflineBar(
              child: ChatNotificationListener(
                router: router,
                // The once-per-launch unread hint sits under the incoming-message
                // listener: same inbox load, but it reads the *first settled*
                // one and slides a self-dismissing banner from the top. Inside
                // OfflineBar, so an offline launch stacks bar-then-hint rather
                // than overlapping.
                child: ChatUnreadLaunchHint(
                  router: router,
                  // The generic in-app notification banner (task approval, swap,
                  // …) — a polished top banner, replacing the removed bottom
                  // snackbar. A tap deep-links through the shared resolver.
                  child: InAppNotificationHost(
                    onOpen: (data) =>
                        _openTapDestination(router, _resolveTapLocation(data)),
                    // App-wide tap-outside-to-dismiss for the soft keyboard.
                    // Wraps the router's Navigator, so every screen, modal sheet
                    // and dialog inherits it (typing a task title, a chat
                    // message, a sales note, … now lowers on a tap away).
                    child: DismissKeyboard(
                      child: child ?? const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
