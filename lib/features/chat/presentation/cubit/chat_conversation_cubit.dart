import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/enums/chat_attachment_kind.dart';
import 'package:drop/core/enums/chat_message_type.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/core/utils/app_logger.dart';
import 'package:drop/core/utils/concurrent.dart';
import 'package:drop/core/utils/uuid.dart';
import 'package:drop/features/chat/domain/chat_realtime.dart';
import 'package:drop/features/chat/domain/entities/chat_conversation.dart';
import 'package:drop/features/chat/domain/entities/chat_message.dart';
import 'package:drop/features/chat/domain/entities/chat_outgoing_attachment.dart';
import 'package:drop/features/chat/presentation/chat_thread_cache.dart';
import 'package:drop/features/chat/domain/usecases/delete_chat_message_for_everyone.dart';
import 'package:drop/features/chat/domain/usecases/delete_chat_message_for_me.dart';
import 'package:drop/features/chat/domain/usecases/get_chat_attachment_url.dart';
import 'package:drop/features/chat/domain/usecases/get_conversation.dart';
import 'package:drop/features/chat/domain/usecases/load_chat_history.dart';
import 'package:drop/features/chat/domain/usecases/mark_chat_read.dart';
import 'package:drop/features/chat/domain/usecases/send_chat_message.dart';
import 'chat_conversation_state.dart';

/// Drives ONE open chat thread — created per opened conversation (mirroring
/// [CaseConversationCubit]'s lifecycle) and REST-only for now: new incoming
/// messages arrive with the socket phase, which will feed this same cubit.
///
/// **Send idempotency (backend-aligned):** every logical send mints one UUID
/// `idempotencyKey`. If the send fails and the user retries the *same* text,
/// the key is **reused**, so a send whose response was lost in transit can
/// never duplicate the message server-side — this is the exact retry contract
/// the backend's dedupe was built for. No fake optimistic bubble is shown: the
/// authoritative message (with its server-assigned `seq`) comes back in the
/// send response and is appended then. Pending/failed bubble states belong to
/// the realtime phase, where reconciliation makes them worth their complexity.
///
/// **Identity note:** the API exposes no "who am I" endpoint, so the caller's
/// backend-internal id is *derived* — from [counterpartUserId] (known when
/// opened from the list) or from the first sent message's `senderId`. On a
/// deep link into a never-messaged thread it stays null until one of those
/// resolves; a `GET /users/me` endpoint would remove this dance entirely.
///
/// **Realtime (optional [ChatRealtime]):** REST stays the source of truth and
/// the only write path; the socket just delivers facts early. The cubit joins
/// its conversation's room for its lifetime, applies live `message:new`
/// (insert in `seq` order, deduped — the server never echoes the caller's own
/// sends) and `message:read` (upgrade the listed messages to READ), and on a
/// **reconnect** reconciles by re-fetching the newest history page and merging
/// it — the backend's documented recovery contract (delivery is best-effort;
/// clients catch up over REST). Realtime failures are silent: without a socket
/// the thread simply behaves like the REST-only build.
class ChatConversationCubit extends Cubit<ChatConversationState> {
  final GetConversation _getConversation;
  final LoadChatHistory _loadHistory;
  final SendChatMessage _sendMessage;
  final MarkChatRead _markRead;
  final DeleteChatMessageForMe _deleteForMe;
  final DeleteChatMessageForEveryone _deleteForEveryone;
  final GetChatAttachmentUrl? _getAttachmentUrl;
  final ChatRealtime? _realtime;
  StreamSubscription<ChatRealtimeEvent>? _realtimeSub;

  final String conversationId;

  /// The other participant's backend-internal id, when the opener knows it
  /// (list rows carry it); enables own-message alignment before the first send.
  final String? counterpartUserId;

  ChatConversation? _conversation;
  List<ChatMessage> _messages = const [];
  String? _nextCursor;
  String? _myUserId;
  bool _loading = false;
  // Optimistic sends never block the composer, so the loaded state's `sending`
  // flag stays false — the in-flight state now lives on the message bubble.
  bool _loadingOlder = false;
  bool _clearing = false;
  String? _deletingMessageId;
  BigInt? _lastMarkedSeq;
  final ChatThreadCache? _cache;

