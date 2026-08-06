import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/core/utils/app_logger.dart';
import 'package:drop/features/chat/domain/chat_realtime.dart';
import 'package:drop/features/chat/domain/entities/chat_conversation.dart';
import 'package:drop/features/chat/domain/entities/chat_message.dart';
import 'package:drop/features/chat/domain/usecases/get_cached_conversations.dart';
import 'package:drop/features/chat/domain/usecases/get_conversations.dart';
import 'package:drop/features/chat/domain/usecases/start_conversation.dart';
import 'package:drop/features/chat/presentation/chat_format.dart';
import 'chat_list_state.dart';

/// Drives the chat inbox (conversation list) — REST + cursor pagination,
/// enriched live by the shared socket. Singleton, app-wide, mirroring
/// [CaseListCubit]'s role for Cases; the open thread lives in its own
/// per-conversation cubit.
///
/// The server orders by most-recent-activity and owns the pagination cursor;
/// this cubit never re-sorts on its own — it accumulates pages and dedupes by
/// id, with one exception: a live `message:new` moves its conversation to the
/// top, exactly the move the server has already made in its own ordering.
///
/// **Realtime (optional [ChatRealtime]):** the shared socket's personal
/// `user:{id}` room delivers `message:new` for every conversation with no
/// room join, so the first [load] declares inbox interest
/// ([ChatRealtime.attachInbox]) and the cubit then keeps the inbox live —
/// reorder + activity bump, a client-held last-message preview, and a
/// client-counted unread badge (the backend pushes no counts; opening a
/// conversation clears its badge via [clearUnread]). Events are deduped by
/// per-conversation `seq`, an unknown conversation falls back to a full
/// refresh (server truth — the client never invents a row), and a reconnect
/// refreshes the first page, which by design resets pagination.
class ChatListCubit extends Cubit<ChatListState> {
  final GetConversations _getConversations;
  final StartConversation _startConversation;
  final GetCachedConversations? _getCachedConversations;
  final ChatRealtime? _realtime;
  StreamSubscription<ChatRealtimeEvent>? _realtimeSub;
  bool _inboxAttached = false;

  List<ChatConversationSummary> _conversations = const [];
  String? _nextCursor;
  bool _hasLoaded = false;
  bool _loading = false;
  bool _refreshing = false;
  bool _loadingMore = false;
  bool _starting = false;

  // Live socket-derived enrichment, keyed by conversation id (see the state
  // docs). _previewMessageIds remembers WHICH message a preview shows so a
  // live delete-for-everyone can tombstone it; _lastSeenSeq dedupes event
  // replays and drops out-of-order stragglers.
  final Map<String, String> _previews = {};
  final Map<String, String> _previewMessageIds = {};
  final Map<String, BigInt> _lastSeenSeq = {};
  final Map<String, int> _unread = {};

  /// Broadcasts a distinct "a new message just arrived" event for each genuinely
  /// new (deduped) live message — the app-wide in-app notification listener
  /// subscribes to this to raise a snackbar/banner when the user isn't already
  /// viewing that conversation. Purely additive: the inbox rendering path is
  /// unchanged whether or not anything listens.
  final StreamController<ChatIncomingMessage> _incomingController =
      StreamController<ChatIncomingMessage>.broadcast();
  Stream<ChatIncomingMessage> get incoming => _incomingController.stream;

  /// Total unread across every conversation — powers the sidebar/nav badge and
  /// the dashboard widget. Reactive: emitted state changes (a live message, an
  /// opened conversation) rebuild any [BlocBuilder] reading it.
  int get totalUnread =>
      _unread.values.fold(0, (sum, count) => sum + count);

  ChatListCubit({
    required this._getConversations,
    required this._startConversation,
    this._getCachedConversations,
    this._realtime,
  }) : super(const ChatListState.initial()) {
    _realtimeSub = _realtime?.events.listen(_onRealtimeEvent);
  }

  @override
  Future<void> close() async {
    await _realtimeSub?.cancel();
    await _incomingController.close();
    if (_inboxAttached) await _realtime?.detachInbox();
    return super.close();
  }

