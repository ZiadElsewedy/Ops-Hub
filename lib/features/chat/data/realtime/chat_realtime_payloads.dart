import 'package:drop/features/chat/data/models/chat_message_model.dart';
import 'package:drop/features/chat/domain/chat_realtime.dart';

/// Wire → domain parsing for the server-emitted socket payloads — the exact
/// shapes in `drop-api` · `chat/realtime/interface/socket/chat-events.ts`.
/// Kept as pure top-level functions so the protocol surface is unit-testable
/// without a socket. `message:new` reuses [ChatMessageModel]: the server
/// serializes the live payload with the same DTO mapper as REST history, so
/// one parser covers both.
ChatMessageReceived parseMessageNew(Map<String, dynamic> json) =>
    ChatMessageReceived(ChatMessageModel.fromJson(json));

ChatMessagesReadReceived parseMessageRead(Map<String, dynamic> json) =>
    ChatMessagesReadReceived(
      conversationId: json['conversationId'] as String,
      readerId: json['readerId'] as String,
      messageIds: [
        for (final id in (json['messageIds'] as List? ?? const []))
          if (id is String) id,
      ],
      readAt: DateTime.parse(json['readAt'] as String),
    );

ChatMessageDeletedReceived parseMessageDeleted(Map<String, dynamic> json) =>
    ChatMessageDeletedReceived(
      conversationId: json['conversationId'] as String,
      messageId: json['messageId'] as String,
      deletedBy: json['deletedBy'] as String,
      deletedAt: DateTime.parse(json['deletedAt'] as String),
    );

ChatMessageHiddenReceived parseMessageDeletedForMe(
        Map<String, dynamic> json) =>
    ChatMessageHiddenReceived(
      conversationId: json['conversationId'] as String,
      messageId: json['messageId'] as String,
      deletedAt: DateTime.parse(json['deletedAt'] as String),
    );
