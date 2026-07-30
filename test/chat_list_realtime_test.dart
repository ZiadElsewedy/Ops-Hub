import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/chat_message_type.dart';
import 'package:drop/features/chat/domain/chat_realtime.dart';
import 'package:drop/features/chat/domain/entities/chat_attachment_download.dart';
import 'package:drop/features/chat/domain/entities/chat_conversation.dart';
import 'package:drop/features/chat/domain/entities/chat_message.dart';
import 'package:drop/features/chat/domain/entities/chat_outgoing_attachment.dart';
import 'package:drop/features/chat/domain/entities/chat_read_receipt.dart';
import 'package:drop/features/chat/domain/repositories/chat_repository.dart';
import 'package:drop/features/chat/domain/usecases/get_conversations.dart';
import 'package:drop/features/chat/domain/usecases/start_conversation.dart';
import 'package:drop/features/chat/presentation/cubit/chat_list_cubit.dart';
import 'package:drop/features/chat/presentation/pages/chat_screen.dart';

ChatConversationSummary _summary(String id, {DateTime? lastMessageAt}) =>
    ChatConversationSummary(
      id: id,
      counterpartUserId: 'user-$id',
      participantIds: ['me', 'user-$id'],
      createdAt: DateTime(2026, 7, 20),
      lastMessageAt: lastMessageAt ?? DateTime(2026, 7, 22, 9),
    );

ChatConversationSummary _summaryUnread(String id, {required int unread}) =>
    ChatConversationSummary(
      id: id,
      counterpartUserId: 'user-$id',
      participantIds: ['me', 'user-$id'],
      createdAt: DateTime(2026, 7, 20),
      lastMessageAt: DateTime(2026, 7, 22, 9),
      unreadCount: unread,
    );

ChatMessage _live(String conversationId, String id, int seq, String body) =>
    ChatMessage(
      id: id,
      conversationId: conversationId,
      senderId: 'user-$conversationId',
      type: ChatMessageType.text,
      body: body,
      seq: BigInt.from(seq),
      status: 'SENT',
      createdAt: DateTime(2026, 7, 22, 10, seq % 60),
    );

class _FakeRealtime implements ChatRealtime {
  final controller = StreamController<ChatRealtimeEvent>.broadcast(sync: true);
  int inboxAttaches = 0;

  @override
  Stream<ChatRealtimeEvent> get events => controller.stream;

  @override
  Future<void> attachInbox() async => inboxAttaches++;

  @override
  Future<void> detachInbox() async {}

  @override
  Future<bool> joinConversation(String conversationId) async => true;

  @override
  Future<void> leaveConversation(String conversationId) async {}
}

class _FakeChatRepository implements ChatRepository {
  @override
  Future<List<ChatConversationSummary>> getCachedConversations() async =>
      const [];

  _FakeChatRepository({required this.onList});

  final Future<ChatConversationPage> Function({String? cursor}) onList;
  int listCalls = 0;

  @override
  Future<ChatConversationPage> getConversations(
      {int? limit, String? cursor}) {
    listCalls++;
    return onList(cursor: cursor);
  }

  @override
  Future<ChatConversation> startConversation(String targetUserId) =>
      throw UnimplementedError();

  @override
  Future<ChatConversation> getConversation(String conversationId) =>
      throw UnimplementedError();

  @override
  Future<ChatMessagePage> getMessageHistory(
          {required String conversationId, int? limit, String? cursor}) =>
      throw UnimplementedError();

  @override
  Future<ChatReadReceipt> markMessagesRead(
          {required String conversationId, required BigInt upToSeq}) =>
      throw UnimplementedError();

  @override
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String idempotencyKey,
    String? content,
    ChatOutgoingAttachment? attachment,
    String? replyToMessageId,
    void Function(int sent, int total)? onSendProgress,
  }) =>
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

ChatListCubit _cubit(_FakeChatRepository repo, _FakeRealtime rt) =>
    ChatListCubit(
      getConversations: GetConversations(repo),
      startConversation: StartConversation(repo),
      realtime: rt,
    );

typedef _Loaded = ({
  List<ChatConversationSummary> conversations,
  Map<String, String> previews,
  Map<String, int> unreadCounts,
});