  void _emitLoaded() {
    if (isClosed) return;
    emit(ChatListState.loaded(
      List.of(_conversations),
      refreshing: _refreshing,
      loadingMore: _loadingMore,
      hasMore: _nextCursor != null,
      starting: _starting,
      previews: Map.of(_previews),
      unreadCounts: Map.of(_unread),
    ));
  }

  /// Loads the first page. Idempotent once loaded — call with [forceRefresh]
  /// (or via [refresh]) to re-pull. A refresh keeps the current list visible
  /// ([ChatListState.loaded.refreshing]) instead of dropping to a spinner, and
  /// resets pagination to page one (the server's ordering may have changed).
  Future<void> load({bool forceRefresh = false}) async {
    if (_loading) return;
    final inError = state.maybeMap(error: (_) => true, orElse: () => false);
    if (_hasLoaded && !forceRefresh && !inError) return;

    // First load = the inbox is on screen — declare inbox interest so the
    // shared socket stays alive and `user:{id}`-room events flow. Singleton
    // cubit: interest persists for the app's life (withdrawn only on close).
    final rt = _realtime;
    if (rt != null && !_inboxAttached) {
      _inboxAttached = true;
      rt.attachInbox(); // fire-and-forget; failure just means REST-only
    }

    _loading = true;
    if (_hasLoaded && _conversations.isNotEmpty) {
      _refreshing = true;
      _emitLoaded();
    } else if (await _paintFromCache()) {
      // Cold start: the durable cache held conversations — paint them instantly
      // (no spinner) and mark refreshing while the server load runs below.
      _refreshing = true;
      _emitLoaded();
    } else {
      // Nothing cached (or no cache wired) — the usual first-load spinner.
      emit(const ChatListState.loading());
    }

    try {
      final page = await _getConversations();
      _conversations = page.items;
      _nextCursor = page.nextCursor;
      // Seed the unread badges from the server's authoritative counts so they
      // are correct after a cold start / account switch — the live socket only
      // ever *increments* from here, and opening a conversation clears it.
      _seedUnread(page.items, replace: true);
      _hasLoaded = true;
      _refreshing = false;
      _emitLoaded();
    } on Failure catch (e, st) {
      // Log the real failure (type + message) rather than only flipping to the
      // error state — otherwise a loading→error loop hides its own cause. The
      // network layer additionally logs the underlying transport error.
      AppLog.error('chat', 'conversation list load failed', e, st);
      _refreshing = false;
      emit(ChatListState.error(e.message));
      // Transient when we still have a list to show (Cases convention).
      if (_hasLoaded) _emitLoaded();
    } catch (e, st) {
      AppLog.error('chat', 'conversation list load failed (unexpected)', e, st);
      _refreshing = false;
      emit(const ChatListState.error(
          'Failed to load conversations. Please try again.'));
      if (_hasLoaded) _emitLoaded();
    } finally {
      _loading = false;
    }
  }

  Future<void> refresh() => load(forceRefresh: true);

  /// Forwards an app-foreground signal to the shared socket so it reconnects
  /// after an OS suspension — without it the inbox's realtime stays dead until
  /// something else happens to reconnect (nothing does, when no thread is open),
  /// so messages arrive only on a manual refresh. A live connection is left
  /// untouched; a reconnect refreshes the inbox via `ChatRealtimeConnected`.
  /// No-op when realtime isn't wired.
  void onAppResumed() => unawaited(_realtime?.onAppResumed() ?? Future.value());

  /// Drops all in-memory inbox state back to first-run, for account switching
  /// on a shared device. This cubit is an app-wide singleton that outlives a
  /// sign-out, so without this the next user would briefly see the previous
  /// user's conversations (and `load()` would even early-return on the stale
  /// `_hasLoaded`, never refreshing). Called from the pre-sign-out hook
  /// alongside the durable cache wipe so the next session always lands on the
  /// signed-in user's own data.
  void reset() {
    _conversations = const [];
    _nextCursor = null;
    _hasLoaded = false;
    _loading = false;
    _refreshing = false;
    _loadingMore = false;
    _starting = false;
    _previews.clear();
    _resolvedPreviews.clear();
    _resolvedEmpty.clear();
    _previewMessageIds.clear();
    _lastSeenSeq.clear();
    _unread.clear();
    // Must be dropped with the rest: a rollback record left over from the
    // previous account could otherwise restore that account's unread count into
    // the next session's inbox when its in-flight mark-read finally fails.
    _optimisticallyCleared.clear();
    if (!isClosed) emit(const ChatListState.initial());
  }

