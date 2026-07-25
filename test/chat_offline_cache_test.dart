import 'package:drop/core/enums/chat_attachment_kind.dart';
import 'package:drop/core/enums/chat_message_type.dart';
import 'package:drop/core/errors/exceptions.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:drop/features/chat/data/local/chat_database.dart';
import 'package:drop/features/chat/data/local/chat_local_datasource.dart';
import 'package:drop/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:drop/features/chat/domain/entities/chat_conversation.dart';
import 'package:drop/features/chat/domain/entities/chat_message.dart';
import 'package:drop/features/chat/domain/entities/chat_outgoing_attachment.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies the Drift offline cache: the [ChatLocalDataSource] on its own, and
/// the [ChatRepositoryImpl] read-through / write-through / offline-fallback
/// orchestration over a real in-memory database.

const _conv = 'conv-1';
const _me = 'me';
const _them = 'them';

ChatMessage _msg(
  int seq, {
  String? id,
  String? body = 'hi',
  String status = 'SENT',
  bool deleted = false,
  ChatMessageAttachment? attachment,
  ChatReplyPreview? reply,
}) =>
    ChatMessage(
      id: id ?? 'm$seq',
      conversationId: _conv,
      senderId: _them,
      type: attachment == null ? ChatMessageType.text : ChatMessageType.image,
      body: body,
      attachment: attachment,
      replyTo: reply,
      seq: BigInt.from(seq),
      status: status,
      createdAt: DateTime.utc(2026, 7, 24, 12, seq),
      deletedForEveryone: deleted,
    );

ChatConversationSummary _summary({DateTime? lastAt}) => ChatConversationSummary(
      id: _conv,
      counterpartUserId: _them,
      counterpartExternalId: 'firebase-them',
      participantIds: const [_me, _them],
      createdAt: DateTime.utc(2026, 7, 24),
      lastMessageAt: lastAt,
    );

