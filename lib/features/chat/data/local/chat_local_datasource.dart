import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drop/core/enums/chat_attachment_kind.dart';
import 'package:drop/core/enums/chat_message_type.dart';
import 'package:drop/features/chat/data/local/chat_database.dart';
import 'package:drop/features/chat/domain/entities/chat_conversation.dart';
import 'package:drop/features/chat/domain/entities/chat_message.dart';

/// A logical text send awaiting server confirmation — the durable outbox
/// record. Reconstructed into a `FAILED` local bubble on a cold open and
/// re-sent (reusing [idempotencyKey], so the backend dedupes) after reconnect.
class PendingChatSend {
  const PendingChatSend({
    required this.idempotencyKey,
    required this.conversationId,
    this.content,
    this.replyToMessageId,
  });

  final String idempotencyKey;
  final String conversationId;
  final String? content;
  final String? replyToMessageId;
}

/// The local (Drift/SQLite) side of the chat repository — the offline cache.
/// Symmetric with [ChatRemoteDataSource]: the repository reads it first / falls
/// back to it, and write-throughs every server truth into it. All mapping
/// between Drift rows and domain entities lives here, so the repository stays a
/// thin orchestrator.
///
/// **Conflict-safe by construction:** every write is an idempotent upsert keyed
/// by id (`insertOnConflictUpdate`), and ordering is driven by the immutable,
/// server-assigned `seq` — never by local wall-clock — so a message can be
/// merged from REST, the socket, or a retry in any order and the cache
/// converges to the same, correctly-ordered result.
abstract class ChatLocalDataSource {
  // ── Conversations (inbox) ──
  Future<List<ChatConversationSummary>> readConversations();
  Future<void> upsertConversations(List<ChatConversationSummary> items);
  Future<ChatConversation?> readConversation(String conversationId);
  Future<void> upsertConversation(ChatConversation conversation);

  // ── Messages ──
  /// Newest [limit] messages of the conversation, returned oldest → newest
  /// (the page contract). Excludes nothing — tombstones are cached as-is.
  Future<List<ChatMessage>> readNewestMessages(
    String conversationId, {
    int limit,
  });

  /// The page of messages strictly older than [beforeSeq], oldest → newest.
  Future<List<ChatMessage>> readMessagesBefore(
    String conversationId,
    BigInt beforeSeq, {
    int limit,
  });

  /// The smallest cached `seq` in the conversation (the oldest cached message),
  /// or null when nothing is cached — used to decide whether more history could
  /// exist below the cached window.
  Future<BigInt?> oldestCachedSeq(String conversationId);

  Future<void> upsertMessages(String conversationId, List<ChatMessage> items);

  /// Removes one message from the cache (delete-for-me — one-sided).
  Future<void> deleteMessage(String messageId);

  /// Persists the per-thread bookkeeping used to resume online pagination and
  /// own-message alignment after a cold re-open.
  Future<void> saveThreadMeta(
    String conversationId, {
    String? myUserId,
    String? nextCursor,
  });

  /// The `(myUserId, nextCursor)` last saved for the thread, if any.
  Future<({String? myUserId, String? nextCursor})?> readThreadMeta(
    String conversationId,
  );

  // ── Outbox (durable pending sends) ──
  Future<void> enqueuePending(PendingChatSend send);
  Future<void> dequeuePending(String idempotencyKey);
  Future<List<PendingChatSend>> readPending(String conversationId);

  // ── Invalidation ──
  Future<void> clearConversation(String conversationId);
  Future<void> clearAll();
}

class ChatLocalDataSourceImpl implements ChatLocalDataSource {
  final ChatDatabase _db;
  ChatLocalDataSourceImpl(this._db);