  // ── Resolved last-message previews ────────────────────────────────
  //
  // The list endpoint returns `lastMessageAt` but not the message itself, so
  // the inbox resolves one preview per row (see `ChatScreen._resolvePreviews`).
  // That memo used to live on the *screen's* State, which meant it died on
  // every navigation — walking into a conversation and back re-fetched every
  // row. It lives here instead: this cubit is an app-wide singleton, so the
  // work is done once per session, and [reset] already runs on sign-out so one
  // account's previews can never surface in the next account's inbox.

  final Map<String, ChatPreview> _resolvedPreviews = {};

  /// Rows whose lookup came back with **nothing**. Tracked separately because
  /// "resolved to empty" and "not resolved yet" are different states, and
  /// conflating them re-queued the fetch on every single rebuild — a request
  /// loop that never settled.
  final Set<String> _resolvedEmpty = {};

  ChatPreview? resolvedPreview(String conversationId) =>
      _resolvedPreviews[conversationId];

  bool isPreviewResolved(String conversationId) =>
      _resolvedPreviews.containsKey(conversationId) ||
      _resolvedEmpty.contains(conversationId);

  /// Records a lookup result. A `null` [preview] means "there was nothing" and
  /// is remembered, not retried.
  void cacheResolvedPreview(String conversationId, ChatPreview? preview) {
    if (preview == null) {
      _resolvedEmpty.add(conversationId);
    } else {
      _resolvedPreviews[conversationId] = preview;
      _resolvedEmpty.remove(conversationId);
    }
  }

  /// Forgets one row's preview so it resolves again — used when returning from
  /// a conversation, where the last message has probably changed.
  void invalidateResolvedPreview(String conversationId) {
    _resolvedPreviews.remove(conversationId);
    _resolvedEmpty.remove(conversationId);
  }

  /// Populates [_conversations] from the durable cache for an instant cold-start
  /// paint. Returns whether anything was painted. Never throws — a cache miss or
  /// error just falls through to the network path.
  Future<bool> _paintFromCache() async {
    final getCached = _getCachedConversations;
    if (getCached == null) return false;
    try {
      final cached = await getCached();
      if (cached.isEmpty) return false;
      _conversations = cached;
      return true;
    } catch (e) {
      AppLog.warning('chat', 'inbox cache paint failed: $e');
      return false;
    }
  }

  /// The loaded summary for [conversationId], or null if the current window
  /// doesn't hold it. Lets a caller (e.g. the new-chat flow) read the
  /// server-computed counterpart id after [startChatWith] refreshes the list.
  ChatConversationSummary? conversationById(String conversationId) {
    for (final c in _conversations) {
      if (c.id == conversationId) return c;
    }
    return null;
  }

  /// Seeds [_unread] from the server-computed `unreadCount` on each summary.
  /// [replace] = true (a full load/refresh) rebuilds the map from scratch so it
  /// mirrors the server exactly; false (pagination append) only fills the new
  /// rows. A zero count clears any stale entry. This is what makes the badge
  /// survive a cold start — the socket path only increments live deltas.
  void _seedUnread(Iterable<ChatConversationSummary> summaries,
      {required bool replace}) {
    if (replace) _unread.clear();
    for (final c in summaries) {
      if (c.unreadCount > 0) {
        _unread[c.id] = c.unreadCount;
      } else {
        _unread.remove(c.id);
      }
    }
  }

  /// Unread counts cleared optimistically but not yet confirmed by a server
  /// mark-read, keyed by conversation id — the rollback record for
  /// [restoreUnread].
  final Map<String, int> _optimisticallyCleared = {};

