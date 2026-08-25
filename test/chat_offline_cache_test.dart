import 'dart:io';

import 'package:drift/native.dart';
import 'package:opshub/core/enums/chat_attachment_kind.dart';
import 'package:opshub/core/enums/chat_message_type.dart';
import 'package:opshub/core/errors/exceptions.dart';
import 'package:opshub/core/errors/failures.dart';
import 'package:opshub/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:opshub/features/chat/data/local/chat_database.dart';
import 'package:opshub/features/chat/data/local/chat_local_datasource.dart';
import 'package:opshub/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:opshub/features/chat/domain/entities/chat_attachment_download.dart';
import 'package:opshub/features/chat/domain/entities/chat_conversation.dart';
import 'package:opshub/features/chat/domain/entities/chat_message.dart';
import 'package:opshub/features/chat/domain/entities/chat_outgoing_attachment.dart';
import 'package:opshub/features/chat/domain/entities/chat_read_receipt.dart';
import 'package:opshub/features/chat/presentation/chat_thread_cache.dart';
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

ChatConversationSummary _summary({DateTime? lastAt, int unread = 0}) =>
    ChatConversationSummary(
      id: _conv,
      counterpartUserId: _them,
      counterpartExternalId: 'firebase-them',
      participantIds: const [_me, _them],
      createdAt: DateTime.utc(2026, 7, 24),
      lastMessageAt: lastAt,
      unreadCount: unread,
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

    test('the server unread count survives a cold/offline paint', () async {
      // Regression: unreadCount was never persisted, so every cached inbox
      // paint reported zero unread until the network answered — unread
      // messages were invisible on a cold offline open.
      await local.upsertConversations([_summary(unread: 4)]);
      expect((await local.readConversations()).single.unreadCount, 4);

      // The count is server-owned, so a later list read refreshes it.
      await local.upsertConversations([_summary(unread: 1)]);
      expect((await local.readConversations()).single.unreadCount, 1);
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

    test(
        'an exhausted cache hands back the server cursor, not "end of history"',
        () async {
      // Regression: running out of cached messages was treated as reaching the
      // start of the thread, so an offline open of a thread whose older history
      // was simply never cached claimed "beginning of the conversation".
      await local.upsertConversations([_summary()]);
      await local.upsertMessages(_conv, [_msg(1), _msg(2)]);
      await local.saveThreadMeta(_conv, nextCursor: 'server-cursor-1');
      final remote = _FakeRemote()..failHistory = true;
      final repo = ChatRepositoryImpl(remote, local);

      final page = await repo.getMessageHistory(conversationId: _conv);
      expect(page.items.map((m) => m.seq.toInt()), [1, 2]);
      // The cache is exhausted, but the server still has older pages — so
      // scroll-back must stay available and resume from the server cursor.
      expect(page.nextCursor, 'server-cursor-1');
    });

    test('an exhausted cache stops when the server reported no more history',
        () async {
      // The other side of the same rule: a stored null cursor means the last
      // online fetch genuinely reached the start, so stopping is correct.
      await local.upsertConversations([_summary()]);
      await local.upsertMessages(_conv, [_msg(1), _msg(2)]);
      await local.saveThreadMeta(_conv, nextCursor: null);
      final remote = _FakeRemote()..failHistory = true;
      final repo = ChatRepositoryImpl(remote, local);

      final page = await repo.getMessageHistory(conversationId: _conv);
      expect(page.nextCursor, isNull);
    });

    test('a confirmed mark-read zeroes the cached unread count', () async {
      // Caching unreadCount would otherwise introduce its own staleness: a
      // thread read offline and reopened offline would keep showing its
      // pre-read badge until the next successful list fetch.
      await local.upsertConversations([_summary(unread: 3)]);
      final repo = ChatRepositoryImpl(_FakeRemote(), local);

      await repo.markMessagesRead(
        conversationId: _conv,
        upToSeq: BigInt.from(9),
      );
      expect((await local.readConversations()).single.unreadCount, 0);
    });

    test('discardPending removes a doomed send from the durable outbox',
        () async {
      // Regression: a send the server permanently rejects had no discard path.
      // Its outbox row survived, so it was re-dispatched on every app open and
      // every reconnect, forever, with no way for the user to be rid of it.
      final cache = ChatThreadCache()..attachLocal(local);
      await local.enqueuePending(const PendingChatSend(
        idempotencyKey: 'doomed-key',
        conversationId: _conv,
        content: 'never accepted',
      ));
      expect(await local.readPending(_conv), hasLength(1));

      await cache.discardPending('doomed-key');
      expect(await local.readPending(_conv), isEmpty);
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

    test('an unexpired brokered attachment URL is fetched once and reused',
        () async {
      final remote = _FakeRemote()
        ..attachmentDownloads = [
          ChatAttachmentDownload(
            url: 'https://storage.example/photo-v1',
            expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
          ),
        ];
      final repo = ChatRepositoryImpl(remote, local);

      final first = await repo.getAttachmentDownloadUrl(
        conversationId: _conv,
        messageId: 'image-1',
      );
      final second = await repo.getAttachmentDownloadUrl(
        conversationId: _conv,
        messageId: 'image-1',
      );

      expect(first.url, second.url);
      expect(remote.attachmentDownloadCalls, 1);
    });

    test('an expired brokered attachment URL refreshes exactly once', () async {
      final remote = _FakeRemote()
        ..attachmentDownloads = [
          ChatAttachmentDownload(
            url: 'https://storage.example/expired',
            expiresAt:
                DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
          ),
          ChatAttachmentDownload(
            url: 'https://storage.example/fresh',
            expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
          ),
        ];
      final repo = ChatRepositoryImpl(remote, local);

      await repo.getAttachmentDownloadUrl(
        conversationId: _conv,
        messageId: 'image-1',
      );
      final refreshed = await repo.getAttachmentDownloadUrl(
        conversationId: _conv,
        messageId: 'image-1',
      );
      await repo.getAttachmentDownloadUrl(
        conversationId: _conv,
        messageId: 'image-1',
      );

      expect(refreshed.url, 'https://storage.example/fresh');
      expect(remote.attachmentDownloadCalls, 2);
    });
  });

  group('schema migration v1 → v2', () {
    late Directory dir;
    late File file;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('drop_chat_migration');
      file = File('${dir.path}/chat.sqlite');
    });

    tearDown(() => dir.deleteSync(recursive: true));

    test('adds unreadCount to an existing v1 database without losing data',
        () async {
      // Every other test opens `.memory()`, which runs onCreate — the upgrade
      // path that real installs take was otherwise never executed. Build a
      // genuine v1 file (v2 minus the new column, user_version rolled back),
      // then let drift open it and run the migration for real.
      final v1 = ChatDatabase(NativeDatabase(file));
      await v1.customStatement(
          'ALTER TABLE chat_conversation_rows DROP COLUMN unread_count');
      await v1.customStatement('PRAGMA user_version = 1');
      await v1.customStatement(
        "INSERT INTO chat_conversation_rows "
        "(id, participant_ids, counterpart_user_id, counterpart_external_id, "
        " created_at_ms, last_message_at_ms, my_user_id, next_cursor, "
        " synced_at_ms) "
        "VALUES ('$_conv', '[\"$_me\",\"$_them\"]', '$_them', "
        " 'firebase-them', 1000, 2000, '$_me', 'cursor-1', 3000)",
      );
      await v1.close();

      // Reopen at the current schema: drift sees user_version 1 and upgrades.
      final v2 = ChatDatabase(NativeDatabase(file));
      final migrated = ChatLocalDataSourceImpl(v2);
      final rows = await migrated.readConversations();

      expect(rows, hasLength(1), reason: 'the v1 row must survive the upgrade');
      final row = rows.single;
      expect(row.id, _conv);
      expect(row.counterpartUserId, _them);
      expect(row.counterpartExternalId, 'firebase-them');
      expect(row.participantIds, [_me, _them]);
      // The new column lands on its default and is corrected by the next
      // (server-authoritative) list read.
      expect(row.unreadCount, 0);
      // Locally-derived bookkeeping must be untouched by the migration.
      expect((await migrated.readThreadMeta(_conv))?.nextCursor, 'cursor-1');

      // And the column is genuinely usable afterwards.
      await migrated.upsertConversations([_summary(unread: 7)]);
      expect((await migrated.readConversations()).single.unreadCount, 7);
      await v2.close();
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
  int attachmentDownloadCalls = 0;
  List<ChatAttachmentDownload> attachmentDownloads = [];

  @override
  Future<ChatReadReceipt> markRead({
    required String conversationId,
    required BigInt upToSeq,
  }) async =>
      ChatReadReceipt(
        conversationId: conversationId,
        markedCount: 1,
        readAt: DateTime.utc(2026, 7, 24, 14),
      );

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

  @override
  Future<ChatAttachmentDownload> getAttachmentDownloadUrl({
    required String conversationId,
    required String messageId,
  }) async {
    attachmentDownloadCalls++;
    return attachmentDownloads.removeAt(0);
  }

  // Everything else (createConversation, getConversation, markRead, deletes,
  // attachment url) is unused by these tests.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
