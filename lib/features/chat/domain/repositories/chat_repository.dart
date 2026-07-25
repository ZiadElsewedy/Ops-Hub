import 'package:drop/features/chat/domain/entities/chat_attachment_download.dart';
import 'package:drop/features/chat/domain/entities/chat_conversation.dart';
import 'package:drop/features/chat/domain/entities/chat_message.dart';
import 'package:drop/features/chat/domain/entities/chat_outgoing_attachment.dart';
import 'package:drop/features/chat/domain/entities/chat_read_receipt.dart';

/// Contract for direct (1:1) chat data access, backed by the NestJS API
/// (`drop-api` · `chat/` module) — REST only; realtime (socket) delivery is a
/// separate later phase. Access control is enforced server-side: every call is
/// participant-scoped by the caller's identity (Bearer token), and a
/// conversation the caller isn't part of surfaces as "not found" — the API
/// never reveals existence.
abstract class ChatRepository {
  /// Starts (get-or-creates) the conversation with the teammate identified by
  /// [targetUserRef] — their **DROP user id (Firebase uid)**, the identity a
  /// client holds for another user. The server resolves it to the internal
  /// participant (provisioning the teammate's user record on first sight) and
  /// returns the conversation. Idempotent per pair — the same conversation is
  /// returned whether it existed or was just created, so this doubles as "open
  /// chat with user".
  ///
  /// `POST /conversations` (body `{ targetUserId }`)
  Future<ChatConversation> startConversation(String targetUserRef);

  /// The caller's conversations, most-recent-activity first. [cursor] is the
  /// opaque `nextCursor` from the previous page. The server clamps [limit] to
  /// 1..50 (default 20).
  ///
  /// When an offline cache is wired, the first page (no [cursor]) transparently
  /// falls back to the cached list if the network is unreachable.
  ///
  /// `GET /conversations`
  Future<ChatConversationPage> getConversations({int? limit, String? cursor});

  /// The locally-cached conversation list only — no network. Empty when nothing
  /// is cached (or no cache is wired). Lets the inbox paint instantly on a cold
  /// start while [getConversations] refreshes from the server in the background.
  Future<List<ChatConversationSummary>> getCachedConversations();

  /// A single conversation the caller participates in. Throws a
  /// [ServerFailure] with the server's "not found" message for a missing
  /// conversation or a non-participant.
  ///
  /// `GET /conversations/:id`
  Future<ChatConversation> getConversation(String conversationId);

  /// Sends a message — text only, attachment only, or both (at least one is
  /// required; the server rejects an empty send with a 400).
  ///
  /// [idempotencyKey] is a **client-generated UUID identifying this logical
  /// send** — keep it stable across retries of the same send and the server
  /// returns the already-persisted message instead of duplicating it (or
  /// re-uploading the attachment).
  ///
  /// [onSendProgress] is a **client-side** transfer-progress hook (bytes sent /
  /// total) for the HTTP upload — used to drive the attachment progress ring.
  /// It is not part of the wire contract and never affects the request body.
  ///
  /// `POST /conversations/:id/messages`
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String idempotencyKey,
    String? content,
    ChatOutgoingAttachment? attachment,
    String? replyToMessageId,
    void Function(int sent, int total)? onSendProgress,
  });

  /// A page of message history, oldest → newest within the page, newest page
  /// first. [cursor] is the opaque `nextCursor` from the previous page and
  /// loads the next **older** page. The server clamps [limit] to 1..50
  /// (default 20). Messages the caller deleted-for-me are filtered
  /// server-side.
  ///
  /// `GET /conversations/:id/messages`
  Future<ChatMessagePage> getMessageHistory({
    required String conversationId,
    int? limit,
    String? cursor,
  });

  /// Marks the conversation read up to [upToSeq] (the highest **visible**
  /// message's seq — call this when messages are actually on screen, not when
  /// they're merely fetched). Idempotent; a replay reports `markedCount: 0`.
  ///
  /// `POST /conversations/:id/messages/read`
  Future<ChatReadReceipt> markMessagesRead({
    required String conversationId,
    required BigInt upToSeq,
  });

  /// Deletes a message from the **caller's** view only; the other participant
  /// is unaffected. Idempotent.
  ///
  /// `DELETE /conversations/:id/messages/:messageId`
  Future<void> deleteMessageForMe({
    required String conversationId,
    required String messageId,
  });

  /// Deletes a message for **both** participants — sender-only, within the
  /// server's time window (a 403 outside it). Returns the tombstoned message
  /// (placeholder body) to swap into the timeline. Idempotent.
  ///
  /// `DELETE /conversations/:id/messages/:messageId/for-everyone`
  Future<ChatMessage> deleteMessageForEveryone({
    required String conversationId,
    required String messageId,
  });

  /// A short-lived download URL for a message's attachment. Fetch the bytes
  /// directly from the URL before it expires; request a fresh one after.
  ///
  /// `GET /conversations/:id/messages/:messageId/attachment`
  Future<ChatAttachmentDownload> getAttachmentDownloadUrl({
    required String conversationId,
    required String messageId,
  });
}