  /// Clears the unread badge for [conversationId] — called when the user opens
  /// the conversation, immediately, so the badge feels instant.
  ///
  /// This is optimistic: the authoritative count comes from the server and the
  /// thread's mark-read call is what actually earns the clear. The previous
  /// count is remembered so [restoreUnread] can put it back if that call fails.
  void clearUnread(String conversationId) {
    final previous = _unread.remove(conversationId);
    if (previous == null) return;
    _optimisticallyCleared[conversationId] = previous;
    if (_hasLoaded) _emitLoaded();
  }

  /// Puts back a badge cleared by [clearUnread] whose mark-read never landed, so
  /// the inbox stops showing "read" for a thread the server still counts as
  /// unread. No-op once the conversation has a fresh count (a later load, or a
  /// newly delivered message, is more current than this rollback).
  void restoreUnread(String conversationId) {
    final previous = _optimisticallyCleared.remove(conversationId);
    if (previous == null || _unread.containsKey(conversationId)) return;
    _unread[conversationId] = previous;
    if (_hasLoaded) _emitLoaded();
  }

  /// Confirms an optimistic clear — the server agreed, so there is nothing to
  /// roll back any more.
  void confirmUnreadCleared(String conversationId) =>
      _optimisticallyCleared.remove(conversationId);

  // ─── Realtime (socket, shared with the thread cubits) ─────────────────

  void _onRealtimeEvent(ChatRealtimeEvent event) {
    if (isClosed) return;
    switch (event) {
      case ChatRealtimeConnected(:final isReconnect):
        // Anything could have happened in the gap (new conversations, new
        // messages, deletions) — re-pull page one, the documented refresh
        // path (list stays visible; pagination resets by design).
        if (isReconnect && _hasLoaded) load(forceRefresh: true);
      case ChatMessageReceived(:final message):
        _applyLiveMessage(message);
      case ChatMessageDeletedReceived e:
        // Only affects the inbox when the deleted message is the one being
        // previewed — swap in the placeholder (activity/order unchanged).
        if (_previewMessageIds[e.conversationId] == e.messageId) {
          _previews[e.conversationId] = chatDeletedForEveryonePlaceholder;
          if (_hasLoaded) _emitLoaded();
        }
      case ChatRealtimeDisconnected() ||
            ChatMessagesReadReceived() ||
            ChatMessageHiddenReceived():
        // Read receipts concern the thread view; a hidden message's preview
        // replacement isn't derivable client-side (next refresh corrects it);
        // a disconnect needs no UI (reconnect + refresh are automatic).
        break;
    }
  }

  /// A live message in one of my conversations (the server excludes my own
  /// sends, so this is always counterpart activity): bump the row to the top
  /// with fresh activity, update its preview, and count it unread. Deduped
  /// by per-conversation `seq` so replays and out-of-order stragglers are
  /// no-ops. An unknown conversation id → full refresh (server truth).
  void _applyLiveMessage(ChatMessage message) {
    if (!_hasLoaded) return; // nothing on screen to sync yet

    final lastSeen = _lastSeenSeq[message.conversationId];
    if (lastSeen != null && message.seq <= lastSeen) return;
    _lastSeenSeq[message.conversationId] = message.seq;

    final index =
        _conversations.indexWhere((c) => c.id == message.conversationId);
    if (index < 0) {
      // A conversation this page window doesn't hold (brand new, or beyond
      // the loaded pages). The client never invents a row — refresh instead.
      load(forceRefresh: true);
      // Still surface an in-app notification for it (name resolves in-thread).
      _notifyIncoming(message, counterpartExternalId: null);
      return;
    }

    final bumped =
        _conversations[index].withLastMessageAt(message.createdAt);
    _conversations = [
      bumped,
      ..._conversations.take(index),
      ..._conversations.skip(index + 1),
    ];
    _previews[message.conversationId] = _previewOf(message);
    _previewMessageIds[message.conversationId] = message.id;
    _unread[message.conversationId] =
        (_unread[message.conversationId] ?? 0) + 1;
    _emitLoaded();
    _notifyIncoming(message,
        counterpartExternalId: bumped.counterpartExternalId);
  }