  /// Prefix marking an optimistic (not-yet-confirmed) local message. The id is
  /// `local:<idempotencyKey>`, so a retry recovers the same key from the id and
  /// the server's dedupe guarantees no duplicate on a lost-response retry.
  static const _localIdPrefix = 'local:';
  static const _statusSending = 'SENDING';
  static const _statusFailed = 'FAILED';

  ChatConversationCubit({
    required this._getConversation,
    required this._loadHistory,
    required this._sendMessage,
    required this._markRead,
    required this._deleteForMe,
    required this._deleteForEveryone,
    required this.conversationId,
    this.counterpartUserId,
    this._realtime,
    this._cache,
    this._getAttachmentUrl,
  })  : super(const ChatConversationState.loading()) {
    // Instant re-open: paint the last-known confirmed messages synchronously
    // from the cache, then refresh from REST in the background (load()).
    final cached = _cache?.get(conversationId);
    if (cached != null) {
      _conversation = cached.conversation;
      _messages = cached.messages;
      _nextCursor = cached.nextCursor;
      _myUserId = cached.myUserId ?? _myUserId;
      _emit();
    } else if (_cache != null) {
      // Cold open (no hot snapshot): rebuild instantly from the durable cache
      // (Drift) while the network load runs in parallel. Guarded so a network
      // win is never overwritten by slower disk data.
      unawaited(_restoreFromCache());
    }
    final rt = _realtime;
    if (rt != null) {
      _realtimeSub = rt.events.listen(_onRealtimeEvent);
      // Fire-and-forget: a refused/failed join leaves the thread REST-only
      // (and the service keeps retrying the connection underneath).
      rt.joinConversation(conversationId);
    }
    load();
  }

  bool _isLocal(ChatMessage m) => m.id.startsWith(_localIdPrefix);

  @override
  Future<void> close() async {
    await _realtimeSub?.cancel();
    await _realtime?.leaveConversation(conversationId);
    return super.close();
  }

  void _emit() {
    if (isClosed) return;
    final conversation = _conversation;
    if (conversation == null) return;
    emit(ChatConversationState.loaded(
      conversation,
      List.of(_messages),
      myUserId: _myUserId,
      sending: false,
      loadingOlder: _loadingOlder,
      hasMore: _nextCursor != null,
      deletingMessageId: _deletingMessageId,
    ));
    // Cache only server-confirmed messages, so a re-opened thread never shows a
    // stuck "sending"/"failed" bubble left over from a torn-down session.
    _cache?.put(
      conversationId,
      ChatThreadSnapshot(
        conversation: conversation,
        messages: _messages.where((m) => !_isLocal(m)).toList(growable: false),
        nextCursor: _nextCursor,
        myUserId: _myUserId,
      ),
    );
  }

  /// Derives the caller's internal id once the conversation and counterpart
  /// are both known: my id is the participant that isn't the counterpart.
  void _deriveMyUserId() {
    if (_myUserId != null) return;
    final counterpart = counterpartUserId;
    final conversation = _conversation;
    if (counterpart == null || conversation == null) return;
    for (final id in conversation.participantIds) {
      if (id != counterpart) {
        _myUserId = id;
        return;
      }
    }
  }

