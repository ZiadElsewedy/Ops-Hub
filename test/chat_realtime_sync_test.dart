import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/chat_message_type.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/features/chat/data/realtime/chat_realtime_payloads.dart';
import 'package:drop/features/chat/domain/chat_realtime.dart';
import 'package:drop/features/chat/domain/entities/chat_attachment_download.dart';
import 'package:drop/features/chat/domain/entities/chat_conversation.dart';
import 'package:drop/features/chat/domain/entities/chat_message.dart';
import 'package:drop/features/chat/domain/entities/chat_outgoing_attachment.dart';
import 'package:drop/features/chat/domain/entities/chat_read_receipt.dart';
import 'package:drop/features/chat/domain/repositories/chat_repository.dart';
import 'package:drop/features/chat/domain/usecases/delete_chat_message_for_everyone.dart';
import 'package:drop/features/chat/domain/usecases/delete_chat_message_for_me.dart';
import 'package:drop/features/chat/domain/usecases/get_conversation.dart';
import 'package:drop/features/chat/domain/usecases/load_chat_history.dart';
import 'package:drop/features/chat/domain/usecases/mark_chat_read.dart';
import 'package:drop/features/chat/domain/usecases/send_chat_message.dart';
import 'package:drop/features/chat/presentation/cubit/chat_conversation_cubit.dart';

const _me = 'me-uuid';
const _them = 'them-uuid';
const _convId = 'conv-1';

ChatMessage _message(String id, int seq, String sender, String body) =>
    ChatMessage(
      id: id,
      conversationId: _convId,
      senderId: sender,
      type: ChatMessageType.text,
      body: body,
      seq: BigInt.from(seq),
      status: 'SENT',
      createdAt: DateTime(2026, 7, 22, 9, seq % 60),
    );

/// Scripted fake for the realtime port: records joins/leaves and lets the
/// test push events into the cubit.
class _FakeRealtime implements ChatRealtime {
  final controller = StreamController<ChatRealtimeEvent>.broadcast(sync: true);
  final joined = <String>[];
  final left = <String>[];

  @override
  Stream<ChatRealtimeEvent> get events => controller.stream;

  @override
  Future<bool> joinConversation(String conversationId) async {
    joined.add(conversationId);
    return true;
  }

  @override
  Future<void> leaveConversation(String conversationId) async {
    left.add(conversationId);
  }

  @override
  Future<void> attachInbox() async {}

  @override
  Future<void> detachInbox() async {}
}

class _FakeChatRepository implements ChatRepository {
  @override
  Future<List<ChatConversationSummary>> getCachedConversations() async =>
      const [];

  _FakeChatRepository({required this.onHistory, this.onSend});

  final Future<ChatMessagePage> Function({String? cursor}) onHistory;

  /// Controllable send: keyed by `content` so a test can resolve concurrent
  /// sends out of order and with chosen server `seq`s.
  final Future<ChatMessage> Function(String content)? onSend;

  @override
  Future<ChatConversation> getConversation(String conversationId) async =>
      ChatConversation(
        id: _convId,
        participantIds: const [_me, _them],
        createdAt: DateTime(2026, 7, 20),
      );

  @override
  Future<ChatMessagePage> getMessageHistory({
    required String conversationId,
    int? limit,
    String? cursor,
  }) =>
      onHistory(cursor: cursor);

  @override
  Future<ChatReadReceipt> markMessagesRead({
    required String conversationId,
    required BigInt upToSeq,
  }) async =>
      ChatReadReceipt(
          conversationId: conversationId,
          markedCount: 0,
          readAt: DateTime(2026, 7, 22));

  @override
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String idempotencyKey,
    String? content,
    ChatOutgoingAttachment? attachment,
    String? replyToMessageId,
    void Function(int sent, int total)? onSendProgress,
  }) {
    final handler = onSend;
    if (handler == null) throw UnimplementedError();
    return handler(content ?? '');
  }

  @override
  Future<ChatConversation> startConversation(String targetUserId) =>
      throw UnimplementedError();

  @override
  Future<ChatConversationPage> getConversations(
          {int? limit, String? cursor}) =>
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

