import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:drop/core/network/api_client.dart' show AuthTokenProvider;
import 'package:drop/core/utils/app_logger.dart';
import 'package:drop/features/chat/data/realtime/chat_realtime_payloads.dart';
import 'package:drop/features/chat/domain/chat_realtime.dart';

/// [ChatRealtime] over Socket.IO — the client half of the backend's
/// `ChatGateway` (`drop-api` · `chat/realtime/interface/socket/`, namespace
/// `/chat`). This file is the **only** place `socket_io_client` may be
/// imported, mirroring the dio rule for `core/network/`.
///
/// Protocol (verbatim from the gateway):
/// * **Handshake auth** — the Firebase ID token in `handshake.auth.token`;
///   a rejected handshake receives `connection:error {message}` and is
///   disconnected server-side.
/// * **Client → server** — `conversation:join` / `conversation:leave` with
///   `{conversationId}`, acknowledged as `{ok, error?}` (a join refusal is
///   the same non-revealing shape for missing and non-participant).
/// * **Server → client** — `message:new` (full REST-shaped message),
///   `message:read`, `message:deleted`, `message:deleted-for-me`.
///
/// Lifecycle: the socket exists only while something needs it — a joined
/// conversation room, or inbox-level interest ([attachInbox]); the first
/// interest connects, the last withdrawal tears down. The server
/// clears all rooms on every disconnect, so after each (re)connect this
/// service re-joins everything in [_joined] itself and emits
/// [ChatRealtimeConnected] (with `isReconnect` set after the first
/// connection) so consumers can reconcile missed history via REST — the
/// backend's documented expectation: delivery is best-effort, REST is truth.
///
/// Reconnection is owned here, not by the library: each attempt **rebuilds**
/// the socket with a freshly fetched token (the library's built-in reconnect
/// would replay the original, possibly expired, handshake auth). Backoff is
/// exponential, capped, and runs only while conversations are joined. After
/// an auth rejection the next attempt force-refreshes the token once.
class ChatSocketService implements ChatRealtime {
  ChatSocketService({
    required String baseUrl,
    required this._tokenProvider,
  })  : _namespaceUrl = '$baseUrl/chat';

  final String _namespaceUrl;
  final AuthTokenProvider _tokenProvider;

  final _events = StreamController<ChatRealtimeEvent>.broadcast();
  final Set<String> _joined = {};

  io.Socket? _socket;
  Timer? _retryTimer;
  Timer? _authConfirmTimer;
  Completer<bool>? _pendingOpen;
  int _attempt = 0;
  bool _connecting = false;
  bool _connectedOnce = false;
  bool _sessionConfirmed = false;
  bool _forceRefreshToken = false;
  bool _inboxAttached = false;
  bool _disposed = false;

  /// Whether anything needs the connection alive — a joined conversation
  /// room, or inbox-level interest (the personal `user:{id}` room delivers
  /// `message:new` for every conversation without any join).
  bool get _hasInterest => _inboxAttached || _joined.isNotEmpty;

  static const _connectTimeout = Duration(seconds: 15);
  static const _ackTimeout = Duration(seconds: 10);
  static const _maxBackoff = Duration(seconds: 30);

  /// After the transport connects, this gateway still rejects a bad token via
  /// `connection:error` followed by a server-side disconnect — so a raw
  /// `connect` is NOT proof of an authenticated session. The connection is only
  /// promoted to "healthy" (backoff reset, [ChatRealtimeConnected] emitted,
  /// rooms re-joined) after this grace window passes with no rejection.
  ///
  /// Without it, a connect-then-reject bounce resets the backoff on every cycle
  /// and emits a false "connected" that re-pulls the REST inbox — turning a
  /// single expired token into a ~1/second reconnect + 401 + crash storm.
  static const _authConfirmGrace = Duration(milliseconds: 800);

  @override
  Stream<ChatRealtimeEvent> get events => _events.stream;

  @override
  Future<bool> joinConversation(String conversationId) async {
    if (_disposed) return false;
    _joined.add(conversationId);
    final socket = await _ensureConnected();
    if (socket == null) return false; // retry loop re-joins once it connects
    return _emitJoin(socket, conversationId);
  }

