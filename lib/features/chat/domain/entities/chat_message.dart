import 'dart:typed_data';

import 'package:drop/core/enums/chat_attachment_kind.dart';
import 'package:drop/core/enums/chat_message_type.dart';

/// The standard text shown in place of a message deleted for everyone — the
/// exact mirror of the backend's `DELETED_FOR_EVERYONE_PLACEHOLDER`
/// (`drop-api` · `chat/messages/domain/delete-for-everyone.policy.ts`). REST
/// tombstones arrive with this body already substituted; the live
/// `message:deleted` socket event carries identifiers only, so the client
/// applies the same text when tombstoning locally.
const String chatDeletedForEveryonePlaceholder = 'This message was deleted';

/// A chat message — the client mirror of the backend's `MessageResponseDto`
/// (`drop-api` · `chat/messages/interface/http/dto/message.response.dto.ts`).
///
/// [seq] is the conversation-scoped ordering sequence. The backend serializes
/// it as a **string** because it is a 64-bit value; it is parsed to [BigInt]
/// here so ordering and cursor math stay exact on every platform (a web build's
/// `int` is a 53-bit JS number).
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.type,
    this.body,
    this.attachment,
    this.replyTo,
    required this.seq,
    required this.status,
    required this.createdAt,
    this.deletedForEveryone = false,
    this.localBytes,
    this.uploadProgress,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final ChatMessageType type;

  /// Text content; null for an attachment-only message. When
  /// [deletedForEveryone] is true this carries the server's placeholder text.
  final String? body;

  /// Null for a text-only message.
  final ChatMessageAttachment? attachment;

  /// Shallow preview of the quoted parent when this message is a reply.
  final ChatReplyPreview? replyTo;

  /// Monotonic per-conversation sequence — the ordering key and history cursor.
  final BigInt seq;

  /// Delivery status as reported by the server. A persisted message is always
  /// at least `SENT` in V1; delivered/read transitions arrive with the
  /// realtime phase, so this is kept as the raw wire string rather than a
  /// client-invented enum that would break on new values.
  final String status;

  final DateTime createdAt;

  /// True when the message was deleted for everyone (tombstoned); [body] then
  /// holds the standard placeholder and [attachment] is gone.
  final bool deletedForEveryone;

  /// **Client-only, never serialized.** The raw bytes of an outgoing attachment
  /// on an optimistic (not-yet-confirmed) local message, so its image thumbnail
  /// can render immediately from memory while the upload is in flight. Always
  /// null on a message that came from the server.
  final Uint8List? localBytes;

  /// **Client-only, never serialized.** Upload progress (0.0–1.0) of an
  /// in-flight attachment send, driven by the HTTP transfer callback. Null for
  /// text sends and for any confirmed/server message.
  final double? uploadProgress;

  /// This message in the deleted-for-everyone state — how a live
  /// `message:deleted` event re-renders it: the placeholder as the body, the
  /// attachment gone, everything else (id, seq, timestamps) preserved,
  /// matching the server's own tombstone shape.
  ChatMessage asDeletedForEveryone() => ChatMessage(
        id: id,
        conversationId: conversationId,
        senderId: senderId,
        type: type,
        body: chatDeletedForEveryonePlaceholder,
        attachment: null,
        replyTo: replyTo,
        seq: seq,
        status: status,
        createdAt: createdAt,
        deletedForEveryone: true,
      );

  /// This message with an updated delivery [status] — used when a realtime
  /// read receipt upgrades an already-rendered message. Everything else is
  /// immutable by contract.
  ChatMessage withStatus(String status) => ChatMessage(
        id: id,
        conversationId: conversationId,
        senderId: senderId,
        type: type,
        body: body,
        attachment: attachment,
        replyTo: replyTo,
        seq: seq,
        status: status,
        createdAt: createdAt,
        deletedForEveryone: deletedForEveryone,
        localBytes: localBytes,
        uploadProgress: uploadProgress,
      );

  /// Copy with a new [uploadProgress] (0.0–1.0), keeping everything else — used
  /// to drive the in-flight attachment progress ring.
  ChatMessage withUploadProgress(double? progress) => ChatMessage(
        id: id,
        conversationId: conversationId,
        senderId: senderId,
        type: type,
        body: body,
        attachment: attachment,
        replyTo: replyTo,
        seq: seq,
        status: status,
        createdAt: createdAt,
        deletedForEveryone: deletedForEveryone,
        localBytes: localBytes,
        uploadProgress: progress,
      );
}

/// An attachment riding on a message — mirror of `MessageAttachmentDto`.
/// [format] is kept as the raw wire string (`"PDF"`, `"JPG"`, …): received
/// history must never fail to parse because a newer server added a format.
/// The outgoing (send) side uses the strict [ChatAttachmentFormat] enum.
class ChatMessageAttachment {
  const ChatMessageAttachment({
    required this.id,
    required this.kind,
    required this.format,
    required this.mimeType,
    required this.originalFilename,
    required this.byteSize,
  });

  final String id;
  final ChatAttachmentKind kind;
  final String format;
  final String mimeType;
  final String originalFilename;

  /// Size in bytes. Serialized as a string on the wire (64-bit); parsed to
  /// [int] here — attachment sizes are bounded by the server's upload limit
  /// and comfortably fit a 53-bit web int.
  final int byteSize;
}

/// Shallow preview of the message a reply quotes — mirror of
/// `MessageReplyPreviewDto`. Reference-only: reflects the parent's *current*
/// state (a deleted-for-everyone parent shows its placeholder body) and
/// carries no `seq` and no nested reply.
class ChatReplyPreview {
  const ChatReplyPreview({
    required this.id,
    required this.senderId,
    required this.type,
    this.body,
    this.attachment,
  });

  final String id;
  final String senderId;
  final ChatMessageType type;
  final String? body;
  final ChatMessageAttachment? attachment;
}

/// A page of message history, oldest → newest within the page. Pass
/// [nextCursor] back as `cursor` to load the next **older** page; null means
/// the full history has been loaded.
class ChatMessagePage {
  const ChatMessagePage({
    required this.items,
    this.nextCursor,
  });

  final List<ChatMessage> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}
