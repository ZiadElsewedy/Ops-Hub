import 'dart:convert';

import 'package:drop/core/enums/chat_attachment_kind.dart';
import 'package:drop/core/enums/chat_message_type.dart';
import 'package:drop/features/chat/domain/entities/chat_message.dart';
import 'package:drop/features/chat/domain/entities/chat_outgoing_attachment.dart';
import 'package:drop/features/chat/domain/entities/chat_read_receipt.dart';

/// JSON (de)serialization for messages — the exact wire shapes of the
/// backend's `MessageResponseDto`, `MessageAttachmentDto`,
/// `MessageReplyPreviewDto`, `MessageListResponseDto` and
/// `MarkMessagesReadResponseDto` (`drop-api` ·
/// `chat/messages/interface/http/dto/`), plus the `SendMessageDto` request
/// body. Field names are verbatim from those DTOs.
///
/// Wire quirks handled here (and nowhere else):
/// - `seq` and `byteSize` arrive as **strings** (64-bit values, not safe as
///   JSON numbers) — parsed to [BigInt] / [int] respectively.
/// - `upToSeq` must be **sent** as a string for the same reason.
/// - outgoing attachment bytes are **base64** inside the JSON body.
class ChatMessageModel {
  const ChatMessageModel._();

  // ─── Responses ────────────────────────────────────────────────────────

  /// `MessageResponseDto` → [ChatMessage].
  static ChatMessage fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        conversationId: json['conversationId'] as String,
        senderId: json['senderId'] as String,
        type: ChatMessageType.fromString(json['type'] as String?),
        body: json['body'] as String?,
        attachment: _optionalAttachment(json['attachment']),
        replyTo: _optionalReply(json['replyTo']),
        seq: BigInt.parse(json['seq'] as String),
        status: json['status'] as String? ?? 'SENT',
        createdAt: DateTime.parse(json['createdAt'] as String),
        deletedForEveryone: json['deletedForEveryone'] as bool? ?? false,
      );

  /// `MessageListResponseDto` (`{items, nextCursor}`) → [ChatMessagePage].
  static ChatMessagePage pageFromJson(Map<String, dynamic> json) =>
      ChatMessagePage(
        items: [
          for (final item in (json['items'] as List? ?? const []))
            fromJson((item as Map).cast<String, dynamic>()),
        ],
        nextCursor: json['nextCursor'] as String?,
      );

  /// `MarkMessagesReadResponseDto` → [ChatReadReceipt].
  static ChatReadReceipt readReceiptFromJson(Map<String, dynamic> json) =>
      ChatReadReceipt(
        conversationId: json['conversationId'] as String,
        markedCount: (json['markedCount'] as num).toInt(),
        readAt: DateTime.parse(json['readAt'] as String),
      );

  static ChatMessageAttachment attachmentFromJson(Map<String, dynamic> json) =>
      ChatMessageAttachment(
        id: json['id'] as String,
        kind: ChatAttachmentKind.fromString(json['kind'] as String?),
        format: json['format'] as String? ?? '',
        mimeType: json['mimeType'] as String? ?? '',
        originalFilename: json['originalFilename'] as String? ?? '',
        byteSize: int.tryParse(json['byteSize'] as String? ?? '') ?? 0,
      );

  static ChatMessageAttachment? _optionalAttachment(dynamic raw) => raw is Map
      ? attachmentFromJson(raw.cast<String, dynamic>())
      : null;

  static ChatReplyPreview? _optionalReply(dynamic raw) {
    if (raw is! Map) return null;
    final json = raw.cast<String, dynamic>();
    return ChatReplyPreview(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      type: ChatMessageType.fromString(json['type'] as String?),
      body: json['body'] as String?,
      attachment: _optionalAttachment(json['attachment']),
    );
  }

  // ─── Requests ─────────────────────────────────────────────────────────

  /// The `SendMessageDto` body. Optional fields are omitted (not null-valued)
  /// to match the backend pipe's `undefined` checks exactly.
  static Map<String, dynamic> sendBody({
    required String idempotencyKey,
    String? content,
    ChatOutgoingAttachment? attachment,
    String? replyToMessageId,
  }) =>
      {
        'idempotencyKey': idempotencyKey,
        'content': ?content,
        'replyToMessageId': ?replyToMessageId,
        if (attachment != null)
          'attachment': {
            'kind': attachment.kind.value,
            'format': attachment.format.value,
            'mimeType': attachment.mimeType,
            'originalFilename': attachment.originalFilename,
            'data': base64Encode(attachment.bytes),
          },
      };

  /// The `MarkMessagesReadDto` body — `upToSeq` as a decimal string.
  static Map<String, dynamic> markReadBody(BigInt upToSeq) =>
      {'upToSeq': upToSeq.toString()};
}