  static int _ms(DateTime d) => d.toUtc().millisecondsSinceEpoch;
  static DateTime _date(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();

  // ─── Conversations ────────────────────────────────────────────────────

  @override
  Future<List<ChatConversationSummary>> readConversations() async {
    final rows = await (_db.select(_db.chatConversationRows)
          ..orderBy([
            (c) => OrderingTerm(
                  expression: c.lastMessageAtMs,
                  mode: OrderingMode.desc,
                ),
            (c) => OrderingTerm(
                  expression: c.createdAtMs,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();
    return rows.map(_summaryOf).toList(growable: false);
  }

  @override
  Future<void> upsertConversations(List<ChatConversationSummary> items) async {
    if (items.isEmpty) return;
    await _db.batch((b) {
      for (final s in items) {
        b.insert(
          _db.chatConversationRows,
          ChatConversationRowsCompanion.insert(
            id: s.id,
            participantIds: jsonEncode(s.participantIds),
            counterpartUserId: Value(s.counterpartUserId),
            counterpartExternalId: Value(s.counterpartExternalId),
            createdAtMs: _ms(s.createdAt),
            lastMessageAtMs: Value(
                s.lastMessageAt == null ? null : _ms(s.lastMessageAt!)),
            syncedAtMs: Value(_ms(DateTime.now())),
          ),
          // Preserve locally-derived fields (myUserId, nextCursor) that the
          // list endpoint doesn't carry, by only overwriting list-owned columns.
          onConflict: DoUpdate(
            (old) => ChatConversationRowsCompanion(
              participantIds: Value(jsonEncode(s.participantIds)),
              counterpartUserId: Value(s.counterpartUserId),
              counterpartExternalId: Value(s.counterpartExternalId),
              createdAtMs: Value(_ms(s.createdAt)),
              lastMessageAtMs: Value(
                  s.lastMessageAt == null ? null : _ms(s.lastMessageAt!)),
              syncedAtMs: Value(_ms(DateTime.now())),
            ),
          ),
        );
      }
    });
  }

  @override
  Future<ChatConversation?> readConversation(String conversationId) async {
    final row = await (_db.select(_db.chatConversationRows)
          ..where((c) => c.id.equals(conversationId)))
        .getSingleOrNull();
    if (row == null) return null;
    return ChatConversation(
      id: row.id,
      participantIds: _stringList(row.participantIds),
      createdAt: _date(row.createdAtMs),
      lastMessageAt:
          row.lastMessageAtMs == null ? null : _date(row.lastMessageAtMs!),
    );
  }

  @override
  Future<void> upsertConversation(ChatConversation conversation) async {
    await _db.into(_db.chatConversationRows).insertOnConflictUpdate(
          ChatConversationRowsCompanion(
            id: Value(conversation.id),
            participantIds: Value(jsonEncode(conversation.participantIds)),
            createdAtMs: Value(_ms(conversation.createdAt)),
            lastMessageAtMs: Value(conversation.lastMessageAt == null
                ? null
                : _ms(conversation.lastMessageAt!)),
            syncedAtMs: Value(_ms(DateTime.now())),
          ),
        );
  }

  ChatConversationSummary _summaryOf(ChatConversationRow row) =>
      ChatConversationSummary(
        id: row.id,
        counterpartUserId: row.counterpartUserId ?? '',
        counterpartExternalId: row.counterpartExternalId,
        participantIds: _stringList(row.participantIds),
        createdAt: _date(row.createdAtMs),
        lastMessageAt:
            row.lastMessageAtMs == null ? null : _date(row.lastMessageAtMs!),
      );

  // ─── Messages ─────────────────────────────────────────────────────────

  @override
  Future<List<ChatMessage>> readNewestMessages(
    String conversationId, {
    int limit = 30,
  }) async {
    final rows = await (_db.select(_db.chatMessageRows)
          ..where((m) => m.conversationId.equals(conversationId))
          ..orderBy([
            (m) => OrderingTerm(expression: m.seq, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .get();
    return rows.reversed.map(_messageOf).toList(growable: false);
  }

  @override
  Future<List<ChatMessage>> readMessagesBefore(
    String conversationId,
    BigInt beforeSeq, {
    int limit = 30,
  }) async {
    final rows = await (_db.select(_db.chatMessageRows)
          ..where((m) =>
              m.conversationId.equals(conversationId) &
              m.seq.isSmallerThanValue(beforeSeq.toInt()))
          ..orderBy([
            (m) => OrderingTerm(expression: m.seq, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .get();
    return rows.reversed.map(_messageOf).toList(growable: false);
  }

  @override
  Future<BigInt?> oldestCachedSeq(String conversationId) async {
    final min = _db.chatMessageRows.seq.min();
    final query = _db.selectOnly(_db.chatMessageRows)
      ..addColumns([min])
      ..where(_db.chatMessageRows.conversationId.equals(conversationId));
    final row = await query.getSingleOrNull();
    final value = row?.read(min);
    return value == null ? null : BigInt.from(value);
  }

  @override
  Future<void> upsertMessages(
    String conversationId,
    List<ChatMessage> items,
  ) async {
    if (items.isEmpty) return;
    await _db.batch((b) {
      for (final m in items) {
        b.insert(
          _db.chatMessageRows,
          _companionOf(conversationId, m),
          onConflict: DoUpdate((_) => _companionOf(conversationId, m)),
        );
      }
    });
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    await (_db.delete(_db.chatMessageRows)
          ..where((m) => m.id.equals(messageId)))
        .go();
  }

  ChatMessageRowsCompanion _companionOf(String conversationId, ChatMessage m) {
    final att = m.attachment;
    final reply = m.replyTo;
    return ChatMessageRowsCompanion(
      id: Value(m.id),
      conversationId: Value(conversationId),
      senderId: Value(m.senderId),
      type: Value(m.type.value),
      body: Value(m.body),
      seq: Value(m.seq.toInt()),
      status: Value(m.status),
      createdAtMs: Value(_ms(m.createdAt)),
      deletedForEveryone: Value(m.deletedForEveryone),
      attachmentId: Value(att?.id),
      attachmentKind: Value(att?.kind.value),
      attachmentFormat: Value(att?.format),
      attachmentMimeType: Value(att?.mimeType),
      attachmentFilename: Value(att?.originalFilename),
      attachmentByteSize: Value(att?.byteSize),
      replyToId: Value(reply?.id),
      replySenderId: Value(reply?.senderId),
      replyType: Value(reply?.type.value),
      replyBody: Value(reply?.body),
      replyAttachmentJson:
          Value(reply?.attachment == null ? null : _encodeAtt(reply!.attachment!)),
    );
  }

  ChatMessage _messageOf(ChatMessageRow row) => ChatMessage(
        id: row.id,
        conversationId: row.conversationId,
        senderId: row.senderId,
        type: ChatMessageType.fromString(row.type),
        body: row.body,
        attachment: _attachmentOf(row),
        replyTo: _replyOf(row),
        seq: BigInt.from(row.seq),
        status: row.status,
        createdAt: _date(row.createdAtMs),
        deletedForEveryone: row.deletedForEveryone,
      );

  ChatMessageAttachment? _attachmentOf(ChatMessageRow row) {
    final id = row.attachmentId;
    if (id == null) return null;
    return ChatMessageAttachment(
      id: id,
      kind: ChatAttachmentKind.fromString(row.attachmentKind),
      format: row.attachmentFormat ?? '',
      mimeType: row.attachmentMimeType ?? '',
      originalFilename: row.attachmentFilename ?? '',
      byteSize: row.attachmentByteSize ?? 0,
    );
  }

  ChatReplyPreview? _replyOf(ChatMessageRow row) {
    final id = row.replyToId;
    if (id == null) return null;
    return ChatReplyPreview(
      id: id,
      senderId: row.replySenderId ?? '',
      type: ChatMessageType.fromString(row.replyType),
      body: row.replyBody,
      attachment: _decodeAtt(row.replyAttachmentJson),
    );
  }

  static Map<String, dynamic> _attMap(ChatMessageAttachment a) => {
        'id': a.id,
        'kind': a.kind.value,
        'format': a.format,
        'mimeType': a.mimeType,
        'originalFilename': a.originalFilename,
        'byteSize': a.byteSize,
      };

  static String _encodeAtt(ChatMessageAttachment a) => jsonEncode(_attMap(a));

  static ChatMessageAttachment? _decodeAtt(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final json = (jsonDecode(raw) as Map).cast<String, dynamic>();
    return ChatMessageAttachment(
      id: json['id'] as String? ?? '',
      kind: ChatAttachmentKind.fromString(json['kind'] as String?),
      format: json['format'] as String? ?? '',
      mimeType: json['mimeType'] as String? ?? '',
      originalFilename: json['originalFilename'] as String? ?? '',
      byteSize: (json['byteSize'] as num?)?.toInt() ?? 0,
    );
  }

  // ─── Thread bookkeeping ─────────────────────────────────────────────────

  @override
  Future<void> saveThreadMeta(
    String conversationId, {
    String? myUserId,
    String? nextCursor,
  }) async {
    await (_db.update(_db.chatConversationRows)
          ..where((c) => c.id.equals(conversationId)))
        .write(ChatConversationRowsCompanion(
      myUserId: Value(myUserId),
      nextCursor: Value(nextCursor),
    ));
  }

  @override
  Future<({String? myUserId, String? nextCursor})?> readThreadMeta(
    String conversationId,
  ) async {
    final row = await (_db.select(_db.chatConversationRows)
          ..where((c) => c.id.equals(conversationId)))
        .getSingleOrNull();
    if (row == null) return null;
    return (myUserId: row.myUserId, nextCursor: row.nextCursor);
  }

  // ─── Outbox ─────────────────────────────────────────────────────────────

  @override
  Future<void> enqueuePending(PendingChatSend send) async {
    await _db.into(_db.pendingMessageRows).insertOnConflictUpdate(
          PendingMessageRowsCompanion.insert(
            idempotencyKey: send.idempotencyKey,
            conversationId: send.conversationId,
            content: Value(send.content),
            replyToMessageId: Value(send.replyToMessageId),
            createdAtMs: _ms(DateTime.now()),
          ),
        );
  }

  @override
  Future<void> dequeuePending(String idempotencyKey) async {
    await (_db.delete(_db.pendingMessageRows)
          ..where((p) => p.idempotencyKey.equals(idempotencyKey)))
        .go();
  }

  @override
  Future<List<PendingChatSend>> readPending(String conversationId) async {
    final rows = await (_db.select(_db.pendingMessageRows)
          ..where((p) => p.conversationId.equals(conversationId))
          ..orderBy([
            (p) => OrderingTerm(expression: p.createdAtMs),
          ]))
        .get();
    return rows
        .map((r) => PendingChatSend(
              idempotencyKey: r.idempotencyKey,
              conversationId: r.conversationId,
              content: r.content,
              replyToMessageId: r.replyToMessageId,
            ))
        .toList(growable: false);
  }

  // ─── Invalidation ─────────────────────────────────────────────────────

  @override
  Future<void> clearConversation(String conversationId) async {
    await (_db.delete(_db.chatMessageRows)
          ..where((m) => m.conversationId.equals(conversationId)))
        .go();
    await (_db.delete(_db.pendingMessageRows)
          ..where((p) => p.conversationId.equals(conversationId)))
        .go();
    await (_db.delete(_db.chatConversationRows)
          ..where((c) => c.id.equals(conversationId)))
        .go();
  }

  @override
  Future<void> clearAll() async {
    await _db.batch((b) {
      b.deleteAll(_db.chatMessageRows);
      b.deleteAll(_db.pendingMessageRows);
      b.deleteAll(_db.chatConversationRows);
    });
  }

  static List<String> _stringList(String raw) {
    if (raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    return decoded is List ? decoded.whereType<String>().toList() : const [];
  }
}