  @override
  Future<void> leaveConversation(String conversationId) async {
    _joined.remove(conversationId);
    final socket = _socket;
    if (socket != null && socket.connected) {
      socket.emitWithAck('conversation:leave',
          {'conversationId': conversationId}, ack: (_) {});
    }
    // Nothing needs realtime anymore — drop the connection (and any retry
    // loop) entirely rather than idling a socket.
    if (!_hasInterest) _teardownSocket();
  }

  @override
  Future<void> attachInbox() async {
    if (_disposed) return;
    _inboxAttached = true;
    await _ensureConnected();
  }

  @override
  Future<void> detachInbox() async {
    _inboxAttached = false;
    if (!_hasInterest) _teardownSocket();
  }

  /// Releases the socket and closes the event stream. Terminal.
  void dispose() {
    _disposed = true;
    _inboxAttached = false;
    _joined.clear();
    _teardownSocket();
    _events.close();
  }

  // ─── Connection ───────────────────────────────────────────────────────

  /// Returns the connected socket, connecting first when needed. Null when
  /// the attempt failed — the backoff loop is then scheduled (while any
  /// conversation is joined) and will re-join rooms itself on success.
  Future<io.Socket?> _ensureConnected() async {
    final existing = _socket;
    if (existing != null && existing.connected) return existing;
    if (_connecting) {
      // A connect is already in flight; don't stack attempts. The caller's
      // room is in [_joined], so the in-flight success will join it.
      return null;
    }
    _connecting = true;
    try {
      return await _connectOnce();
    } finally {
      _connecting = false;
    }
  }

  Future<io.Socket?> _connectOnce() async {
    _retryTimer?.cancel();
    _teardownSocket(keepBackoff: true);

    String? token;
    try {
      token = await _tokenProvider(forceRefresh: _forceRefreshToken);
    } catch (e) {
      AppLog.warning('chat', 'socket token fetch failed: $e');
    }
    _forceRefreshToken = false;
    if (token == null) {
      // Signed out (or token fetch failed) — connecting would only bounce off
      // the gateway's auth. Retry on the backoff loop.
      _scheduleRetry();
      return null;
    }

    final socket = io.io(
      _namespaceUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .disableReconnection() // reconnection is owned here (fresh token)
          .enableForceNew()
          .setAuth({'token': token})
          .build(),
    );
    _socket = socket;
    _sessionConfirmed = false;

    // The handshake only completes once the connection is *confirmed*
    // authenticated (grace window elapsed with no `connection:error`) or has
    // failed — not on the raw transport connect, which this gateway allows
    // before it rejects a bad token. All of that is wired in [_wireEvents],
    // which settles this completer via [_settleOpen].
    final opened = Completer<bool>();
    _pendingOpen = opened;
    _wireEvents(socket);
    socket.connect();

    final ok = await opened.future
        .timeout(_connectTimeout, onTimeout: () => false);
    _pendingOpen = null;
    if (!ok || _disposed) {
      _scheduleRetry();
      return null;
    }
    return socket;
  }

  void _wireEvents(io.Socket socket) {
    // A raw transport connect is NOT an authenticated session (see
    // [_authConfirmGrace]): defer every success side effect until the grace
    // window passes with no `connection:error`. Until then the backoff is
    // untouched, no [ChatRealtimeConnected] is emitted, and no room is joined.
    socket.onConnect((_) {
      _authConfirmTimer?.cancel();
      _authConfirmTimer =
          Timer(_authConfirmGrace, () => _confirmConnection(socket));
    });

    socket.onConnectError((_) {
      // Transport-level failure — no auth verdict. Fail the in-flight connect
      // and retry with the backoff intact; a `disconnect` may not follow a
      // connect error, so schedule here too (the retry guard dedupes).
      _settleOpen(false);
      _scheduleRetry();
    });

    // The gateway's auth rejection: it names the reason, then disconnects us.
    // Cancel the pending confirmation so this connection is never counted as
    // healthy (leaving the backoff to grow), and force-refresh the token on the
    // next attempt (expiry is the usual cause).
    socket.on('connection:error', (data) {
      _authConfirmTimer?.cancel();
      _authConfirmTimer = null;
      _forceRefreshToken = true;
      final message = data is Map ? data['message']?.toString() : null;
      AppLog.warning(
          'chat', 'socket auth rejected: ${message ?? 'unknown reason'}');
      _settleOpen(false);
    });

    socket.onDisconnect((_) {
      _authConfirmTimer?.cancel();
      _authConfirmTimer = null;
      // Only pair a Disconnected with a Connected we actually emitted: a
      // never-confirmed (auth-rejected) connection stays silent so the inbox
      // and thread views aren't churned during a reconnect storm.
      if (_sessionConfirmed) {
        _sessionConfirmed = false;
        _emitEvent(const ChatRealtimeDisconnected());
      }
      _settleOpen(false);
      _scheduleRetry();
    });

    socket.on('message:new', (data) => _parse(data, parseMessageNew));
    socket.on('message:read', (data) => _parse(data, parseMessageRead));
    socket.on('message:deleted', (data) => _parse(data, parseMessageDeleted));
    socket.on('message:deleted-for-me',
        (data) => _parse(data, parseMessageDeletedForMe));
  }