ChatConversationCubit _cubit(_FakeChatRepository repo, _FakeRealtime rt) =>
    ChatConversationCubit(
      getConversation: GetConversation(repo),
      loadHistory: LoadChatHistory(repo),
      sendMessage: SendChatMessage(repo),
      markRead: MarkChatRead(repo),
      deleteForMe: DeleteChatMessageForMe(repo),
      deleteForEveryone: DeleteChatMessageForEveryone(repo),
      conversationId: _convId,
      counterpartUserId: _them,
      realtime: rt,
    );

List<ChatMessage> _messagesOf(ChatConversationCubit cubit) =>
    cubit.state.maybeMap(
        loaded: (s) => s.messages, orElse: () => throw StateError('not loaded'));

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('joins its conversation on creation and leaves on close', () async {
    final rt = _FakeRealtime();
    final cubit = _cubit(
      _FakeChatRepository(
          onHistory: ({String? cursor}) async =>
              const ChatMessagePage(items: [])),
      rt,
    );
    await _settle();
    expect(rt.joined, [_convId]);
    await cubit.close();
    expect(rt.left, [_convId]);
  });

  test('a live message:new for this thread is appended once', () async {
    final rt = _FakeRealtime();
    final cubit = _cubit(
      _FakeChatRepository(
          onHistory: ({String? cursor}) async =>
              ChatMessagePage(items: [_message('m1', 1, _them, 'Hi')])),
      rt,
    );
    await _settle();

    final live = _message('m2', 2, _them, 'Still there?');
    rt.controller.add(ChatMessageReceived(live));
    rt.controller.add(ChatMessageReceived(live)); // duplicate delivery
    expect(_messagesOf(cubit).map((m) => m.id), ['m1', 'm2']);

    // A different conversation's message is ignored.
    rt.controller.add(ChatMessageReceived(ChatMessage(
      id: 'other',
      conversationId: 'conv-9',
      senderId: _them,
      type: ChatMessageType.text,
      body: 'wrong thread',
      seq: BigInt.from(9),
      status: 'SENT',
      createdAt: DateTime(2026, 7, 22),
    )));
    expect(_messagesOf(cubit).length, 2);
    await cubit.close();
  });

  test('an out-of-order delivery is inserted at its seq position', () async {
    final rt = _FakeRealtime();
    final cubit = _cubit(
      _FakeChatRepository(
          onHistory: ({String? cursor}) async => ChatMessagePage(items: [
                _message('m1', 1, _them, 'One'),
                _message('m3', 3, _them, 'Three'),
              ])),
      rt,
    );
    await _settle();

    rt.controller.add(ChatMessageReceived(_message('m2', 2, _them, 'Two')));
    expect(_messagesOf(cubit).map((m) => m.body), ['One', 'Two', 'Three']);
    await cubit.close();
  });

  test('message:read upgrades the listed messages to READ', () async {
    final rt = _FakeRealtime();
    final cubit = _cubit(
      _FakeChatRepository(
          onHistory: ({String? cursor}) async => ChatMessagePage(items: [
                _message('m1', 1, _me, 'Mine'),
                _message('m2', 2, _me, 'Mine too'),
                _message('m3', 3, _them, 'Theirs'),
              ])),
      rt,
    );
    await _settle();

    rt.controller.add(ChatMessagesReadReceived(
      conversationId: _convId,
      readerId: _them,
      messageIds: const ['m1', 'm2', 'missing-id'],
      readAt: DateTime(2026, 7, 22, 10),
    ));

    final byId = {for (final m in _messagesOf(cubit)) m.id: m.status};
    expect(byId, {'m1': 'READ', 'm2': 'READ', 'm3': 'SENT'});
    await cubit.close();
  });

  test('a reconnect reconciles missed messages via REST', () async {
    final rt = _FakeRealtime();
    var page = ChatMessagePage(items: [_message('m1', 1, _them, 'Hi')]);
    final cubit = _cubit(
      _FakeChatRepository(onHistory: ({String? cursor}) async => page),
      rt,
    );
    await _settle();
    expect(_messagesOf(cubit).length, 1);

    // While disconnected the counterpart sent two messages; the newest page
    // now holds all three.
    page = ChatMessagePage(items: [
      _message('m1', 1, _them, 'Hi'),
      _message('m2', 2, _them, 'You there?'),
      _message('m3', 3, _them, 'Ping'),
    ]);
    rt.controller.add(const ChatRealtimeDisconnected());
    rt.controller.add(const ChatRealtimeConnected(isReconnect: true));
    await _settle();

    expect(_messagesOf(cubit).map((m) => m.id), ['m1', 'm2', 'm3']);
    await cubit.close();
  });

  test('the first connection does not trigger a redundant reconcile',
      () async {
    final rt = _FakeRealtime();
    var historyCalls = 0;
    final cubit = _cubit(
      _FakeChatRepository(onHistory: ({String? cursor}) async {
        historyCalls++;
        return const ChatMessagePage(items: []);
      }),
      rt,
    );
    await _settle();
    rt.controller.add(const ChatRealtimeConnected(isReconnect: false));
    await _settle();
    expect(historyCalls, 1); // only the initial load
    await cubit.close();
  });

  test('a live message:deleted tombstones the message in place', () async {
    final rt = _FakeRealtime();
    final cubit = _cubit(
      _FakeChatRepository(
          onHistory: ({String? cursor}) async =>
              ChatMessagePage(items: [_message('m1', 1, _me, 'Regret this')])),
      rt,
    );
    await _settle();

    rt.controller.add(ChatMessageDeletedReceived(
      conversationId: _convId,
      messageId: 'm1',
      deletedBy: _me,
      deletedAt: DateTime(2026, 7, 22, 10),
    ));

    final message = _messagesOf(cubit).single;
    expect(message.deletedForEveryone, isTrue);
    expect(message.body, chatDeletedForEveryonePlaceholder);
    expect(message.seq, BigInt.one); // record preserved, only display changed
    await cubit.close();
  });

  test('a live message:deleted-for-me removes the message from this session',
      () async {
    final rt = _FakeRealtime();
    final cubit = _cubit(
      _FakeChatRepository(
          onHistory: ({String? cursor}) async => ChatMessagePage(items: [
                _message('m1', 1, _them, 'Keep'),
                _message('m2', 2, _them, 'Hide'),
              ])),
      rt,
    );
    await _settle();

    rt.controller.add(ChatMessageHiddenReceived(
      conversationId: _convId,
      messageId: 'm2',
      deletedAt: DateTime(2026, 7, 22, 10),
    ));

    expect(_messagesOf(cubit).map((m) => m.id), ['m1']);
    await cubit.close();
  });

  group('payload parsing (wire shapes from chat-events.ts)', () {
    test('message:new parses through the shared message model', () {
      final event = parseMessageNew({
        'id': 'm1',
        'conversationId': _convId,
        'senderId': _them,
        'type': 'TEXT',
        'body': 'hello',
        'attachment': null,
        'replyTo': null,
        'seq': '42',
        'status': 'SENT',
        'createdAt': '2026-07-22T09:00:00.000Z',
        'deletedForEveryone': false,
      });
      expect(event.message.id, 'm1');
      expect(event.message.seq, BigInt.from(42));
      expect(event.message.body, 'hello');
    });

    test('message:read parses ids and timestamp', () {
      final event = parseMessageRead({
        'conversationId': _convId,
        'readerId': _them,
        'messageIds': ['a', 'b'],
        'readAt': '2026-07-22T10:30:00.000Z',
      });
      expect(event.conversationId, _convId);
      expect(event.readerId, _them);
      expect(event.messageIds, ['a', 'b']);
      expect(event.readAt, DateTime.utc(2026, 7, 22, 10, 30));
    });

    test('message:deleted and message:deleted-for-me parse', () {
      final deleted = parseMessageDeleted({
        'conversationId': _convId,
        'messageId': 'm1',
        'deletedBy': _them,
        'deletedAt': '2026-07-22T11:00:00.000Z',
      });
      expect(deleted.messageId, 'm1');
      expect(deleted.deletedBy, _them);

      final hidden = parseMessageDeletedForMe({
        'conversationId': _convId,
        'messageId': 'm2',
        'deletedAt': '2026-07-22T11:05:00.000Z',
      });
      expect(hidden.messageId, 'm2');
    });
  });

  // Ordering must follow the authoritative server `seq`, never the optimistic
  // placeholder's slot. Each case is built to invert send order vs. seq order,
  // so it would fail if a confirmed message were dropped into its placeholder's
  // position instead of re-inserted by `seq`.
  group('confirmed messages render in authoritative seq order', () {
    List<int> seqs(ChatConversationCubit c) =>
        _messagesOf(c).map((m) => m.seq.toInt()).toList();
    List<String?> bodies(ChatConversationCubit c) =>
        _messagesOf(c).map((m) => m.body).toList();

    test('two rapid concurrent sends whose server seqs invert the send order',
        () async {
      final completers = <String, Completer<ChatMessage>>{};
      final cubit = _cubit(
        _FakeChatRepository(
          onHistory: ({String? cursor}) async =>
              ChatMessagePage(items: [_message('m0', 10, _them, 'seed')]),
          onSend: (content) =>
              (completers[content] = Completer<ChatMessage>()).future,
        ),
        _FakeRealtime(),
      );
      await _settle();

      // Both optimistic sends are in flight (the POSTs are unawaited).
      await cubit.sendMessage('A'); // local placeholder seq 11
      await cubit.sendMessage('B'); // local placeholder seq 12
      expect(bodies(cubit), ['seed', 'A', 'B']);

      // The server assigned B the LOWER seq (it arrived first) and A the higher,
      // and B's response returns first — the exact case in-place replace broke.
      completers['B']!.complete(_message('mB', 11, _me, 'B'));
      await _settle();
      completers['A']!.complete(_message('mA', 12, _me, 'A'));
      await _settle();

      expect(bodies(cubit), ['seed', 'B', 'A']);
      expect(seqs(cubit), [10, 11, 12]);
      await cubit.close();
    });

    test('a pending send interleaved with a lower-seq realtime message',
        () async {
      final sent = Completer<ChatMessage>();
      final rt = _FakeRealtime();
      final cubit = _cubit(
        _FakeChatRepository(
          onHistory: ({String? cursor}) async =>
              ChatMessagePage(items: [_message('m0', 10, _them, 'seed')]),
          onSend: (_) => sent.future,
        ),
        rt,
      );
      await _settle();

      await cubit.sendMessage('mine'); // local placeholder seq 11
      // The counterpart's message lands live first with the real seq 11; the
      // server will assign my message the next seq (12).
      rt.controller.add(ChatMessageReceived(_message('mc', 11, _them, 'theirs')));
      await _settle();

      sent.complete(_message('mm', 12, _me, 'mine'));
      await _settle();

      expect(bodies(cubit), ['seed', 'theirs', 'mine']);
      expect(seqs(cubit), [10, 11, 12]);
      await cubit.close();
    });

    test('a failed send retried after a newer message keeps seq order',
        () async {
      final attempts = <Completer<ChatMessage>>[];
      final rt = _FakeRealtime();
      final cubit = _cubit(
        _FakeChatRepository(
          onHistory: ({String? cursor}) async =>
              ChatMessagePage(items: [_message('m0', 10, _them, 'seed')]),
          onSend: (_) => (attempts..add(Completer<ChatMessage>())).last.future,
        ),
        rt,
      );
      await _settle();

      await cubit.sendMessage('mine'); // local placeholder seq 11 (attempt 0)
      attempts[0].completeError(const ServerFailure('offline'));
      await _settle();
      // A newer counterpart message arrives while mine sits failed.
      rt.controller.add(ChatMessageReceived(_message('mc', 11, _them, 'theirs')));
      await _settle();

      final failedId =
          _messagesOf(cubit).firstWhere((m) => m.status == 'FAILED').id;
      await cubit.retrySend(failedId); // attempt 1, reuses the idempotency key
      attempts[1].complete(_message('mm', 12, _me, 'mine'));
      await _settle();

      expect(bodies(cubit), ['seed', 'theirs', 'mine']);
      expect(seqs(cubit), [10, 11, 12]);
      await cubit.close();
    });
  });
}
