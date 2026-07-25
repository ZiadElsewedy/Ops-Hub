import 'dart:async';

import 'package:drop/core/enums/chat_message_type.dart';
import 'package:drop/core/utils/app_logger.dart';
import 'package:drop/features/chat/data/local/chat_local_datasource.dart';
import 'package:drop/features/chat/domain/entities/chat_conversation.dart';
import 'package:drop/features/chat/domain/entities/chat_message.dart';

/// The confirmed, server-authoritative state of one thread, kept for instant
/// re-open. [messages] holds only what has actually come back from the backend
/// — pending (optimistic) sends are excluded so a reopened thread never shows a
/// stuck "sending" bubble from a torn-down session.
///
/// [pending] carries the durable outbox restored from disk on a **cold** open —
/// text sends that were never acknowledged, materialized as `FAILED` bubbles so
/// the user sees them and they can be retried after reconnect. It is always
/// empty for an in-memory (hot) snapshot.
class ChatThreadSnapshot {
  const ChatThreadSnapshot({
    required this.conversation,
    required this.messages,
    this.nextCursor,
    this.myUserId,
    this.pending = const [],
  });

  final ChatConversation conversation;
  final List<ChatMessage> messages;
  final String? nextCursor;
  final String? myUserId;
  final List<ChatMessage> pending;
}

/// A cache of thread snapshots keyed by conversation id, with two tiers:
///
/// - an **in-memory** hot tier (synchronous [get]/[put]) — the process-lifetime
///   cache that already lets a re-opened conversation paint its last messages
///   instantly while it refreshes in the background; and
/// - an optional **durable** tier ([ChatLocalDataSource], Drift/SQLite) — so the
///   same instant open survives a full app restart, and so realtime-delivered
///   messages (which reach the thread cubit through [put], never through the
///   repository) are persisted for offline reading.
///
/// The durable tier is write-through and best-effort: a persistence error is
/// logged, never surfaced, and the in-memory tier keeps working. When no local
/// datasource is wired (e.g. unit tests) this behaves exactly like the original
/// in-memory-only cache.
///
/// A single instance is held in the DI container and shared across every
/// per-thread cubit, so the same conversation reopened later reuses its snapshot.
class ChatThreadCache {
  ChatThreadCache([this._local]);

  /// The durable tier. Nullable and settable once via [attachLocal] so the DI
  /// container can construct the cache eagerly (it is referenced by static
  /// helpers that run before `init()` in tests) and wire the Drift datasource
  /// during `init()`.
  ChatLocalDataSource? _local;
  final Map<String, ChatThreadSnapshot> _store = {};

  /// Wires the durable tier after construction. Idempotent-safe: a second call
  /// simply replaces the datasource.
  void attachLocal(ChatLocalDataSource local) => _local = local;

  /// The in-memory snapshot for [conversationId] (synchronous, hot path).
  ChatThreadSnapshot? get(String conversationId) => _store[conversationId];

  /// Stores [snapshot] in memory and, when a durable tier is wired, mirrors its
  /// confirmed messages + conversation + per-thread bookkeeping to disk
  /// (fire-and-forget — never blocks the UI emit that triggered it).
  void put(String conversationId, ChatThreadSnapshot snapshot) {
    _store[conversationId] = snapshot;
    final local = _local;
    if (local == null) return;
    unawaited(_persist(local, conversationId, snapshot));
  }

  Future<void> _persist(
    ChatLocalDataSource local,
    String conversationId,
    ChatThreadSnapshot snapshot,
  ) async {
    try {
      await local.upsertConversation(snapshot.conversation);
      await local.upsertMessages(conversationId, snapshot.messages);
      await local.saveThreadMeta(
        conversationId,
        myUserId: snapshot.myUserId,
        nextCursor: snapshot.nextCursor,
      );
    } catch (e) {
      AppLog.warning('chat', 'thread cache persist failed: $e');
    }
  }

  /// Rebuilds the confirmed thread state from the durable tier — the cold-start
  /// instant open. Returns the in-memory snapshot (or null) when there is no
  /// durable tier or nothing is cached on disk. Also warms the in-memory tier so
  /// a subsequent [get] is a hit. Outbox (pending) bubbles are handled
  /// separately by [restorePending], so this stays a fast, confirmed-only read.
  Future<ChatThreadSnapshot?> restore(String conversationId) async {
    final local = _local;
    if (local == null) return _store[conversationId];
    try {
      final conversation = await local.readConversation(conversationId);
      if (conversation == null) return _store[conversationId];
      final messages =
          await local.readNewestMessages(conversationId, limit: 30);
      final meta = await local.readThreadMeta(conversationId);

      final snapshot = ChatThreadSnapshot(
        conversation: conversation,
        messages: messages,
        nextCursor: meta?.nextCursor,
        myUserId: meta?.myUserId,
      );
      _store[conversationId] = snapshot;
      return snapshot;
    } catch (e) {
      AppLog.warning('chat', 'thread cache restore failed: $e');
      return _store[conversationId];
    }
  }

  /// The durable outbox for [conversationId], materialized as `FAILED` local
  /// bubbles sequenced just past [afterSeq] so they render at the bottom. The id
  /// is `local:<idempotencyKey>` so the cubit's existing retry recovers the key
  /// and the backend dedupes a duplicate send. Empty when no durable tier is
  /// wired or nothing is queued.
  Future<List<ChatMessage>> restorePending(
    String conversationId, {
    BigInt? afterSeq,
  }) async {
    final local = _local;
    if (local == null) return const [];
    try {
      final pending = await local.readPending(conversationId);
      if (pending.isEmpty) return const [];
      final meta = await local.readThreadMeta(conversationId);
      var seq = afterSeq ?? BigInt.zero;
      final now = DateTime.now();
      return [
        for (final p in pending)
          ChatMessage(
            id: 'local:${p.idempotencyKey}',
            conversationId: p.conversationId,
            senderId: meta?.myUserId ?? '',
            type: ChatMessageType.text,
            body: p.content,
            seq: seq += BigInt.one,
            status: 'FAILED',
            createdAt: now,
          ),
      ];
    } catch (e) {
      AppLog.warning('chat', 'thread cache pending restore failed: $e');
      return const [];
    }
  }

  /// Drops the in-memory tier (durable tier is cleared separately on sign-out
  /// via the local datasource).
  void clear() => _store.clear();
}