  /// Promotes a transport connect to a confirmed, authenticated session once
  /// [_authConfirmGrace] elapses with no `connection:error`: resets the
  /// backoff, emits [ChatRealtimeConnected] and re-joins every active room
  /// (the server cleared them on the previous disconnect). A stale timer — the
  /// socket was replaced or torn down meanwhile — is ignored.
  void _confirmConnection(io.Socket socket) {
    _authConfirmTimer = null;
    if (_disposed || socket != _socket || !socket.connected) return;
    _attempt = 0;
    _sessionConfirmed = true;
    final isReconnect = _connectedOnce;
    _connectedOnce = true;
    _settleOpen(true);
    _emitEvent(ChatRealtimeConnected(isReconnect: isReconnect));
    for (final id in _joined) {
      _emitJoin(socket, id);
    }
  }

  /// Completes the in-flight [_connectOnce] handshake exactly once.
  void _settleOpen(bool ok) {
    final pending = _pendingOpen;
    if (pending != null && !pending.isCompleted) pending.complete(ok);
  }

  void _parse(dynamic data,
      ChatRealtimeEvent Function(Map<String, dynamic>) parser) {
    if (data is! Map) return;
    try {
      _emitEvent(parser(data.cast<String, dynamic>()));
    } catch (e) {
      // A malformed payload must never kill the stream — log and move on;
      // REST reconciliation covers whatever was missed.
      AppLog.warning('chat', 'socket payload parse failed: $e');
    }
  }

  Future<bool> _emitJoin(io.Socket socket, String conversationId) {
    final acked = Completer<bool>();
    socket.emitWithAck(
      'conversation:join',
      {'conversationId': conversationId},
      ack: (dynamic response) {
        final ok = response is Map && response['ok'] == true;
        if (!ok) {
          AppLog.warning('chat',
              'conversation:join refused: ${response is Map ? response['error'] : response}');
        }
        if (!acked.isCompleted) acked.complete(ok);
      },
    );
    return acked.future.timeout(_ackTimeout, onTimeout: () => false);
  }

  void _emitEvent(ChatRealtimeEvent event) {
    if (!_disposed && !_events.isClosed) _events.add(event);
  }

  // ─── Reconnection ─────────────────────────────────────────────────────

  void _scheduleRetry() {
    if (_disposed || !_hasInterest) return;
    if (_retryTimer?.isActive ?? false) return;
    final delay = _backoff(_attempt);
    _attempt++;
    _retryTimer = Timer(delay, () async {
      if (_disposed || !_hasInterest) return;
      if (_connecting || (_socket?.connected ?? false)) return;
      _connecting = true;
      try {
        await _connectOnce();
      } finally {
        _connecting = false;
      }
    });
  }

  Duration _backoff(int attempt) {
    final seconds = 1 << (attempt > 5 ? 5 : attempt); // 1,2,4,8,16,32→capped
    final capped = Duration(seconds: seconds);
    return capped > _maxBackoff ? _maxBackoff : capped;
  }

  void _teardownSocket({bool keepBackoff = false}) {
    _authConfirmTimer?.cancel();
    _authConfirmTimer = null;
    _sessionConfirmed = false;
    _settleOpen(false);
    if (!keepBackoff) {
      _retryTimer?.cancel();
      _retryTimer = null;
      _attempt = 0;
    }
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      // Detach handlers before disposing so the teardown's own disconnect
      // doesn't schedule a retry.
      socket.clearListeners();
      socket.dispose();
    }
  }
}