_Loaded _loadedOf(ChatListCubit cubit) => cubit.state.maybeMap(
      loaded: (s) => (
        conversations: s.conversations,
        previews: s.previews,
        unreadCounts: s.unreadCounts,
      ),
      orElse: () => throw StateError('not loaded'),
    );

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('first load attaches inbox interest exactly once', () async {
    final rt = _FakeRealtime();
    final cubit = _cubit(
      _FakeChatRepository(
          onList: ({String? cursor}) async =>
              ChatConversationPage(items: [_summary('a')])),
      rt,
    );
    await cubit.load();
    await cubit.load(forceRefresh: true);
    expect(rt.inboxAttaches, 1);
    await cubit.close();
  });

  test(
      'a live message reorders the conversation to the top and updates '
      'preview, activity, and unread count', () async {
    final rt = _FakeRealtime();
    final cubit = _cubit(
      _FakeChatRepository(
          onList: ({String? cursor}) async =>
              ChatConversationPage(items: [_summary('a'), _summary('b')])),
      rt,
    );
    await cubit.load();

    rt.controller.add(ChatMessageReceived(_live('b', 'm1', 5, 'Fresh news')));

    final loaded = _loadedOf(cubit);
    expect(loaded.conversations.map((c) => c.id), ['b', 'a']);
    expect(loaded.conversations.first.lastMessageAt,
        DateTime(2026, 7, 22, 10, 5));
    expect(loaded.previews['b'], 'Fresh news');
    expect(loaded.unreadCounts['b'], 1);
    await cubit.close();
  });

  test('duplicate and out-of-order events are ignored (seq dedupe)', () async {
    final rt = _FakeRealtime();
    final cubit = _cubit(
      _FakeChatRepository(
          onList: ({String? cursor}) async =>
              ChatConversationPage(items: [_summary('a')])),
      rt,
    );
    await cubit.load();

    final m5 = _live('a', 'm5', 5, 'Five');
    rt.controller.add(ChatMessageReceived(m5));
    rt.controller.add(ChatMessageReceived(m5)); // exact replay
    rt.controller
        .add(ChatMessageReceived(_live('a', 'm3', 3, 'Old straggler')));

    final loaded = _loadedOf(cubit);
    expect(loaded.unreadCounts['a'], 1);
    expect(loaded.previews['a'], 'Five');
    await cubit.close();
  });

  test('a message for an unknown conversation triggers a full refresh',
      () async {
    final rt = _FakeRealtime();
    var items = [_summary('a')];
    final repo = _FakeChatRepository(
        onList: ({String? cursor}) async => ChatConversationPage(items: items));
    final cubit = _cubit(repo, rt);
    await cubit.load();
    expect(repo.listCalls, 1);

    items = [_summary('new-conv'), _summary('a')];
    rt.controller.add(ChatMessageReceived(_live('new-conv', 'm1', 1, 'Hi!')));
    await _settle();

    expect(repo.listCalls, 2);
    expect(_loadedOf(cubit).conversations.map((c) => c.id), ['new-conv', 'a']);
    await cubit.close();
  });

  test('a reconnect refreshes page one (reconciliation)', () async {
    final rt = _FakeRealtime();
    final repo = _FakeChatRepository(
        onList: ({String? cursor}) async =>
            ChatConversationPage(items: [_summary('a')]));
    final cubit = _cubit(repo, rt);
    await cubit.load();
    expect(repo.listCalls, 1);

    rt.controller.add(const ChatRealtimeConnected(isReconnect: false));
    await _settle();
    expect(repo.listCalls, 1); // first connect: initial load already truthful

    rt.controller.add(const ChatRealtimeConnected(isReconnect: true));
    await _settle();
    expect(repo.listCalls, 2);
    await cubit.close();
  });

  test('opening a conversation clears its unread badge', () async {
    final rt = _FakeRealtime();
    final cubit = _cubit(
      _FakeChatRepository(
          onList: ({String? cursor}) async =>
              ChatConversationPage(items: [_summary('a')])),
      rt,
    );
    await cubit.load();
    rt.controller.add(ChatMessageReceived(_live('a', 'm1', 1, 'Ping')));
    expect(_loadedOf(cubit).unreadCounts['a'], 1);

    cubit.clearUnread('a');
    expect(_loadedOf(cubit).unreadCounts.containsKey('a'), isFalse);
    await cubit.close();
  });

  test('an unacknowledged mark-read restores the badge it cleared', () async {
    // Regression: the badge was cleared optimistically on open and never
    // reconciled against the mark-read result, so a failed mark-read left the
    // inbox showing "read" for a thread the server still counted as unread —
    // until the next full refresh, which could be the rest of the session.
    final rt = _FakeRealtime();
    final cubit = _cubit(
      _FakeChatRepository(
          onList: ({String? cursor}) async =>
              ChatConversationPage(items: [_summary('a')])),
      rt,
    );
    await cubit.load();
    rt.controller.add(ChatMessageReceived(_live('a', 'm1', 1, 'Ping')));
    expect(_loadedOf(cubit).unreadCounts['a'], 1);

    cubit.clearUnread('a');
    expect(_loadedOf(cubit).unreadCounts.containsKey('a'), isFalse);

    // The thread's mark-read never landed.
    cubit.restoreUnread('a');
    expect(_loadedOf(cubit).unreadCounts['a'], 1);
    await cubit.close();
  });

  test('a confirmed mark-read leaves nothing to roll back', () async {
    final rt = _FakeRealtime();
    final cubit = _cubit(
      _FakeChatRepository(
          onList: ({String? cursor}) async =>
              ChatConversationPage(items: [_summary('a')])),
      rt,
    );
    await cubit.load();
    rt.controller.add(ChatMessageReceived(_live('a', 'm1', 1, 'Ping')));

    cubit.clearUnread('a');
    cubit.confirmUnreadCleared('a');
    // A late/duplicate rollback after the server agreed must not resurrect it.
    cubit.restoreUnread('a');
    expect(_loadedOf(cubit).unreadCounts.containsKey('a'), isFalse);
    await cubit.close();
  });

  test('a message arriving after an open outranks a pending rollback',
      () async {
    final rt = _FakeRealtime();
    final cubit = _cubit(
      _FakeChatRepository(
          onList: ({String? cursor}) async =>
              ChatConversationPage(items: [_summary('a')])),
      rt,
    );
    await cubit.load();
    rt.controller.add(ChatMessageReceived(_live('a', 'm1', 1, 'Ping')));
    cubit.clearUnread('a');

    // A new message lands while the mark-read is still in flight, then the
    // mark-read fails: the fresher count must win, not the stale rollback.
    rt.controller.add(ChatMessageReceived(_live('a', 'm2', 2, 'Again')));
    expect(_loadedOf(cubit).unreadCounts['a'], 1);
    cubit.restoreUnread('a');
    expect(_loadedOf(cubit).unreadCounts['a'], 1);
    await cubit.close();
  });

  test('reset() drops the rollback record too (no cross-account bleed)',
      () async {
    // reset() exists to drop all in-memory inbox state on account switch. A
    // surviving rollback record would let the previous account's in-flight
    // mark-read restore that account's unread count into the next session.
    final rt = _FakeRealtime();
    final cubit = _cubit(
      _FakeChatRepository(
          onList: ({String? cursor}) async =>
              ChatConversationPage(items: [_summary('a')])),
      rt,
    );
    await cubit.load();
    rt.controller.add(ChatMessageReceived(_live('a', 'm1', 1, 'Ping')));
    cubit.clearUnread('a');
    expect(_loadedOf(cubit).unreadCounts.containsKey('a'), isFalse);

    // Account switch: reset, then the next session loads its own inbox.
    cubit.reset();
    await cubit.load();
    expect(_loadedOf(cubit).unreadCounts.containsKey('a'), isFalse);

    // Only NOW does the previous account's in-flight mark-read fail. Its
    // rollback must not inject the old count into this session.
    cubit.restoreUnread('a');
    expect(_loadedOf(cubit).unreadCounts.containsKey('a'), isFalse);
    await cubit.close();
  });

  test('totalUnread sums per-conversation unread and drops on open', () async {
    final rt = _FakeRealtime();
    final cubit = _cubit(
      _FakeChatRepository(
          onList: ({String? cursor}) async =>
              ChatConversationPage(items: [_summary('a'), _summary('b')])),
      rt,
    );
    await cubit.load();
    expect(cubit.totalUnread, 0);

    rt.controller.add(ChatMessageReceived(_live('a', 'm1', 1, 'Hi')));
    rt.controller.add(ChatMessageReceived(_live('b', 'm2', 2, 'Yo')));
    rt.controller.add(ChatMessageReceived(_live('b', 'm3', 3, '!!')));
    expect(cubit.totalUnread, 3);

    cubit.clearUnread('b');
    expect(cubit.totalUnread, 1);
    await cubit.close();
  });

  test('a live message emits an incoming-notification event', () async {
    final rt = _FakeRealtime();
    final cubit = _cubit(
      _FakeChatRepository(
          onList: ({String? cursor}) async =>
              ChatConversationPage(items: [_summary('a')])),
      rt,
    );
    await cubit.load();

    final events = <ChatIncomingMessage>[];
    final sub = cubit.incoming.listen(events.add);
    rt.controller.add(ChatMessageReceived(_live('a', 'm1', 7, 'Ping me')));
    await _settle();

    expect(events, hasLength(1));
    expect(events.single.conversationId, 'a');
    expect(events.single.preview, 'Ping me');
    await sub.cancel();
    await cubit.close();
  });

  test('a live delete-for-everyone tombstones the previewed line', () async {
    final rt = _FakeRealtime();
    final cubit = _cubit(
      _FakeChatRepository(
          onList: ({String? cursor}) async =>
              ChatConversationPage(items: [_summary('a')])),
      rt,
    );
    await cubit.load();
    rt.controller.add(ChatMessageReceived(_live('a', 'm1', 1, 'Oops')));
    expect(_loadedOf(cubit).previews['a'], 'Oops');

    rt.controller.add(ChatMessageDeletedReceived(
      conversationId: 'a',
      messageId: 'm1',
      deletedBy: 'user-a',
      deletedAt: DateTime(2026, 7, 22, 11),
    ));
    expect(_loadedOf(cubit).previews['a'], chatDeletedForEveryonePlaceholder);

    // A delete of some OLDER (non-previewed) message changes nothing.
    rt.controller.add(ChatMessageDeletedReceived(
      conversationId: 'a',
      messageId: 'other-message',
      deletedBy: 'user-a',
      deletedAt: DateTime(2026, 7, 22, 11),
    ));
    expect(_loadedOf(cubit).previews['a'], chatDeletedForEveryonePlaceholder);
    await cubit.close();
  });

  testWidgets('the inbox renders the live preview and unread badge',
      (tester) async {
    final rt = _FakeRealtime();
    final cubit = _cubit(
      _FakeChatRepository(
          onList: ({String? cursor}) async =>
              ChatConversationPage(items: [_summary('a'), _summary('b')])),
      rt,
    );
    addTearDown(() => rt.controller.close());
    addTearDown(cubit.close);
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider.value(value: cubit, child: const ChatScreen()),
    ));
    await tester.pump(); // post-frame load
    await tester.pump(); // resolve the page future
    expect(_loadedOf(cubit).conversations.length, 2,
        reason: 'inbox should be loaded before events fire');

    rt.controller.add(ChatMessageReceived(_live('b', 'm1', 1, 'See you at 5')));
    rt.controller.add(ChatMessageReceived(_live('b', 'm2', 2, 'Bring keys')));
    expect(_loadedOf(cubit).previews['b'], 'Bring keys',
        reason: 'cubit should hold the live preview');
    // Two pumps: the cubit's async stream delivers the new state during the
    // first (after its frame was already built); the second renders it.
    await tester.pump();
    await tester.pump();

    expect(find.text('Bring keys'), findsOneWidget); // live preview
    expect(find.text('2'), findsOneWidget); // unread badge
  });

  test(
      'unread badge is seeded from the server-computed unreadCount on load '
      '(survives a cold start)', () async {
    final rt = _FakeRealtime();
    final cubit = _cubit(
      _FakeChatRepository(
        onList: ({String? cursor}) async => ChatConversationPage(items: [
          _summaryUnread('a', unread: 4),
          _summaryUnread('b', unread: 0),
        ]),
      ),
      rt,
    );

    await cubit.load();

    final loaded = _loadedOf(cubit);
    expect(loaded.unreadCounts['a'], 4);
    expect(loaded.unreadCounts.containsKey('b'), isFalse);
    expect(cubit.totalUnread, 4);
    await cubit.close();
  });

  test('reset() drops all in-memory inbox state for account switching',
      () async {
    final rt = _FakeRealtime();
    final cubit = _cubit(
      _FakeChatRepository(
        onList: ({String? cursor}) async =>
            ChatConversationPage(items: [_summaryUnread('a', unread: 2)]),
      ),
      rt,
    );

    await cubit.load();
    expect(cubit.totalUnread, 2);
    expect(_loadedOf(cubit).conversations, isNotEmpty);

    cubit.reset();

    expect(cubit.totalUnread, 0);
    expect(
      cubit.state.maybeMap(initial: (_) => true, orElse: () => false),
      isTrue,
      reason: 'reset returns the cubit to first-run',
    );
    await cubit.close();
  });
}