void main() {
  late ChatDatabase db;
  late ChatLocalDataSourceImpl local;

  setUp(() {
    db = ChatDatabase.memory();
    local = ChatLocalDataSourceImpl(db);
  });

  tearDown(() => db.close());

  group('ChatLocalDataSource', () {
    test('conversation round-trips including the external id', () async {
      await local.upsertConversations([_summary(lastAt: DateTime.utc(2026, 7, 24, 13))]);
      final list = await local.readConversations();
      expect(list, hasLength(1));
      expect(list.first.id, _conv);
      expect(list.first.counterpartUserId, _them);
      expect(list.first.counterpartExternalId, 'firebase-them');
    });

    test('messages read newest-first-window, oldest→newest within page',
        () async {
      await local.upsertMessages(_conv, [for (var i = 1; i <= 5; i++) _msg(i)]);
      final newest = await local.readNewestMessages(_conv, limit: 3);
      expect(newest.map((m) => m.seq.toInt()), [3, 4, 5]);
    });

    test('reply + attachment metadata survive a round-trip (no bytes)',
        () async {
      final attachment = const ChatMessageAttachment(
        id: 'att-1',
        kind: ChatAttachmentKind.image,
        format: 'JPG',
        mimeType: 'image/jpeg',
        originalFilename: 'photo.jpg',
        byteSize: 2048,
      );
      final reply = const ChatReplyPreview(
        id: 'm1',
        senderId: _me,
        type: ChatMessageType.text,
        body: 'the parent',
      );
      await local.upsertMessages(_conv, [
        _msg(2, id: 'm2', body: null, attachment: attachment, reply: reply),
      ]);
      final read = (await local.readNewestMessages(_conv)).single;
      expect(read.attachment!.id, 'att-1');
      expect(read.attachment!.originalFilename, 'photo.jpg');
      expect(read.attachment!.byteSize, 2048);
      expect(read.replyTo!.id, 'm1');
      expect(read.replyTo!.body, 'the parent');
    });

    test('upsert is conflict-safe: same id replaces (tombstone wins)',
        () async {
      await local.upsertMessages(_conv, [_msg(3, id: 'm3', body: 'original')]);
      await local.upsertMessages(_conv, [
        _msg(3, id: 'm3', body: 'This message was deleted', deleted: true),
      ]);
      final read = (await local.readNewestMessages(_conv)).single;
      expect(read.id, 'm3');
      expect(read.deletedForEveryone, isTrue);
      expect(read.body, 'This message was deleted');
    });

    test('older-page reads only messages below a seq', () async {
      await local.upsertMessages(_conv, [for (var i = 1; i <= 6; i++) _msg(i)]);
      final older = await local.readMessagesBefore(_conv, BigInt.from(4));
      expect(older.map((m) => m.seq.toInt()), [1, 2, 3]);
      expect(await local.oldestCachedSeq(_conv), BigInt.from(1));
    });

    test('deleteMessage removes one row (delete-for-me)', () async {
      await local.upsertMessages(_conv, [_msg(1), _msg(2)]);
      await local.deleteMessage('m1');
      final read = await local.readNewestMessages(_conv);
      expect(read.map((m) => m.id), ['m2']);
    });

    test('outbox enqueue / read / dequeue', () async {
      await local.enqueuePending(const PendingChatSend(
        idempotencyKey: 'key-1',
        conversationId: _conv,
        content: 'queued',
      ));
      var pending = await local.readPending(_conv);
      expect(pending.single.content, 'queued');
      await local.dequeuePending('key-1');
      pending = await local.readPending(_conv);
      expect(pending, isEmpty);
    });

    test('clearAll wipes every table', () async {
      await local.upsertConversations([_summary()]);
      await local.upsertMessages(_conv, [_msg(1)]);
      await local.enqueuePending(const PendingChatSend(
        idempotencyKey: 'k',
        conversationId: _conv,
      ));
      await local.clearAll();
      expect(await local.readConversations(), isEmpty);
      expect(await local.readNewestMessages(_conv), isEmpty);
      expect(await local.readPending(_conv), isEmpty);
    });
  });

  group('ChatRepositoryImpl with cache', () {
    test('write-through: a successful history read is cached', () async {
      final remote = _FakeRemote()
        ..history = ChatMessagePage(items: [_msg(1), _msg(2)]);
      final repo = ChatRepositoryImpl(remote, local);

      await repo.getMessageHistory(conversationId: _conv);
      // The cache now holds what the server returned.
      expect((await local.readNewestMessages(_conv)).map((m) => m.id),
          ['m1', 'm2']);
    });

    test('offline fallback: newest history served from cache on failure',
        () async {
      await local.upsertMessages(_conv, [_msg(1), _msg(2), _msg(3)]);
      final remote = _FakeRemote()..failHistory = true;
      final repo = ChatRepositoryImpl(remote, local);

      final page = await repo.getMessageHistory(conversationId: _conv);
      expect(page.items.map((m) => m.id), ['m1', 'm2', 'm3']);
    });

    test('offline with an empty cache still surfaces the failure', () async {
      final remote = _FakeRemote()..failHistory = true;
      final repo = ChatRepositoryImpl(remote, local);
      expect(
        () => repo.getMessageHistory(conversationId: _conv),
        throwsA(isA<ServerFailure>()),
      );
    });

    test('cache-first back-pagination via a local: cursor never hits the network',
        () async {
      await local.upsertMessages(_conv, [for (var i = 1; i <= 5; i++) _msg(i)]);
      final remote = _FakeRemote()..failHistory = true;
      final repo = ChatRepositoryImpl(remote, local);

      // First (offline) page: served from cache, newest window.
      final first = await repo.getMessageHistory(conversationId: _conv);
      expect(first.items.map((m) => m.seq.toInt()), [1, 2, 3, 4, 5]);

      // A synthetic local cursor pages strictly below seq 3 from the cache.
      final older = await repo.getMessageHistory(
        conversationId: _conv,
        cursor: 'local:3',
      );
      expect(older.items.map((m) => m.seq.toInt()), [1, 2]);
      expect(remote.historyCalls, 1); // only the first page touched the network
    });

    test('offline conversation list falls back to the cached list', () async {
      await local.upsertConversations([_summary(lastAt: DateTime.utc(2026, 7))]);
      final remote = _FakeRemote()..failConversations = true;
      final repo = ChatRepositoryImpl(remote, local);

      final page = await repo.getConversations();
      expect(page.items.single.id, _conv);
      expect(page.nextCursor, isNull);
    });

    test('sendMessage drains the outbox on success; text send is enqueued first',
        () async {
      final remote = _FakeRemote()..sent = _msg(9, id: 'server-9', body: 'text');
      final repo = ChatRepositoryImpl(remote, local);

      await repo.sendMessage(
        conversationId: _conv,
        idempotencyKey: 'key-9',
        content: 'text',
      );
      // Confirmed message cached, outbox drained.
      expect((await local.readNewestMessages(_conv)).map((m) => m.id),
          contains('server-9'));
      expect(await local.readPending(_conv), isEmpty);
    });

    test('a failed text send leaves the outbox entry for retry', () async {
      final remote = _FakeRemote()..failSend = true;
      final repo = ChatRepositoryImpl(remote, local);

      await expectLater(
        repo.sendMessage(
          conversationId: _conv,
          idempotencyKey: 'key-x',
          content: 'unsent',
        ),
        throwsA(isA<ServerFailure>()),
      );
      final pending = await local.readPending(_conv);
      expect(pending.single.idempotencyKey, 'key-x');
      expect(pending.single.content, 'unsent');
    });
  });
}

class _FakeRemote implements ChatRemoteDataSource {
  ChatMessagePage history = const ChatMessagePage(items: []);
  ChatConversationPage conversations = const ChatConversationPage(items: []);
  ChatMessage? sent;
  bool failHistory = false;
  bool failConversations = false;
  bool failSend = false;
  int historyCalls = 0;

  @override
  Future<ChatMessagePage> loadHistory({
    required String conversationId,
    int? limit,
    String? cursor,
  }) async {
    historyCalls++;
    if (failHistory) throw const ServerException('offline');
    return history;
  }

  @override
  Future<ChatConversationPage> listConversations({
    int? limit,
    String? cursor,
  }) async {
    if (failConversations) throw const ServerException('offline');
    return conversations;
  }

  @override
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String idempotencyKey,
    String? content,
    ChatOutgoingAttachment? attachment,
    String? replyToMessageId,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    if (failSend) throw const ServerException('offline');
    return sent!;
  }

  // Everything else (createConversation, getConversation, markRead, deletes,
  // attachment url) is unused by these tests.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
