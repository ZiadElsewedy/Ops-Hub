import 'package:drop/features/chat/domain/entities/chat_message.dart';

/// Domain port for the chat realtime channel (the backend's Socket.IO
/// `/chat` namespace) — the socket sibling of [ChatRepository]. **Read-only by
/// contract**: all writes (send, read, delete) stay on REST; the socket only
/// delivers facts the server already committed, and clients reconcile through
/// REST history after a connection gap (the backend's documented expectation —
/// delivery is best-effort, REST is the source of truth).
///
/// Room lifecycle mirrors the backend: connecting joins the caller's personal
/// `user:{id}` room automatically; a conversation room must be joined
/// explicitly while the thread is on screen and is dropped server-side on
/// every disconnect — implementations re-join their active conversations on
/// reconnect, so callers never manage that themselves.
abstract class ChatRealtime {
  /// Server-pushed facts + connection transitions, as one broadcast stream.
  /// Events for every joined conversation are multiplexed here — consumers
  /// filter by conversation id.
  Stream<ChatRealtimeEvent> get events;

  /// Joins [conversationId]'s room (connecting the socket first if needed).
  /// Resolves true when the server acknowledged the join, false when it
  /// refused ("not found" — also the non-participant answer) or the socket
  /// couldn't connect. Safe to call repeatedly.
  Future<bool> joinConversation(String conversationId);

  /// Leaves [conversationId]'s room. When nothing else needs the connection
  /// (no joined conversations, inbox not attached) the implementation may
  /// drop it entirely. Idempotent.
  Future<void> leaveConversation(String conversationId);

  /// Declares inbox-level interest: keeps the socket connected even with no
  /// conversation room joined. The server delivers `message:new` for *every*
  /// conversation of the caller through their auto-joined personal
  /// `user:{id}` room, so the inbox needs no room join — only a live
  /// connection. Idempotent.
  Future<void> attachInbox();

  /// Withdraws inbox-level interest; the connection drops once no joined
  /// conversations remain either. Idempotent.
  Future<void> detachInbox();
}

/// One fact or transition from the realtime channel.
sealed class ChatRealtimeEvent {
  const ChatRealtimeEvent();
}

/// The socket (re)connected and authenticated. [isReconnect] is true for every
/// connection after the first — the signal to reconcile missed history via
/// REST (rooms were re-joined by the implementation already).
class ChatRealtimeConnected extends ChatRealtimeEvent {
  const ChatRealtimeConnected({required this.isReconnect});
  final bool isReconnect;
}

/// The socket dropped. Reconnection is automatic while conversations are
/// joined; purely informational for consumers.
class ChatRealtimeDisconnected extends ChatRealtimeEvent {
  const ChatRealtimeDisconnected();
}

/// `message:new` — a new message in a joined conversation (or any conversation
/// of mine, via the personal room). Never the caller's own send: the server
/// excludes the sender's sockets, whose client already holds the message from
/// the REST response. The payload is byte-identical to REST history.
class ChatMessageReceived extends ChatRealtimeEvent {
  const ChatMessageReceived(this.message);
  final ChatMessage message;
}

/// `message:read` — the counterpart read a batch of messages. The server
/// excludes the reader's own sockets, so [readerId] is always someone else
/// from the receiving client's perspective.
class ChatMessagesReadReceived extends ChatRealtimeEvent {
  const ChatMessagesReadReceived({
    required this.conversationId,
    required this.readerId,
    required this.messageIds,
    required this.readAt,
  });

  final String conversationId;
  final String readerId;
  final List<String> messageIds;
  final DateTime readAt;
}

/// `message:deleted` — a message was deleted for everyone and must re-render
/// as the placeholder. Broadcast to both participants with no exclusion.
/// Parsed for protocol completeness; the delete UI phase consumes it.
class ChatMessageDeletedReceived extends ChatRealtimeEvent {
  const ChatMessageDeletedReceived({
    required this.conversationId,
    required this.messageId,
    required this.deletedBy,
    required this.deletedAt,
  });

  final String conversationId;
  final String messageId;
  final String deletedBy;
  final DateTime deletedAt;
}

/// `message:deleted-for-me` — the caller hid a message on another of their own
/// sessions (strictly one-sided; never reaches the counterpart). Parsed for
/// protocol completeness; the delete UI phase consumes it.
class ChatMessageHiddenReceived extends ChatRealtimeEvent {
  const ChatMessageHiddenReceived({
    required this.conversationId,
    required this.messageId,
    required this.deletedAt,
  });

  final String conversationId;
  final String messageId;
  final DateTime deletedAt;
}
