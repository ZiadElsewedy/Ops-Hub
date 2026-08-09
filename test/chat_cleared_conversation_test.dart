import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/services/chat_cleared_store.dart';
import 'package:drop/features/chat/domain/entities/chat_conversation.dart';
import 'package:drop/features/chat/domain/repositories/chat_repository.dart';
import 'package:drop/features/chat/domain/usecases/get_conversations.dart';
import 'package:drop/features/chat/domain/usecases/start_conversation.dart';
import 'package:drop/features/chat/presentation/cubit/chat_list_cubit.dart';

// Clearing or deleting a conversation for me must actually stick: the inbox row
// disappears and stays gone across a refresh (the list endpoint keeps reporting
// the old last message), until a genuinely newer message arrives. These pin the
// pure watermark rule and the ChatListCubit filtering behind that.

ChatConversationSummary _summary(
  String id, {
  DateTime? lastMessageAt,
  int unread = 0,
}) =>
    ChatConversationSummary(
      id: id,
      counterpartUserId: 'internal-$id',
      counterpartExternalId: '$id-fb',
      participantIds: ['me-internal', 'internal-$id'],
      createdAt: DateTime(2026, 8, 1),
      lastMessageAt: lastMessageAt ?? DateTime(2026, 8, 1, 12),
      unreadCount: unread,
    );

class _FakeChatRepository implements ChatRepository {
  _FakeChatRepository(this.items);
  List<ChatConversationSummary> items;

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

/// A tiny in-memory stand-in for [ChatClearedStore]'s live view — the cubit
/// only reads the watermark accessor and writes through the mark callback.
class _MemoryCleared {
  final Map<String, int> _through = {};
  int? through(String id) => _through[id];
  void mark(String id, DateTime? at) {
    final ts = (at ?? DateTime.now()).millisecondsSinceEpoch;
    final cur = _through[id];
    if (cur == null || ts > cur) _through[id] = ts;
  }
}

ChatListCubit _cubit(_FakeChatRepository repo, _MemoryCleared cleared) =>
    ChatListCubit(
      getConversations: GetConversations(repo),
      startConversation: StartConversation(_FakeChatRepository(const [])),
      clearedThroughMillis: cleared.through,
      onConversationCleared: cleared.mark,
    );

void main() {
  group('chatConversationCleared (pure rule)', () {
    final at = DateTime(2026, 8, 1, 12);

    test('no watermark → never cleared', () {
      expect(chatConversationCleared(at, null), isFalse);
    });

    test('activity at or before the watermark → still cleared', () {
      expect(chatConversationCleared(at, at.millisecondsSinceEpoch), isTrue);
      expect(
        chatConversationCleared(
            at.subtract(const Duration(hours: 1)), at.millisecondsSinceEpoch),
        isTrue,
      );
    });

    test('a strictly-newer message → no longer cleared', () {
      expect(
        chatConversationCleared(
            at.add(const Duration(minutes: 1)), at.millisecondsSinceEpoch),
        isFalse,
      );
    });

    test('no activity but a watermark exists → cleared', () {
      expect(chatConversationCleared(null, at.millisecondsSinceEpoch), isTrue);
    });
  });

  group('ChatListCubit hides cleared conversations', () {
    test('marking a conversation cleared drops it from the inbox + unread total',
        () async {
      final cleared = _MemoryCleared();
      final repo = _FakeChatRepository([
        _summary('a', unread: 2),
        _summary('b', unread: 5, lastMessageAt: DateTime(2026, 8, 2, 9)),
      ]);
      final cubit = _cubit(repo, cleared);
      await cubit.load();
      expect(_visible(cubit).map((c) => c.id), ['a', 'b']);
      expect(cubit.totalUnread, 7);

      cubit.markConversationCleared('b', DateTime(2026, 8, 2, 9));

      expect(_visible(cubit).map((c) => c.id), ['a']);
      // The cleared row's 5 unread must not reach the badge.
      expect(cubit.totalUnread, 2);
      await cubit.close();
    });

    test('a cleared conversation stays hidden across a refresh', () async {
      final cleared = _MemoryCleared();
      final repo = _FakeChatRepository([
        _summary('a'),
        _summary('b', lastMessageAt: DateTime(2026, 8, 2, 9)),
      ]);
      final cubit = _cubit(repo, cleared);
      await cubit.load();

      cubit.markConversationCleared('b', DateTime(2026, 8, 2, 9));
      expect(_visible(cubit).map((c) => c.id), ['a']);

      // The server list still reports b with its old last activity — the
      // persistent watermark keeps it hidden.
      await cubit.refresh();
      expect(_visible(cubit).map((c) => c.id), ['a']);
      await cubit.close();
    });

    test('a newer message brings a cleared conversation back', () async {
      final cleared = _MemoryCleared();
      final repo = _FakeChatRepository([
        _summary('a'),
        _summary('b', lastMessageAt: DateTime(2026, 8, 2, 9)),
      ]);
      final cubit = _cubit(repo, cleared);
      await cubit.load();

      cubit.markConversationCleared('b', DateTime(2026, 8, 2, 9));
      expect(_visible(cubit).map((c) => c.id), ['a']);

      // A genuinely newer message on b lands (server refresh reflects it).
      repo.items = [
        _summary('a'),
        _summary('b', lastMessageAt: DateTime(2026, 8, 2, 10), unread: 1),
      ];
      await cubit.refresh();
      expect(_visible(cubit).map((c) => c.id), ['a', 'b']);
      expect(cubit.totalUnread, 1);
      await cubit.close();
    });
  });
}
