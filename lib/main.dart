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
import 'package:drop/core/config/app_environment.dart';
import 'package:drop/core/di/injection.dart';
import 'package:drop/core/observability/crash_reporter.dart';
import 'package:drop/core/routes/app_router.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/services/usage_tracker.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/utils/app_logger.dart';
import 'package:drop/core/utils/platform_capabilities.dart';
import 'package:drop/core/theme/app_theme.dart';
import 'package:drop/core/widgets/connectivity_scope.dart';
import 'package:drop/features/chat/presentation/widgets/chat_notification_listener.dart';
import 'package:drop/features/chat/presentation/chat_deep_link_navigation.dart';
import 'package:drop/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:drop/features/auth/presentation/cubit/auth_state.dart';
import 'package:drop/features/auth/presentation/pages/splash_page.dart';
import 'package:drop/features/sales/presentation/cubit/sales_month_cubit.dart';
import 'package:drop/features/notifications/domain/notification_deep_link.dart';
import 'package:drop/firebase_options.dart';

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
      title: 'DROP',
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

Future<GoRouter> _initializeRuntime() async {
  // Startup banner — states which backend this build targets. The URL is a pure
  // function of build mode (see AppEnvironment), so this is the ground truth:
  // "Development / Debug / localhost" for `flutter run`, "Production / Release /
  // Railway" for any release artifact.
  debugPrint(AppEnvironment.current.startupBanner);

  if (Firebase.apps.isEmpty) {
    await AppLog.time(
      'boot',
      'Firebase.initializeApp',
      () => Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ),
    );
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

  await AppLog.time(
    'auth',
    'restoreSession',
    AppDependencies.authCubit.restoreSession,
  );

  final user = AppDependencies.authCubit.state.maybeWhen(
    authenticated: (value) => value,
    orElse: () => null,
  );
  if (user != null && user.hasAppAccess) {
    // Only the existing home-critical, cache-backed scopes are warmed. Feature
    // screens such as schedule, swaps, cases, and templates remain lazy.
    await Future.wait<void>([
      AppDependencies.statisticsCubit.load(user),
      AppDependencies.taskCubit.load(user),
      AppDependencies.branchCubit.loadIfNeeded(),
    ]);
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
  AppDependencies.notificationService
    ..onForeground = (title, body, data) {
      // iOS presents its own foreground banner
      // (`setForegroundNotificationPresentationOptions`, set in
      // NotificationService.init). Showing the in-app snackbar as well would
      // double-notify for the same message, so Apple platforms rely on the OS
      // banner — which is tappable and routes through the same
      // `onMessageOpenedApp` → resolver path, so nothing is lost.
      // ANDROID IS UNCHANGED: it keeps the snackbar, because a foreground push
      // on Android is delivered to `onMessage` only and the OS shows nothing.
      if (requiresApnsToken) return;
      final text = [
        title,
        body,
      ].where((s) => s != null && s.isNotEmpty).join(' — ');
      if (text.isEmpty) return;
      // The foreground push is actionable: "View" deep-links to the same
      // destination a background tap would, so a foreground notification is
      // never a dead end.
      final destination = _resolveTapLocation(data);
      _messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(text),
          action: destination == null
              ? null
              : SnackBarAction(
                  label: 'View',
                  onPressed: () {
                    final router = _router;
                    if (router == null) return;
                    if (_isChatDestination(destination)) {
                      _openChatNotification(router, destination);
                    } else {
                      router.push(destination);
                    }
                  },
                ),
        ),
      );
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
      // cold-start / in-app). A resolvable target is pushed onto the current
      // stack; anything unresolved falls back to the inbox — navigation never
      // crashes on a stale or unknown notification.
      final destination = _resolveTapLocation(data);
      if (destination != null) {
        if (_isChatDestination(destination)) {
          _openChatNotification(router, destination);
        } else {
          router.push(destination);
        }
      } else {
        router.go(RouteNames.notifications);
      }
    };
  unawaited(AppDependencies.notificationService.init());
}

bool _isChatDestination(String destination) =>
    destination.startsWith('${RouteNames.chat}/');

void _openChatNotification(GoRouter router, String destination) {
  final conversationId = Uri.parse(destination).pathSegments.last;
  final role = AppDependencies.authCubit.state.maybeWhen(
    authenticated: (user) => user.role,
    orElse: () => null,
  );
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
    unauthenticated: () {
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
        'DROP quit unexpectedly last time. You can export the crash report '
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
          title: 'DROP',
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
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
