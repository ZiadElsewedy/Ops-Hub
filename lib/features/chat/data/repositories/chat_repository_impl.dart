import 'package:drop/core/errors/exceptions.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/core/utils/app_logger.dart';
import 'package:drop/core/network/network_guard.dart';
import 'package:drop/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:drop/features/chat/data/local/chat_local_datasource.dart';
import 'package:drop/features/chat/domain/entities/chat_attachment_download.dart';
import 'package:drop/features/chat/domain/entities/chat_conversation.dart';
import 'package:drop/features/chat/domain/entities/chat_message.dart';
import 'package:drop/features/chat/domain/entities/chat_outgoing_attachment.dart';
import 'package:drop/features/chat/domain/entities/chat_read_receipt.dart';
import 'package:drop/features/chat/domain/repositories/chat_repository.dart';

/// [ChatRepository] backed by the NestJS API, with an optional Drift-backed
/// offline cache ([ChatLocalDataSource]).
///
/// **Contract preserved.** When [_local] is null the repository behaves exactly
/// as the REST-only original (this is how the unit tests construct it) — every
/// method is a guarded remote call. When a cache is wired, the repository
/// becomes cache-aware without changing a single signature:
///
/// - **Read-through / write-through.** A successful remote read is mirrored
///   into the cache; the network stays the source of truth.
/// - **Offline fallback.** If the first page of the inbox or a thread's newest
///   history can't be fetched, the cache serves what it has instead of an error
///   — the WhatsApp/Telegram "open instantly, sync in the background" feel. If
///   the cache is *also* empty, the original failure propagates so the existing
///   error UI still shows.
/// - **Cache-first back-pagination.** Older history is served straight from the
///   cache while it lasts (a `local:<seq>` cursor), so scroll-back is instant
///   and works offline; only once the cache is exhausted does the server cursor
///   take over.
/// - **Durable outbox.** A text send is persisted before dispatch and dropped
///   on acknowledgement, so a message composed offline survives a restart and
///   is retried after reconnect (the idempotency key makes the retry safe).
///
/// A cache write never breaks a successful network call: cache errors are
/// swallowed (and logged), not surfaced.
class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource _remote;
  final ChatLocalDataSource? _local;

  // Brokered URLs are short-lived credentials, not attachment bytes. Keeping
  // them here makes every thumbnail/viewer request in this app session reuse
  // the same URL until the server-provided expiry, which in turn lets
  // Flutter's URL-keyed ImageCache reuse the decoded image.
  final Map<String, ChatAttachmentDownload> _attachmentDownloads = {};
  final Map<String, Future<ChatAttachmentDownload>> _attachmentDownloadRequests =
      {};

  ChatRepositoryImpl(this._remote, [this._local]);

  /// Drops every cached brokered URL. Called on sign-out beside the other chat
  /// cache wipes: these are short-lived **credentials** for another account's
  /// attachments, so a shared device must not carry them into the next session.
  void clearAttachmentUrlCache() {
    _attachmentDownloads.clear();
    _attachmentDownloadRequests.clear();
  }

  /// Prefix on a message-history cursor that the repository itself minted to
  /// page **backwards through the cache** (encodes the oldest seq served so
  /// far). Distinct from an opaque server cursor, which is never this shape.
  static const _localCursor = 'local:';

  /// How many cached messages a cache-served page returns. Comfortably covers
  /// the server's default page (20) so an offline page is never thinner than an
  /// online one.
  static const _cachePageSize = 30;

  /// Maps datasource exceptions to the failure vocabulary the cubits handle.
  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } on ConflictException catch (e) {
      throw ConflictFailure(e.message);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  /// Runs [remote] (mapping its exceptions to failures), mirrors the result
  /// into the cache via [persist] (best-effort), and on failure falls back to
  /// [fallback] when it can produce something. The original failure propagates
  /// when there is no cache fallback or the cache is empty.
  Future<T> _readThrough<T>({
    required Future<T> Function() remote,
    Future<void> Function(T value)? persist,
    Future<T?> Function()? fallback,
  }) async {
    try {
      final value = await _guard(remote);
      if (persist != null) {
        try {
          await persist(value);
        } catch (e) {
          AppLog.warning('chat', 'cache write failed: $e');
        }
      }
      return value;
    } on Failure {
      if (fallback != null) {
        try {
          final cached = await fallback();
          if (cached != null) return cached;
        } catch (e) {
          AppLog.warning('chat', 'cache read failed: $e');
        }
      }
      rethrow;
    }
  }

  // ─── Conversations ────────────────────────────────────────────────────

  @override
  Future<ChatConversation> startConversation(String targetUserId) => _guard(
      () async => (await _remote.createConversation(targetUserId)).toEntity());

  @override
  Future<ChatConversationPage> getConversations({int? limit, String? cursor}) =>
      _readThrough(
        remote: () => _remote.listConversations(limit: limit, cursor: cursor),
        persist: (page) => _local?.upsertConversations(page.items) ?? Future.value(),
        // Only the first page (cursor == null) is served from the cache when
        // offline — deeper pages are inherently network-bound.
        fallback: (_local == null || cursor != null) ? null : _cachedConversations,
      );

  @override
  Future<List<ChatConversationSummary>> getCachedConversations() async {
    final local = _local;
    if (local == null) return const [];
    try {
      return await local.readConversations();
    } catch (e) {
      AppLog.warning('chat', 'cached conversations read failed: $e');
      return const [];
    }
  }

  Future<ChatConversationPage?> _cachedConversations() async {
    final cached = await _local!.readConversations();
    if (cached.isEmpty) return null;
    // The cache holds one flat, activity-ordered list — no server pagination.
    return ChatConversationPage(items: cached, nextCursor: null);
  }

  @override
  Future<ChatConversation> getConversation(String conversationId) =>
      _readThrough(
        remote: () async =>
            (await _remote.getConversation(conversationId)).toEntity(),
        persist: (conv) => _local?.upsertConversation(conv) ?? Future.value(),
        fallback:
            _local == null ? null : () => _local.readConversation(conversationId),
      );

  // ─── Messages ─────────────────────────────────────────────────────────

  @override
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String idempotencyKey,
    String? content,
    ChatOutgoingAttachment? attachment,
    String? replyToMessageId,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    NetworkGuard.ensureWritable();
    // Durable outbox — text sends only. Persist before dispatch so a message
    // composed offline (or lost to a crash) survives and can be retried after
    // reconnect; the same idempotency key makes the retry duplicate-safe. An
    // attachment's bytes are deliberately never persisted, so those keep the
    // in-session retry.
    final isTextSend =
        attachment == null && (content?.trim().isNotEmpty ?? false);
    if (_local != null && isTextSend) {
      try {
        await _local.enqueuePending(PendingChatSend(
          idempotencyKey: idempotencyKey,
          conversationId: conversationId,
          content: content,
          replyToMessageId: replyToMessageId,
        ));
      } catch (e) {
        AppLog.warning('chat', 'outbox enqueue failed: $e');
      }
    }

    final sent = await _guard(() => _remote.sendMessage(
          conversationId: conversationId,
          idempotencyKey: idempotencyKey,
          content: content,
          attachment: attachment,
          replyToMessageId: replyToMessageId,
          onSendProgress: onSendProgress,
        ));

    // Acknowledged — persist the authoritative message and drain the outbox.
    if (_local != null) {
      try {
        await _local.upsertMessages(conversationId, [sent]);
        await _local.dequeuePending(idempotencyKey);
      } catch (e) {
        AppLog.warning('chat', 'cache write after send failed: $e');
      }
    }
    return sent;
  }

  @override
  Future<ChatMessagePage> getMessageHistory({
    required String conversationId,
    int? limit,
    String? cursor,
  }) {
    // Cache-first back-pagination: a `local:` cursor pages through the cache
    // without touching the network (instant, works offline).
    if (_local != null && cursor != null && cursor.startsWith(_localCursor)) {
      return _cachedOlderPage(conversationId, cursor);
    }
    final isFirstPage = cursor == null;
    return _readThrough(
      remote: () =>
          _remote.loadHistory(conversationId: conversationId, cursor: cursor, limit: limit),
      persist: (page) async {
        final local = _local;
        if (local == null) return;
        await local.upsertMessages(conversationId, page.items);
        if (isFirstPage) {
          await local.saveThreadMeta(conversationId, nextCursor: page.nextCursor);
        }
      },
      // Only the newest page (cursor == null) has a cache equivalent; a server
      // cursor we can't decode offline surfaces the original failure.
      fallback: (_local == null || !isFirstPage)
          ? null
          : () => _cachedNewestPage(conversationId),
    );
  }

  Future<ChatMessagePage?> _cachedNewestPage(String conversationId) async {
    final cached =
        await _local!.readNewestMessages(conversationId, limit: _cachePageSize);
    if (cached.isEmpty) return null;
    return ChatMessagePage(
      items: cached,
      nextCursor: await _localCursorIfMore(conversationId, cached.first.seq),
    );
  }

  Future<ChatMessagePage> _cachedOlderPage(
    String conversationId,
    String cursor,
  ) async {
    final beforeSeq = BigInt.tryParse(cursor.substring(_localCursor.length));
    if (beforeSeq == null) return const ChatMessagePage(items: []);
    final older = await _local!
        .readMessagesBefore(conversationId, beforeSeq, limit: _cachePageSize);
    if (older.isEmpty) return const ChatMessagePage(items: []);
    return ChatMessagePage(
      items: older,
      nextCursor: await _localCursorIfMore(conversationId, older.first.seq),
    );
  }

  /// The cursor to page further back from [oldestServed].
  ///
  /// While the cache still holds older messages, that is a `local:` cursor and
  /// scroll-back stays instant and network-free. Once the cache is exhausted the
  /// **stored server cursor** takes over: the cache running out is not evidence
  /// that the thread has no more history, only that we never cached it. Falling
  /// back to it means an offline scroll-back that walks off the end of the cache
  /// resumes from the server the moment connectivity returns, instead of the UI
  /// claiming "beginning of the conversation" over history that plainly exists.
  ///
  /// Null — a genuine stop — is returned only when the cache is exhausted *and*
  /// the last online first-page fetch reported no further page.
  Future<String?> _localCursorIfMore(
    String conversationId,
    BigInt oldestServed,
  ) async {
    final oldest = await _local!.oldestCachedSeq(conversationId);
    if (oldest != null && oldest < oldestServed) {
      return '$_localCursor$oldestServed';
    }
    final meta = await _local.readThreadMeta(conversationId);
    return meta?.nextCursor;
  }

  @override
  Future<ChatReadReceipt> markMessagesRead({
    required String conversationId,
    required BigInt upToSeq,
  }) =>
      _readThrough(
        remote: () => _remote.markRead(
          conversationId: conversationId,
          upToSeq: upToSeq,
        ),
        // The server has confirmed the read, so the cached badge must follow it.
        // Otherwise a thread read offline and reopened offline would still show
        // its pre-read count until the next successful list fetch. Best-effort,
        // like every cache write; the next list read is authoritative anyway.
        persist: (_) => _local?.clearCachedUnread(conversationId) ??
            Future<void>.value(),
      );

  @override
  Future<void> deleteMessageForMe({
    required String conversationId,
    required String messageId,
  }) =>
      _readThrough(
        remote: () => _remote.deleteForMe(
          conversationId: conversationId,
          messageId: messageId,
        ),
        persist: (_) => _local?.deleteMessage(messageId) ?? Future.value(),
      );

  @override
  Future<ChatMessage> deleteMessageForEveryone({
    required String conversationId,
    required String messageId,
  }) =>
      _readThrough(
        remote: () => _remote.deleteForEveryone(
          conversationId: conversationId,
          messageId: messageId,
        ),
        persist: (tombstone) =>
            _local?.upsertMessages(conversationId, [tombstone]) ?? Future.value(),
      );

  @override
  Future<ChatAttachmentDownload> getAttachmentDownloadUrl({
    required String conversationId,
    required String messageId,
  }) async {
    final key = '$conversationId:$messageId';
    final cached = _attachmentDownloads[key];
    if (cached != null && !cached.isExpired) return cached;

    // Multiple bubbles can ask for the same URL in the same frame (for
    // example an inline image and a viewer transition). Coalesce that work as
    // well as caching its completed result.
    final inFlight = _attachmentDownloadRequests[key];
    if (inFlight != null) return inFlight;

    final request = _guard(() => _remote.getAttachmentDownloadUrl(
          conversationId: conversationId,
          messageId: messageId,
        ));
    _attachmentDownloadRequests[key] = request;
    try {
      final download = await request;
      _attachmentDownloads[key] = download;
      return download;
    } finally {
      if (identical(_attachmentDownloadRequests[key], request)) {
        _attachmentDownloadRequests.remove(key);
      }
    }
  }
}
