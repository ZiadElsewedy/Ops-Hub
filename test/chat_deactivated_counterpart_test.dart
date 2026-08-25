import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/auth/domain/repositories/auth_repository.dart';
import 'package:opshub/features/chat/domain/entities/chat_conversation.dart';
import 'package:opshub/features/chat/domain/repositories/chat_repository.dart';
import 'package:opshub/features/chat/domain/usecases/get_chat_directory.dart';
import 'package:opshub/features/chat/domain/usecases/get_conversations.dart';
import 'package:opshub/features/chat/domain/usecases/start_conversation.dart';
import 'package:opshub/features/chat/presentation/cubit/chat_list_cubit.dart';

// Deactivating an account must make its chat disappear: the inbox drops the
// conversation, the unread badge stops counting it, and (elsewhere) the thread
// refuses to open. These tests pin the two pure/logic seams behind that.

UserEntity _user(String uid, {bool isActive = true}) => UserEntity(
      uid: uid,
      email: '$uid@drop.test',
      displayName: uid,
      authProvider: 'password',
      branchId: 'b1',
      isActive: isActive,
    );

ChatConversationSummary _summary(
  String id, {
  required String counterpartExternalId,
  int unread = 0,
}) =>
    ChatConversationSummary(
      id: id,
      counterpartUserId: 'internal-$id',
      counterpartExternalId: counterpartExternalId,
      participantIds: ['me-internal', 'internal-$id'],
      createdAt: DateTime(2026, 8, 1),
      lastMessageAt: DateTime(2026, 8, 1, 12),
      unreadCount: unread,
    );

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this.everyone);
  final List<UserEntity> everyone;

  @override
  Future<List<UserEntity>> getAllUsers() async => everyone;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeChatRepository implements ChatRepository {
  _FakeChatRepository(this.items);
  final List<ChatConversationSummary> items;

  @override
  Future<List<ChatConversationSummary>> getCachedConversations() async =>
      const [];

  @override
  Future<ChatConversationPage> getConversations({int? limit, String? cursor}) =>
      Future.value(ChatConversationPage(items: items));

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

List<ChatConversationSummary> _visible(ChatListCubit cubit) =>
    cubit.state.maybeMap(
      loaded: (s) => s.conversations,
      orElse: () => throw StateError('not loaded'),
    );

void main() {
  group('GetChatDirectory.resolve', () {
    test('splits active teammates from deactivated uids in one pass', () async {
      final me = _user('me');
      final repo = _FakeAuthRepository([
        me,
        _user('alice'),
        _user('bob', isActive: false),
        _user('carol', isActive: false),
      ]);
      final snapshot = await GetChatDirectory(repo).resolve(me);

      expect(snapshot.active.map((u) => u.uid), ['alice']);
      // The caller is never their own deactivated counterpart, even if off.
      expect(snapshot.deactivatedUids, {'bob', 'carol'});
    });

    test('call() stays active-only (picker contract unchanged)', () async {
      final me = _user('me');
      final repo = _FakeAuthRepository([me, _user('alice'), _user('bob', isActive: false)]);
      final active = await GetChatDirectory(repo).call(me);
      expect(active.map((u) => u.uid), ['alice']);
    });
  });

  group('ChatListCubit hides deactivated counterparts', () {
    test('a deactivated counterpart is dropped from the inbox and unread total',
        () async {
      final deactivated = <String>{'bob-fb'};
      final cubit = ChatListCubit(
        getConversations: GetConversations(
          _FakeChatRepository([
            _summary('a', counterpartExternalId: 'alice-fb', unread: 2),
            _summary('b', counterpartExternalId: 'bob-fb', unread: 5),
          ]),
        ),
        startConversation: StartConversation(_FakeChatRepository(const [])),
        deactivatedCounterpartUids: () => deactivated,
      );

      await cubit.load();

      expect(_visible(cubit).map((c) => c.id), ['a']);
      // The hidden row's 5 unread must not reach the badge.
      expect(cubit.totalUnread, 2);
      await cubit.close();
    });

    test('reactivating a teammate restores the row on refilter, no re-fetch',
        () async {
      final deactivated = <String>{'bob-fb'};
      final cubit = ChatListCubit(
        getConversations: GetConversations(
          _FakeChatRepository([
            _summary('a', counterpartExternalId: 'alice-fb'),
            _summary('b', counterpartExternalId: 'bob-fb'),
          ]),
        ),
        startConversation: StartConversation(_FakeChatRepository(const [])),
        deactivatedCounterpartUids: () => deactivated,
      );

      await cubit.load();
      expect(_visible(cubit).map((c) => c.id), ['a']);

      // Admin turns Bob back on; the directory reload calls refilter().
      deactivated.clear();
      cubit.refilter();
      expect(_visible(cubit).map((c) => c.id), ['a', 'b']);
      await cubit.close();
    });

    test('no provider (or empty set) hides nothing', () async {
      final cubit = ChatListCubit(
        getConversations: GetConversations(
          _FakeChatRepository([
            _summary('a', counterpartExternalId: 'alice-fb'),
            _summary('b', counterpartExternalId: 'bob-fb'),
          ]),
        ),
        startConversation: StartConversation(_FakeChatRepository(const [])),
      );
      await cubit.load();
      expect(_visible(cubit).map((c) => c.id), ['a', 'b']);
      await cubit.close();
    });
  });
}
