/// A direct (1:1) chat conversation between two DROP users — the client mirror
/// of the backend's `ConversationResponseDto` (`drop-api` ·
/// `chat/conversations/interface/http/dto/conversation-response.dto.ts`).
///
/// Plain immutable value objects (not freezed) — mirroring the [CaseIdentity]
/// precedent: they cross the data boundary and are held by cubit states later,
/// but state equality is handled at the state level, so no codegen is needed
/// in this layer.
class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.participantIds,
    required this.createdAt,
    this.lastMessageAt,
  });

  /// Conversation UUID.
  final String id;

  /// Both participants' internal user UUIDs (always exactly two in V1).
  final List<String> participantIds;

  final DateTime createdAt;

  /// Timestamp of the newest message; null for an empty conversation. The
  /// server orders the conversation list by this (most recent activity first).
  final DateTime? lastMessageAt;

  /// The other participant relative to [myUserId] — for a conversation fetched
  /// by id (the list endpoint provides this pre-computed, see
  /// [ChatConversationSummary.counterpartUserId]).
  String counterpartOf(String myUserId) =>
      participantIds.firstWhere((id) => id != myUserId, orElse: () => myUserId);
}

/// One row of the caller's conversation list — the client mirror of the
/// backend's `ConversationListItemResponseDto`. Identical to
/// [ChatConversation] plus the server-computed [counterpartUserId] and
/// [unreadCount]. Last-message previews remain client-resolved from cache,
/// history, and realtime because the list endpoint does not expose them.
class ChatConversationSummary {
  const ChatConversationSummary({
    required this.id,
    required this.counterpartUserId,
    required this.participantIds,
    required this.createdAt,
    this.counterpartExternalId,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.lastMessage,
  });

  final String id;

  /// The other participant relative to the requester, resolved server-side.
  /// Backend-internal id — **never a UI display key**; use
  /// [counterpartExternalId] to look up the real profile.
  final String counterpartUserId;

  /// The counterpart's DROP user id (Firebase uid), so the client can resolve
  /// the real name/avatar/role from its own directory. Null if the backend
  /// hasn't provisioned the counterpart yet.
  final String? counterpartExternalId;

  final List<String> participantIds;
  final DateTime createdAt;
  final DateTime? lastMessageAt;

  /// Messages the requester has received in this conversation but not yet read,
  /// as counted server-side. Seeds the inbox/nav unread badge so it is correct
  /// on a cold start (the live socket only increments from here). 0 = none.
  final int unreadCount;

  /// The latest message, served with the row (FR-021) so the inbox can draw a
  /// preview without a follow-up request per conversation.
  ///
  /// Null means **nothing to preview**, which is not the same as "not loaded":
  /// the conversation has no messages, the requester deleted the latest for
  /// themselves, or the server predates this field. The inbox falls back to
  /// resolving the preview itself in that last case, so the client works
  /// against a deployed server that does not send it yet.
  final ChatLastMessage? lastMessage;

  /// This row with a fresher [lastMessageAt] — how a live `message:new`
  /// bumps a conversation's activity without a REST round trip.
  ChatConversationSummary withLastMessageAt(DateTime at) =>
      ChatConversationSummary(
        id: id,
        counterpartUserId: counterpartUserId,
        counterpartExternalId: counterpartExternalId,
        participantIds: participantIds,
        createdAt: createdAt,
        lastMessageAt: at,
        unreadCount: unreadCount,
        lastMessage: lastMessage,
      );
}

/// The conversation-list preview message. Deliberately unformatted — the row
/// composes its line with the rules the client already owns (attachment label,
/// "You:" prefix, tombstone placeholder).
class ChatLastMessage {
  const ChatLastMessage({
    required this.id,
    required this.senderId,
    required this.type,
    this.body,
    this.deletedForEveryoneAt,
  });

  final String id;
  final String senderId;
  final String type;
  final String? body;

  /// Set when the message was deleted for everyone.
  final DateTime? deletedForEveryoneAt;

  bool get isDeletedForEveryone => deletedForEveryoneAt != null;
}

/// A page of the conversation list with an opaque keyset cursor. Pass
/// [nextCursor] back as `cursor` to load the next page; null means no more.
class ChatConversationPage {
  const ChatConversationPage({required this.items, this.nextCursor});

  final List<ChatConversationSummary> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}
