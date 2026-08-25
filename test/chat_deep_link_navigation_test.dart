import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/core/routes/route_names.dart';
import 'package:opshub/features/chat/presentation/chat_deep_link_navigation.dart';

class _StackObserver extends NavigatorObserver {
  final List<Route<dynamic>> _stack = [];

  List<String?> get locations =>
      _stack.map((route) => route.settings.name).toList(growable: false);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.add(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _stack.remove(oldRoute);
    if (newRoute != null) _stack.add(newRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    super.didRemove(route, previousRoute);
  }
}

GoRouter _router(_StackObserver observer, {String initialLocation = '/'}) =>
    GoRouter(
      initialLocation: initialLocation,
      observers: [observer],
      routes: [
        GoRoute(
          name: 'home',
          path: RouteNames.home,
          builder: (_, _) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          name: 'chat',
          path: RouteNames.chat,
          builder: (_, _) => const Scaffold(body: Text('Chat')),
        ),
        GoRoute(
          name: 'conversation',
          path: RouteNames.chatConversationPattern,
          builder: (_, state) => Scaffold(
            body: Text('Conversation ${state.pathParameters['conversationId']}'),
          ),
        ),
        GoRoute(
          name: 'other',
          path: '/other',
          builder: (_, _) => const Scaffold(body: Text('Other')),
        ),
      ],
    );

void main() {
  testWidgets('notification chat stack matches normal chat navigation', (tester) async {
    final normalObserver = _StackObserver();
    final normal = _router(normalObserver);
    await tester.pumpWidget(MaterialApp.router(routerConfig: normal));
    normal.push(RouteNames.chat);
    normal.push(RouteNames.chatConversation('c-1'));
    await tester.pumpAndSettle();
    final normalLocations = List<String?>.from(normalObserver.locations);

    final notificationObserver = _StackObserver();
    final notification = _router(notificationObserver, initialLocation: '/other');
    await tester.pumpWidget(MaterialApp.router(routerConfig: notification));
    openChatDeepLink(notification, 'c-1', role: UserRole.employee);
    await tester.pumpAndSettle();

    expect(normalLocations, ['home', 'chat', 'conversation']);
    expect(notificationObserver.locations, normalLocations);
    // The delegate's state is the real current location. `push` does not write
    // back to `routeInformationProvider`, so asserting on that would pass or
    // fail for reasons unrelated to the stack.
    expect(notification.state.uri.path, RouteNames.chatConversation('c-1'));
  });

  testWidgets('re-tapping the visible conversation does not add a route', (tester) async {
    final observer = _StackObserver();
    final router = _router(observer);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    openChatDeepLink(router, 'c-1', role: UserRole.employee);
    await tester.pumpAndSettle();
    final before = List<String?>.from(observer.locations);

    openChatDeepLink(router, 'c-1', role: UserRole.employee);
    await tester.pumpAndSettle();

    expect(observer.locations, before);
  });
}