  /// Raises a distinct incoming-message event (best-effort — a closed
  /// controller during teardown is ignored). The server never echoes the
  /// caller's own sends, so this is always genuine counterpart activity.
  void _notifyIncoming(ChatMessage message, {String? counterpartExternalId}) {
    if (_incomingController.isClosed) return;
    _incomingController.add(ChatIncomingMessage(
      conversationId: message.conversationId,
      preview: _previewOf(message),
      counterpartExternalId: counterpartExternalId,
    ));
  }

  String _previewOf(ChatMessage message) {
    if (message.deletedForEveryone) return chatDeletedForEveryonePlaceholder;
    final body = (message.body ?? '').trim();
    if (body.isNotEmpty) return body;
    final attachment = message.attachment;
    return attachment != null ? attachment.originalFilename : '';
  }

  /// Loads the next (older-activity) page and appends it. No-op while a page
  /// is already in flight or when the server reported no more pages.
  Future<void> loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingMore || _loading || !_hasLoaded) return;

    _loadingMore = true;
    _emitLoaded();
    try {
      final page = await _getConversations(cursor: cursor);
      final known = {for (final c in _conversations) c.id};
      final fresh =
          page.items.where((c) => !known.contains(c.id)).toList(growable: false);
      _conversations = [..._conversations, ...fresh];
      _nextCursor = page.nextCursor;
      // Seed unread for the newly appended rows only (don't disturb existing).
      _seedUnread(fresh, replace: false);
    } on Failure catch (e) {
      emit(ChatListState.error(e.message));
    } catch (e) {
      AppLog.warning('chat', 'conversation list page failed: $e');
      emit(const ChatListState.error('Failed to load more conversations.'));
    } finally {
      _loadingMore = false;
      _emitLoaded();
    }
  }

  /// Starts (get-or-creates) the conversation with the teammate identified by
  /// [targetUserRef] — the teammate's **DROP user id (Firebase uid)**, the only
  /// identity a client holds for another user; the server resolves it to the
  /// internal participant and returns the conversation. Returns it for
  /// navigation, or null on failure. Idempotent server-side, so picking a
  /// teammate you already chat with just returns the existing thread.
  ///
  /// On success the inbox is refreshed so the (possibly new) conversation shows
  /// with the server's real summary — the list row carries the server-computed
  /// counterpart id, which the client cannot derive from a Firebase uid alone.
  Future<ChatConversation?> startChatWith(String targetUserRef) async {
    if (_starting) return null;
    _starting = true;
    if (_hasLoaded) _emitLoaded();
    try {
      final conversation = await _startConversation(targetUserRef);
      // Pull the server's list so the conversation appears with correct data
      // (name/preview slots, ordering). A no-op-cheap refresh; fire-and-forget
      // would race the caller's navigation, so await it.
      _starting = false;
      await load(forceRefresh: true);
      return conversation;
    } on Failure catch (e) {
      _starting = false;
      emit(ChatListState.error(e.message));
      if (_hasLoaded) _emitLoaded();
      return null;
    } catch (e) {
      AppLog.warning('chat', 'start conversation failed: $e');
      _starting = false;
      emit(const ChatListState.error('Failed to start the conversation.'));
      if (_hasLoaded) _emitLoaded();
      return null;
    } finally {
      _starting = false;
      if (_hasLoaded) _emitLoaded();
    }
  }
}

/// A single "new message just arrived" signal for the app-wide in-app
/// notification listener. Carries only what a notification needs: which
/// conversation, a one-line preview, and the counterpart's directory key
/// (Firebase uid) so the listener can resolve the sender's real name — null
/// when the conversation isn't in the loaded window yet (the notification then
/// falls back to a neutral title).
class ChatIncomingMessage {
  const ChatIncomingMessage({
    required this.conversationId,
    required this.preview,
    this.counterpartExternalId,
  });

  final String conversationId;
  final String preview;
  final String? counterpartExternalId;
}
