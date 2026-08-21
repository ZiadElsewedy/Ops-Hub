import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:opshub/core/routes/route_names.dart';
import 'package:opshub/core/routes/router_extensions.dart';
import 'package:opshub/features/chat/domain/entities/chat_conversation.dart';
import 'package:opshub/features/chat/domain/repositories/chat_repository.dart';
import 'package:opshub/features/chat/domain/usecases/get_cached_conversations.dart';
import 'package:opshub/features/chat/domain/usecases/get_conversations.dart';
import 'package:opshub/features/chat/domain/usecases/start_conversation.dart';
import 'package:opshub/features/chat/presentation/cubit/chat_list_cubit.dart';
import 'package:opshub/features/chat/presentation/widgets/chat_unread_launch_hint.dart';

/// List-endpoint-only stub. Every other repository call is out of scope for the
/// launch hint and throws through [noSuchMethod] if reached.
class _StubChatRepository implements ChatRepository {
  _StubChatRepository(this.page, {this.cached = const [], this.deferred});

  ChatConversationPage page;
  final List<ChatConversationSummary> cached;

  /// When set, the list endpoint resolves to this instead of [page] — the seam
  /// for holding a load open across the cache paint.
  final Future<ChatConversationPage>? deferred;

  @override
  Future<ChatConversationPage> getConversations({int? limit, String? cursor}) =>
      deferred ?? Future.value(page);

  @override
  Future<List<ChatConversationSummary>> getCachedConversations() async => cached;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

ChatConversationSummary _summary(String id, {int unread = 0}) =>
    ChatConversationSummary(
      id: id,
      counterpartUserId: 'user-$id',
      participantIds: ['me', 'user-$id'],
      createdAt: DateTime(2026, 8, 6),
      lastMessageAt: DateTime(2026, 8, 6, 10),
      unreadCount: unread,
    );

void main() {
  ChatListCubit cubit(_StubChatRepository repo) => ChatListCubit(
        getConversations: GetConversations(repo),
        startConversation: StartConversation(repo),
      );

  GoRouter router({String initialLocation = RouteNames.home}) => GoRouter(
        initialLocation: initialLocation,
        routes: [
          GoRoute(
            path: RouteNames.home,
            builder: (_, _) => const Scaffold(body: Text('Home')),
          ),
          GoRoute(
            path: RouteNames.chat,
            builder: (_, _) => const Scaffold(body: Text('Chat inbox')),
          ),
        ],
      );

  Widget host(ChatListCubit c, GoRouter r, {bool reduceMotion = false}) {
    Widget app = MaterialApp.router(
      routerConfig: r,
      builder: (context, child) => ChatUnreadLaunchHint(
        router: r,
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (reduceMotion) {
      app = MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: app,
      );
    }
    return BlocProvider.value(value: c, child: app);
  }

  testWidgets('announces the launch unread count, then dismisses itself',
      (tester) async {
    final c = cubit(_StubChatRepository(
      ChatConversationPage(items: [_summary('a', unread: 3), _summary('b', unread: 1)]),
    ));
    final r = router();
    await tester.pumpWidget(host(c, r));

    await c.load();
    await tester.pump(); // slide starts
    await tester.pump(const Duration(milliseconds: 300)); // slide lands

    expect(find.text('You have 4 unread messages.'), findsOneWidget);
    expect(find.text('Tap to open Chat.'), findsOneWidget);

    // Still up just before the dismissal, gone after it plays out.
    await tester.pump(const Duration(milliseconds: 3000));
    expect(find.text('You have 4 unread messages.'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('You have 4 unread messages.'), findsNothing);
    expect(r.topLocationOrNull, RouteNames.home);

    await c.close();
  });

  testWidgets('a single unread message reads in the singular', (tester) async {
    final c = cubit(_StubChatRepository(
      ChatConversationPage(items: [_summary('a', unread: 1)]),
    ));
    final r = router();
    await tester.pumpWidget(host(c, r));

    await c.load();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('You have 1 unread message.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await c.close();
  });

  testWidgets('tapping opens the Chat inbox', (tester) async {
    final c = cubit(_StubChatRepository(
      ChatConversationPage(items: [_summary('a', unread: 2)]),
    ));
    final r = router();
    await tester.pumpWidget(host(c, r));

    await c.load();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('You have 2 unread messages.'));
    await tester.pumpAndSettle();

    expect(r.topLocationOrNull, RouteNames.chat);
    expect(find.text('You have 2 unread messages.'), findsNothing);

    await c.close();
  });

  testWidgets('stays silent when the launch lands on Chat', (tester) async {
    final c = cubit(_StubChatRepository(
      ChatConversationPage(items: [_summary('a', unread: 5)]),
    ));
    final r = router(initialLocation: RouteNames.chat);
    await tester.pumpWidget(host(c, r));

    await c.load();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('You have 5 unread messages.'), findsNothing);
    await c.close();
  });

  testWidgets('stays silent when a chat deep link pushed Chat on top of home',
      (tester) async {
    // The case the match list's own uri cannot see: home was *routed* to and
    // Chat was *pushed* over it, which is how every chat destination is reached.
    final c = cubit(_StubChatRepository(
      ChatConversationPage(items: [_summary('a', unread: 5)]),
    ));
    final r = router();
    await tester.pumpWidget(host(c, r));
    r.push(RouteNames.chat);
    await tester.pumpAndSettle();

    await c.load();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('You have 5 unread messages.'), findsNothing);
    await c.close();
  });

  testWidgets('shows once per launch — a later unread does not raise it',
      (tester) async {
    final repo = _StubChatRepository(
      ChatConversationPage(items: [_summary('a')]),
    );
    final c = cubit(repo);
    final r = router();
    await tester.pumpWidget(host(c, r));

    // The launch snapshot is empty: nothing to announce, and the hint is spent.
    await c.load();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('unread'), findsNothing);

    repo.page = ChatConversationPage(items: [_summary('a', unread: 7)]);
    await c.load(forceRefresh: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('You have 7 unread messages.'), findsNothing);

    await c.close();
  });

  testWidgets('reduced motion swaps the slide for an instant show and hide',
      (tester) async {
    final c = cubit(_StubChatRepository(
      ChatConversationPage(items: [_summary('a', unread: 2)]),
    ));
    final r = router();
    await tester.pumpWidget(host(c, r, reduceMotion: true));

    await c.load();
    await tester.pump(); // present on the first frame, no slide to wait out
    expect(find.text('You have 2 unread messages.'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 3600));
    await tester.pump();
    expect(find.text('You have 2 unread messages.'), findsNothing);

    await c.close();
  });

  testWidgets('ignores the cache paint and waits for the settled count',
      (tester) async {
    // A durable-cache paint emits `loaded(refreshing: true)` off summaries that
    // carry no server counts. Announcing from it would say "no unread" on every
    // cold start that had a cache.
    final gate = Completer<ChatConversationPage>();
    final repo = _StubChatRepository(
      const ChatConversationPage(items: []),
      cached: [_summary('a')],
      deferred: gate.future,
    );
    final c = ChatListCubit(
      getConversations: GetConversations(repo),
      startConversation: StartConversation(repo),
      getCachedConversations: GetCachedConversations(repo),
    );
    final r = router();
    await tester.pumpWidget(host(c, r));

    final loading = c.load();
    await tester.pump(); // cache paint (refreshing)
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('unread'), findsNothing);

    gate.complete(ChatConversationPage(items: [_summary('a', unread: 2)]));
    await loading;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('You have 2 unread messages.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await c.close();
  });
}
