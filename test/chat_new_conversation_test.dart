import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/widgets/premium_button.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/domain/repositories/auth_repository.dart';
import 'package:drop/features/chat/domain/usecases/get_chat_directory.dart';
import 'package:drop/features/chat/domain/entities/chat_attachment_download.dart';
import 'package:drop/features/chat/domain/entities/chat_conversation.dart';
import 'package:drop/features/chat/domain/entities/chat_message.dart';
import 'package:drop/features/chat/domain/entities/chat_outgoing_attachment.dart';
import 'package:drop/features/chat/domain/entities/chat_read_receipt.dart';
import 'package:drop/features/chat/domain/repositories/chat_repository.dart';
import 'package:drop/features/chat/domain/usecases/get_conversations.dart';
import 'package:drop/features/chat/domain/usecases/start_conversation.dart';
import 'package:drop/features/chat/presentation/cubit/chat_list_cubit.dart';
import 'package:drop/features/chat/presentation/cubit/new_chat_cubit.dart';
import 'package:drop/features/chat/presentation/pages/chat_screen.dart';
import 'package:drop/features/chat/presentation/pages/new_chat_screen.dart'
    show NewChatView;
import 'package:drop/features/chat/presentation/widgets/chat_conversation_tile.dart';

// ─── Fakes ─────────────────────────────────────────────────────────────

UserEntity _me() => const UserEntity(
      uid: 'me-fb', email: 'me@drop.test', displayName: 'Me',
      authProvider: 'password', branchId: 'b1');

UserEntity _teammate(String uid, String name,
        {UserRole role = UserRole.employee,
        String branchId = 'b1',
        bool isActive = true}) =>
    UserEntity(
      uid: uid, email: '$uid@drop.test', displayName: name,
      authProvider: 'password', branchId: branchId, role: role,
      isActive: isActive);

/// An admin: branchless, exactly as `createUserAccount` provisions them.
UserEntity _admin(String uid, String name) => UserEntity(
      uid: uid, email: '$uid@drop.test', displayName: name,
      authProvider: 'password', role: UserRole.admin);

UserEntity _adminMe() => _admin('me-fb', 'Me');

ChatConversation _conversation(String id, String counterpartInternalId) =>
    ChatConversation(
      id: id,
      participantIds: ['me-internal', counterpartInternalId],
      createdAt: DateTime(2026, 7, 22),
      lastMessageAt: DateTime(2026, 7, 22, 12),
    );

ChatConversationSummary _summary(String id, String counterpartInternalId) =>
    ChatConversationSummary(
      id: id,
      counterpartUserId: counterpartInternalId,
      participantIds: ['me-internal', counterpartInternalId],
      createdAt: DateTime(2026, 7, 22),
      lastMessageAt: DateTime(2026, 7, 22, 12),
    );