  /// Initial load (also the full-screen retry): conversation + newest history
  /// page in parallel. Loading history does NOT mark anything read — that's
  /// [markVisibleRead], fired by the UI when messages are actually on screen.
  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    if (_conversation == null) emit(const ChatConversationState.loading());
    try {
      final results = await Future.wait<dynamic>([
        _getConversation(conversationId),
        _loadHistory(conversationId: conversationId),
      ]);
      _conversation = results[0] as ChatConversation;
      final page = results[1] as ChatMessagePage;
      // Keep any optimistic/failed local bubbles the network page doesn't carry
      // (a cold-restored outbox bubble, or an in-flight send) so the refresh
      // never drops them.
      final locals = _messages.where(_isLocal).toList();
      _messages = [...page.items, ...locals];
      _nextCursor = page.nextCursor;
      _deriveMyUserId();
      _emit();
      unawaited(_adoptOutbox());
    } on Failure catch (e) {
      emit(ChatConversationState.error(e.message));
      _emit(); // transient when the thread is already on screen
      unawaited(_adoptOutbox());
    } catch (e) {
      AppLog.warning('chat', 'conversation load failed: $e');
      emit(const ChatConversationState.error(
          'Failed to load the conversation. Please try again.'));
      _emit();
    } finally {
      _loading = false;
    }
  }

  /// Cold-start instant open: paints the last-known **confirmed** thread from
  /// the durable cache (Drift) if the network [load] hasn't already resolved.
  /// Guarded on [_conversation] so a network win is never clobbered.
  Future<void> _restoreFromCache() async {
    final cache = _cache;
    if (cache == null) return;
    final snapshot = await cache.restore(conversationId);
    if (isClosed || snapshot == null || _conversation != null) return;
    _conversation = snapshot.conversation;
    _messages = snapshot.messages;
    _nextCursor = snapshot.nextCursor;
    _myUserId = snapshot.myUserId ?? _myUserId;
    _deriveMyUserId();
    _emit();
  }

  /// Adopts the durable outbox (text sends never acknowledged before the app
  /// was last closed) as `FAILED` bubbles, then retries them now that the load
  /// has settled. Deduped by id, so re-running is a no-op. No-op without a
  /// durable cache.
  Future<void> _adoptOutbox() async {
    final cache = _cache;
    if (cache == null || isClosed) return;
    var maxSeq = BigInt.zero;
    for (final m in _messages) {
      if (m.seq > maxSeq) maxSeq = m.seq;
    }
    final pending =
        await cache.restorePending(conversationId, afterSeq: maxSeq);
    if (isClosed || pending.isEmpty) return;
    final known = {for (final m in _messages) m.id};
    final toAdd =
        pending.where((m) => !known.contains(m.id)).toList(growable: false);
    if (toAdd.isNotEmpty) {
      _messages = [..._messages, ...toAdd];
      _emit();
    }
    _retryFailedSends();
  }

  /// Re-dispatches every failed optimistic send (reusing its idempotency key,
  /// so the backend dedupes). Fired after a good load and on reconnect.
  void _retryFailedSends() {
    for (final m in List.of(_messages)) {
      if (_isLocal(m) && m.status == _statusFailed) {
        unawaited(retrySend(m.id));
      }
    }
  }

  /// Loads the next **older** page and prepends it (scroll-back). No-op while
  /// one is in flight or when the full history has been loaded.
  Future<void> loadOlder() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingOlder || _conversation == null) return;

    _loadingOlder = true;
    _emit();
    try {
      final page = await _loadHistory(
        conversationId: conversationId,
        cursor: cursor,
      );
      final known = {for (final m in _messages) m.id};
      _messages = [
        ...page.items.where((m) => !known.contains(m.id)),
        ..._messages,
      ];
      _nextCursor = page.nextCursor;
    } on Failure catch (e) {
      emit(ChatConversationState.error(e.message));
    } catch (e) {
      AppLog.warning('chat', 'history page failed: $e');
      emit(const ChatConversationState.error('Failed to load older messages.'));
    } finally {
      _loadingOlder = false;
      _emit();
    }
  }

  /// Optimistic send (spec §7): the message appears **immediately** as a local
  /// `SENDING` bubble and the composer clears at once — the UI never blocks on
  /// the network. The POST runs in the background and resolves the bubble:
  /// success replaces it with the server's authoritative message (real `seq`),
  /// failure marks it `FAILED` for [retrySend]. Returns true as soon as the
  /// local bubble is inserted (the composer keys its clear off this).
  ///
  /// Supports text, an [attachment], or both. The idempotency key is minted
  /// once and encoded in the local id, so a retry reuses it and the backend's
  /// dedupe guarantees a lost-response retry never duplicates the message.
  Future<bool> sendMessage(
    String text, {
    String? replyToMessageId,
    ChatOutgoingAttachment? attachment,
  }) async {
    final trimmed = text.trim();
    if ((trimmed.isEmpty && attachment == null) || _conversation == null) {
      return false;
    }

    final idempotencyKey = UuidV4.generate();
    final local = _buildLocalMessage(
      idempotencyKey: idempotencyKey,
      content: trimmed,
      replyToMessageId: replyToMessageId,
      attachment: attachment,
    );
    _messages = [..._messages, local];
    _emit();

    unawaited(_dispatchSend(
      localId: local.id,
      idempotencyKey: idempotencyKey,
      content: trimmed.isEmpty ? null : trimmed,
      replyToMessageId: replyToMessageId,
      attachment: attachment,
    ));
    return true;
  }

  /// Re-sends a previously failed local message, reusing its idempotency key
  /// (recovered from the local id) so the retry is dedupe-safe.
  Future<void> retrySend(String localMessageId) async {
    final index = _messages.indexWhere((m) => m.id == localMessageId);
    if (index < 0) return;
    final failed = _messages[index];
    if (failed.status != _statusFailed) return;

    final hasAttachment = _pendingAttachments.containsKey(localMessageId);
    _messages = [..._messages]..[index] = failed
        .withStatus(_statusSending)
        .withUploadProgress(hasAttachment ? 0.0 : null);
    _emit();
    unawaited(_dispatchSend(
      localId: localMessageId,
      idempotencyKey: localMessageId.substring(_localIdPrefix.length),
      content: (failed.body ?? '').isEmpty ? null : failed.body,
      replyToMessageId: failed.replyTo?.id,
      attachment: _pendingAttachments[localMessageId],
    ));
  }

  /// Resolves a short-lived download URL for a received attachment (the
  /// full-screen image viewer fetches its bytes from it). Returns null when no
  /// resolver is wired or the broker call fails — the viewer then shows an
  /// unavailable state rather than throwing.
  Future<String?> attachmentDownloadUrl(String messageId) async {
    final resolver = _getAttachmentUrl;
    if (resolver == null) return null;
    try {
      final download = await resolver(
        conversationId: conversationId,
        messageId: messageId,
      );
      return download.url;
    } catch (e) {
      AppLog.warning('chat', 'attachment url failed: $e');
      return null;
    }
  }

  /// Raw bytes for optimistic attachment sends, kept off the message model so a
  /// retry can re-upload without re-picking. Cleared once the send resolves.
  final Map<String, ChatOutgoingAttachment> _pendingAttachments = {};

  Future<void> _dispatchSend({
    required String localId,
    required String idempotencyKey,
    String? content,
    String? replyToMessageId,
    ChatOutgoingAttachment? attachment,
  }) async {
    if (attachment != null) _pendingAttachments[localId] = attachment;
    try {
      final sent = await _sendMessage(
        conversationId: conversationId,
        idempotencyKey: idempotencyKey,
        content: content,
        replyToMessageId: replyToMessageId,
        attachment: attachment,
        onSendProgress: attachment == null
            ? null
            : (sent, total) {
                if (total > 0) _updateUploadProgress(localId, sent / total);
              },
      );
      if (isClosed) return;
      _pendingAttachments.remove(localId);
      _myUserId ??= sent.senderId; // authoritative "me" from my own send
      _replaceLocal(localId, sent);
      _emit();
    } on Failure catch (e) {
      AppLog.warning('chat', 'send failed: ${e.message}');
      if (isClosed) return;
      _markLocalFailed(localId);
      _emit();
    } catch (e) {
      AppLog.warning('chat', 'send failed: $e');
      if (isClosed) return;
      _markLocalFailed(localId);
      _emit();
    }
  }

  /// Builds the optimistic local message. Its `seq` sits just past the newest
  /// so it renders at the bottom; on confirmation it is replaced by the server
  /// message carrying the real `seq`.
  ChatMessage _buildLocalMessage({
    required String idempotencyKey,
    required String content,
    String? replyToMessageId,
    ChatOutgoingAttachment? attachment,
  }) {
    var maxSeq = BigInt.zero;
    for (final m in _messages) {
      if (m.seq > maxSeq) maxSeq = m.seq;
    }
    ChatReplyPreview? replyPreview;
    if (replyToMessageId != null) {
      for (final m in _messages) {
        if (m.id == replyToMessageId) {
          replyPreview = ChatReplyPreview(
            id: m.id,
            senderId: m.senderId,
            type: m.type,
            body: m.body,
            attachment: m.attachment,
          );
          break;
        }
      }
    }
    final localAttachment = attachment == null
        ? null
        : ChatMessageAttachment(
            id: '$_localIdPrefix$idempotencyKey',
            kind: attachment.kind,
            format: attachment.format.value,
            mimeType: attachment.mimeType,
            originalFilename: attachment.originalFilename,
            byteSize: attachment.bytes.length,
          );
    return ChatMessage(
      id: '$_localIdPrefix$idempotencyKey',
      conversationId: conversationId,
      senderId: _myUserId ?? '',
      type: attachment == null
          ? ChatMessageType.text
          : (attachment.kind == ChatAttachmentKind.image
              ? ChatMessageType.image
              : ChatMessageType.document),
      body: content.isEmpty ? null : content,
      attachment: localAttachment,
      replyTo: replyPreview,
      seq: maxSeq + BigInt.one,
      status: _statusSending,
      createdAt: DateTime.now(),
      localBytes: attachment?.kind == ChatAttachmentKind.image
          ? attachment?.bytes
          : null,
      // Attachment sends start at 0% so the progress ring shows immediately;
      // text sends have no meaningful transfer progress.
      uploadProgress: attachment == null ? null : 0.0,
    );
  }

  /// Swaps a confirmed optimistic send for its authoritative server message.
  ///
  /// The placeholder's slot is **never** reused: its provisional `seq`
  /// (`maxSeq + 1` at send time) need not match the order the server actually
  /// assigned once rapid/concurrent sends or an interleaved realtime message are
  /// in play, so reusing the slot could leave the thread out of `seq` order.
  /// Instead the placeholder is removed and [_insertBySeq] re-inserts the
  /// message at its true `seq`, preserving the list's sorted-by-`seq` invariant.
  /// [_insertBySeq] also dedupes: if a realtime echo already delivered this id,
  /// it updates that copy in place rather than inserting a duplicate.
  void _replaceLocal(String localId, ChatMessage sent) {
    final localIndex = _messages.indexWhere((m) => m.id == localId);
    if (localIndex >= 0) {
      _messages = [..._messages]..removeAt(localIndex);
    }
    _insertBySeq(sent);
  }

  void _markLocalFailed(String localId) {
    final index = _messages.indexWhere((m) => m.id == localId);
    if (index < 0) return;
    _messages = [..._messages]..[index] =
        _messages[index].withStatus(_statusFailed).withUploadProgress(null);
  }

  /// Updates an in-flight attachment's progress ring, throttled to whole-percent
  /// changes so the transfer callback (which fires per chunk) can't trigger a
  /// rebuild storm. Always emits the final 100%.
  void _updateUploadProgress(String localId, double fraction) {
    if (isClosed) return;
    final index = _messages.indexWhere((m) => m.id == localId);
    if (index < 0) return;
    final clamped = fraction.clamp(0.0, 1.0);
    final current = _messages[index].uploadProgress ?? 0;
    if (clamped < 1.0 && (clamped * 100).floor() == (current * 100).floor()) {
      return;
    }
    _messages = [..._messages]..[index] =
        _messages[index].withUploadProgress(clamped);
    _emit();
  }

  // ─── Message deletion (REST — the socket only echoes the fact) ────────

  /// Hides [messageId] from this user's view only (the counterpart is
  /// unaffected — strictly one-sided, backend INV-19). Returns whether it
  /// succeeded; failures surface through the transient-error convention.
  /// One delete in flight at a time.
  Future<bool> deleteMessageForMe(String messageId) async {
    if (_deletingMessageId != null || _conversation == null) return false;
    _deletingMessageId = messageId;
    _emit();
    try {
      await _deleteForMe(
          conversationId: conversationId, messageId: messageId);
      _messages = [..._messages]..removeWhere((m) => m.id == messageId);
      return true;
    } on Failure catch (e) {
      emit(ChatConversationState.error(e.message));
      return false;
    } catch (e) {
      AppLog.warning('chat', 'delete for me failed: $e');
      emit(const ChatConversationState.error(
          'Failed to delete the message.'));
      return false;
    } finally {
      _deletingMessageId = null;
      _emit();
    }
  }

  /// Deletes [messageId] for **both** participants. The server enforces every
  /// rule — original sender only, within its time window — and refuses with a
  /// clear 403 message otherwise; the client never pre-computes permission.
  /// On success the server's tombstone (placeholder body) replaces the
  /// message in place. Idempotent server-side.
  Future<bool> deleteMessageForEveryone(String messageId) async {
    if (_deletingMessageId != null || _conversation == null) return false;
    _deletingMessageId = messageId;
    _emit();
    try {
      final tombstone = await _deleteForEveryone(
          conversationId: conversationId, messageId: messageId);
      _insertBySeq(tombstone);
      return true;
    } on Failure catch (e) {
      emit(ChatConversationState.error(e.message));
      return false;
    } catch (e) {
      AppLog.warning('chat', 'delete for everyone failed: $e');
      emit(const ChatConversationState.error(
          'Failed to delete the message.'));
      return false;
    } finally {
      _deletingMessageId = null;
      _emit();
    }
  }

  /// Clears the conversation **for me only** — a bulk delete-for-me over every
  /// loaded, server-confirmed message (the counterpart keeps their copy). Uses
  /// the existing per-message delete API (no new backend), pooled so a long
  /// thread doesn't fan out a request per message at once. Optimistic local
  /// bubbles (unsent) are left in place. Returns whether it succeeded.
  Future<bool> clearChatForMe() async {
    if (_conversation == null || _clearing) return false;
    final ids = _messages
        .where((m) => !_isLocal(m))
        .map((m) => m.id)
        .toList(growable: false);
    if (ids.isEmpty) return true;
    _clearing = true;
    _deletingMessageId = null;
    _emit();
    try {
      await mapPooled(3, [
        for (final id in ids)
          () => _deleteForMe(conversationId: conversationId, messageId: id),
      ]);
      _messages = _messages.where(_isLocal).toList();
      return true;
    } on Failure catch (e) {
      emit(ChatConversationState.error(e.message));
      return false;
    } catch (e) {
      AppLog.warning('chat', 'clear chat failed: $e');
      emit(const ChatConversationState.error(
          'Failed to clear the conversation.'));
      return false;
    } finally {
      _clearing = false;
      _emit();
    }
  }

  /// Shared-media / document counts over the loaded window — for the
  /// Conversation Info screen. Derived, presentation-only (no backend count
  /// endpoint); reflects what's currently loaded, which is the visible history.
  ({int media, int documents}) get sharedAttachmentCounts {
    var media = 0;
    var documents = 0;
    for (final m in _messages) {
      final a = m.attachment;
      if (a == null || m.deletedForEveryone) continue;
      if (a.kind.isImage) {
        media++;
      } else {
        documents++;
      }
    }
    return (media: media, documents: documents);
  }

  // ─── Realtime (socket) ────────────────────────────────────────────────

  void _onRealtimeEvent(ChatRealtimeEvent event) {
    if (isClosed) return;
    switch (event) {
      case ChatRealtimeConnected(:final isReconnect):
        // The connection was down for a while — messages sent in the gap were
        // never pushed. Rooms are already re-joined by the service; catch up
        // through REST, the source of truth, and flush any pending sends the
        // outage stranded.
        if (isReconnect) {
          _reconcile();
          _retryFailedSends();
        }
      case ChatMessageReceived(:final message):
        if (message.conversationId != conversationId) return;
        if (_conversation == null) return; // initial load will fetch it
        _insertBySeq(message);
        _emit();
      case ChatMessagesReadReceived e:
        if (e.conversationId != conversationId) return;
        _applyReadReceipt(e);
      case ChatMessageDeletedReceived e:
        // Deleted for everyone (by either side) — re-render the placeholder.
        if (e.conversationId != conversationId) return;
        final index = _messages.indexWhere((m) => m.id == e.messageId);
        if (index < 0 || _messages[index].deletedForEveryone) return;
        _messages = [..._messages]
          ..[index] = _messages[index].asDeletedForEveryone();
        _emit();
      case ChatMessageHiddenReceived e:
        // This user hid the message on another of their own sessions —
        // mirror it here (strictly one-sided; nothing reaches the other side).
        if (e.conversationId != conversationId) return;
        final before = _messages.length;
        _messages = [..._messages]..removeWhere((m) => m.id == e.messageId);
        if (_messages.length != before) _emit();
      case ChatRealtimeDisconnected():
        // No UI — reconnect + reconcile are automatic.
        break;
    }
  }

  /// Inserts a live message at its `seq` position (dedup by id — an id already
  /// present is replaced, keeping the newer server view). Almost always a
  /// plain append; the ordered path covers late deliveries after a reconcile.
  void _insertBySeq(ChatMessage message) {
    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index >= 0) {
      _messages = [..._messages]..[index] = message;
      return;
    }
    if (_messages.isEmpty || message.seq > _messages.last.seq) {
      _messages = [..._messages, message];
      return;
    }
    final at = _messages.indexWhere((m) => m.seq > message.seq);
    _messages = [..._messages]..insert(at < 0 ? _messages.length : at, message);
  }

  /// The counterpart read a batch of my messages — upgrade their status. The
  /// server excludes the reader's own sockets, so no self-check is needed;
  /// ids not currently loaded are simply skipped (history re-fetch would show
  /// the same truth).
  void _applyReadReceipt(ChatMessagesReadReceived receipt) {
    final ids = receipt.messageIds.toSet();
    var changed = false;
    final updated = <ChatMessage>[];
    for (final m in _messages) {
      if (ids.contains(m.id) && m.status != 'READ') {
        updated.add(m.withStatus('READ'));
        changed = true;
      } else {
        updated.add(m);
      }
    }
    if (!changed) return;
    _messages = updated;
    _emit();
  }

  /// Post-reconnect catch-up: re-fetch the newest history page and merge it —
  /// new ids are inserted in `seq` order, known ids take the server's view.
  /// A gap larger than one page is left for scroll-back to fill (the loaded
  /// window stays contiguous at its newest edge, which is what the thread
  /// shows). Failures are silent: the next reconnect or manual refresh
  /// reconciles, and stale-but-consistent beats an error banner mid-thread.
  Future<void> _reconcile() async {
    if (_conversation == null) return; // first load hasn't succeeded yet
    try {
      final page = await _loadHistory(conversationId: conversationId);
      for (final message in page.items) {
        _insertBySeq(message);
      }
      if (_messages.isEmpty) _nextCursor = page.nextCursor;
      _emit();
    } on Failure catch (e) {
      AppLog.warning('chat', 'reconnect reconcile failed: ${e.message}');
    } catch (e) {
      AppLog.warning('chat', 'reconnect reconcile failed: $e');
    }
  }

  /// Marks the thread read up to the newest loaded message — call when the
  /// messages are actually **visible** (the backend treats mark-read as the
  /// opened-and-visible signal, not a fetch side effect). Monotonic and
  /// fire-and-forget: failures are logged, never surfaced — a missed read
  /// receipt isn't worth an error banner.
  Future<void> markVisibleRead() async {
    // Read up to the newest *server-confirmed* message — an optimistic bubble's
    // placeholder `seq` must never be sent as a real read cursor.
    BigInt? upToSeq;
    for (var i = _messages.length - 1; i >= 0; i--) {
      if (!_isLocal(_messages[i])) {
        upToSeq = _messages[i].seq;
        break;
      }
    }
    if (upToSeq == null) return;
    final already = _lastMarkedSeq;
    if (already != null && upToSeq <= already) return;

    _lastMarkedSeq = upToSeq; // set first so concurrent calls no-op
    try {
      await _markRead(conversationId: conversationId, upToSeq: upToSeq);
    } on Failure catch (e) {
      if (_lastMarkedSeq == upToSeq) _lastMarkedSeq = already;
      AppLog.warning('chat', 'mark-read failed: ${e.message}');
    } catch (e) {
      if (_lastMarkedSeq == upToSeq) _lastMarkedSeq = already;
      AppLog.warning('chat', 'mark-read failed: $e');
    }
  }
}