/// Directory fake. The chat directory is a single unfiltered read, so the fake
/// records whether anything ever went down a branch-scoped path (it must not).
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this.everyone);

  /// Every user in the org, as `getAllUsers` would return them.
  final List<UserEntity> everyone;

  final List<String> branchReads = [];
  int allUsersReads = 0;

  @override
  Future<List<UserEntity>> getAllUsers() async {
    allUsersReads++;
    return everyone;
  }

  @override
  Future<List<UserEntity>> getUsersByBranch(String branchId) async {
    branchReads.add(branchId);
    return everyone.where((u) => u.branchId == branchId).toList();
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Chat repo fake: start records the target ref and returns a scripted
/// conversation; list returns whatever the test scripts (so the post-start
/// refresh finds the conversation with its server counterpart id).
class _FakeChatRepository implements ChatRepository {
  @override
  Future<List<ChatConversationSummary>> getCachedConversations() async =>
      const [];

  _FakeChatRepository({
    required this.onStart,
    this.pages = const [],
  });

  final ChatConversation Function(String targetRef) onStart;
  final List<ChatConversationPage> pages;
  final List<String> startedWith = [];
  int _listCall = 0;

  @override
  Future<ChatConversation> startConversation(String targetUserRef) async {
    startedWith.add(targetUserRef);
    return onStart(targetUserRef);
  }

  @override
  Future<ChatConversationPage> getConversations({int? limit, String? cursor}) async {
    final page = pages.isEmpty
        ? const ChatConversationPage(items: [])
        : pages[_listCall < pages.length ? _listCall : pages.length - 1];
    _listCall++;
    return page;
  }

  @override
  Future<ChatConversation> getConversation(String id) =>
      throw UnimplementedError();
  @override
  Future<ChatMessagePage> getMessageHistory(
          {required String conversationId, int? limit, String? cursor}) =>
      throw UnimplementedError();
  @override
  Future<ChatMessage> sendMessage(
          {required String conversationId,
          required String idempotencyKey,
          String? content,
          ChatOutgoingAttachment? attachment,
          String? replyToMessageId,
          void Function(int sent, int total)? onSendProgress}) =>
      throw UnimplementedError();
  @override
  Future<ChatReadReceipt> markMessagesRead(
          {required String conversationId, required BigInt upToSeq}) =>
      throw UnimplementedError();
  @override
  Future<void> deleteMessageForMe(
          {required String conversationId, required String messageId}) =>
      throw UnimplementedError();
  @override
  Future<ChatMessage> deleteMessageForEveryone(
          {required String conversationId, required String messageId}) =>
      throw UnimplementedError();
  @override
  Future<ChatAttachmentDownload> getAttachmentDownloadUrl(
          {required String conversationId, required String messageId}) =>
      throw UnimplementedError();
}

ChatListCubit _listCubit(_FakeChatRepository repo) => ChatListCubit(
      getConversations: GetConversations(repo),
      startConversation: StartConversation(repo),
    );

void main() {
  group('inbox entry points', () {
    testWidgets('empty inbox shows the Start Chat CTA', (tester) async {
      final repo = _FakeChatRepository(
        onStart: (_) => _conversation('c1', 'x'),
        pages: const [ChatConversationPage(items: [])],
      );
      final list = _listCubit(repo);
      await tester.pumpWidget(MaterialApp(
        home: BlocProvider.value(value: list, child: const ChatScreen()),
      ));
      await tester.pump();
      await tester.pump();

      expect(find.text('No conversations yet'), findsOneWidget);
      final cta = find.widgetWithText(PremiumButton, 'Start Chat');
      expect(cta, findsOneWidget);
      await list.close();
    });

    testWidgets('FAB is present even when conversations exist', (tester) async {
      final repo = _FakeChatRepository(
        onStart: (_) => _conversation('c1', 'x'),
        pages: [ChatConversationPage(items: [_summary('c1', 'u-int')])],
      );
      final list = _listCubit(repo);
      await tester.pumpWidget(MaterialApp(
        home: BlocProvider.value(value: list, child: const ChatScreen()),
      ));
      await tester.pump();
      await tester.pump();

      expect(find.byType(ChatConversationTile), findsOneWidget); // has convos
      expect(find.widgetWithText(FloatingActionButton, 'New Chat'),
          findsOneWidget); // FAB still there
      await list.close();
    });
  });

  group('teammate picker', () {
    Widget host(ChatListCubit list, _FakeAuthRepository auth,
        {required void Function(String) onNavigate, UserEntity? me}) {
      final router = GoRouter(
        initialLocation: '/picker',
        routes: [
          GoRoute(
            path: '/picker',
            builder: (context, state) => MultiBlocProvider(
              providers: [
                BlocProvider.value(value: list),
                BlocProvider(
                  create: (_) => NewChatCubit(
                    getChatDirectory: GetChatDirectory(auth),
                    currentUser: me ?? _me(),
                  ),
                ),
              ],
              child: const NewChatView(),
            ),
          ),
          GoRoute(
            path: RouteNames.chatConversationPattern,
            builder: (_, state) {
              final id = state.pathParameters['conversationId']!;
              onNavigate(id);
              return Scaffold(body: Text('THREAD $id'));
            },
          ),
        ],
      );
      return MaterialApp.router(routerConfig: router);
    }

    testWidgets('lists teammates (excludes current user) with name and role',
        (tester) async {
      final auth = _FakeAuthRepository([
        _me(),
        _teammate('u-sara', 'Sara K', role: UserRole.manager),
        _teammate('u-omar', 'Omar N'),
      ]);
      final repo = _FakeChatRepository(onStart: (_) => _conversation('c1', 'x'));
      final list = _listCubit(repo);
      await tester.pumpWidget(host(list, auth, onNavigate: (_) {}));
      await tester.pump();
      await tester.pump();

      expect(find.text('Sara K'), findsOneWidget);
      expect(find.text('Omar N'), findsOneWidget);
      expect(find.text('Store Manager'), findsOneWidget);
      expect(find.text('Me'), findsNothing); // current user excluded
      await list.close();
    });

    testWidgets('search filters the teammate list', (tester) async {
      final auth = _FakeAuthRepository([
        _teammate('u-sara', 'Sara K'),
        _teammate('u-omar', 'Omar N'),
      ]);
      final list =
          _listCubit(_FakeChatRepository(onStart: (_) => _conversation('c1', 'x')));
      await tester.pumpWidget(host(list, auth, onNavigate: (_) {}));
      await tester.pump();
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'omar');
      await tester.pump();
      expect(find.text('Omar N'), findsOneWidget);
      expect(find.text('Sara K'), findsNothing);
      await list.close();
    });

    testWidgets('selecting a teammate creates a new conversation and navigates',
        (tester) async {
      final auth = _FakeAuthRepository([_teammate('u-omar', 'Omar N')]);
      final repo = _FakeChatRepository(
        onStart: (ref) => _conversation('c-new', 'omar-int'),
        // After start, the refresh returns the new conversation summary.
        pages: [
          const ChatConversationPage(items: []), // initial list load
          ChatConversationPage(items: [_summary('c-new', 'omar-int')]),
        ],
      );
      final list = _listCubit(repo);
      String? navigatedTo;
      await tester.pumpWidget(
          host(list, auth, onNavigate: (id) => navigatedTo = id));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Omar N'));
      await tester.pumpAndSettle();

      expect(repo.startedWith, ['u-omar']); // called StartConversation with uid
      expect(navigatedTo, 'c-new'); // navigated to the conversation
      expect(find.text('THREAD c-new'), findsOneWidget);
      await list.close();
    });

    testWidgets(
        'selecting a teammate you already chat with opens the existing thread',
        (tester) async {
      final auth = _FakeAuthRepository([_teammate('u-omar', 'Omar N')]);
      // Server is idempotent: start returns the SAME existing conversation id.
      final repo = _FakeChatRepository(
        onStart: (_) => _conversation('c-existing', 'omar-int'),
        pages: [
          ChatConversationPage(items: [_summary('c-existing', 'omar-int')]),
          ChatConversationPage(items: [_summary('c-existing', 'omar-int')]),
        ],
      );
      final list = _listCubit(repo);
      String? navigatedTo;
      await tester.pumpWidget(
          host(list, auth, onNavigate: (id) => navigatedTo = id));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Omar N'));
      await tester.pumpAndSettle();

      expect(repo.startedWith, ['u-omar']);
      expect(navigatedTo, 'c-existing'); // opened existing, not a duplicate
      await list.close();
    });

    // ─── Flat access model ─────────────────────────────────────────────
    // Chat is not org-scoped: every active user may message every other one.
    // No branch predicate, no role predicate, in any layer.

    testWidgets('staff see every role, including admins and other branches',
        (tester) async {
      final auth = _FakeAuthRepository([
        _me(), // branch b1
        _teammate('u-omar', 'Omar N'), // branch b1
        _teammate('u-sara', 'Sara K', role: UserRole.manager, branchId: 'b2'),
        _admin('u-dina', 'Dina A'), // branchless
      ]);
      final list =
          _listCubit(_FakeChatRepository(onStart: (_) => _conversation('c1', 'x')));
      await tester.pumpWidget(host(list, auth, onNavigate: (_) {}));
      await tester.pump();
      await tester.pump();

      expect(find.text('Omar N'), findsOneWidget); // same branch
      expect(find.text('Sara K'), findsOneWidget); // OTHER branch
      expect(find.text('Dina A'), findsOneWidget); // branchless admin
      expect(find.text('Me'), findsNothing); // caller excluded
      // The directory is one unfiltered read — never a branch query.
      expect(auth.allUsersReads, 1);
      expect(auth.branchReads, isEmpty);
      await list.close();
    });

    testWidgets('a branchless admin sees everyone too', (tester) async {
      final auth = _FakeAuthRepository([
        _adminMe(), // branchId == null
        _teammate('u-omar', 'Omar N'),
        _teammate('u-sara', 'Sara K', role: UserRole.manager, branchId: 'b2'),
      ]);
      final list =
          _listCubit(_FakeChatRepository(onStart: (_) => _conversation('c1', 'x')));
      await tester.pumpWidget(
          host(list, auth, onNavigate: (_) {}, me: _adminMe()));
      await tester.pump();
      await tester.pump();

      expect(find.text('Omar N'), findsOneWidget);
      expect(find.text('Sara K'), findsOneWidget);
      expect(find.text('No teammates yet'), findsNothing);
      expect(auth.branchReads, isEmpty);
      await list.close();
    });

    testWidgets('deactivated users are hidden', (tester) async {
      final auth = _FakeAuthRepository([
        _teammate('u-omar', 'Omar N'),
        _teammate('u-gone', 'Gone Person', isActive: false),
      ]);
      final list =
          _listCubit(_FakeChatRepository(onStart: (_) => _conversation('c1', 'x')));
      await tester.pumpWidget(host(list, auth, onNavigate: (_) {}));
      await tester.pump();
      await tester.pump();

      expect(find.text('Omar N'), findsOneWidget);
      expect(find.text('Gone Person'), findsNothing);
      await list.close();
    });

    testWidgets('a legacy doc with no isActive field is treated as active',
        (tester) async {
      // UserEntity defaults isActive to true, so the filter must not drop it.
      const legacy = UserEntity(
          uid: 'u-legacy', email: 'legacy@drop.test', displayName: 'Legacy P',
          authProvider: 'password');
      final auth = _FakeAuthRepository([legacy]);
      final list =
          _listCubit(_FakeChatRepository(onStart: (_) => _conversation('c1', 'x')));
      await tester.pumpWidget(host(list, auth, onNavigate: (_) {}));
      await tester.pump();
      await tester.pump();

      expect(find.text('Legacy P'), findsOneWidget);
      await list.close();
    });
  });
}
