import 'package:drop/features/chat/domain/entities/chat_message.dart';
import 'package:drop/features/chat/domain/repositories/chat_repository.dart';

/// Deletes a message for both participants — sender-only, inside the server's
/// time window (403 outside it). Returns the tombstoned placeholder message to
/// swap into the timeline. Idempotent.
class DeleteChatMessageForEveryone {
  final ChatRepository _repository;
  const DeleteChatMessageForEveryone(this._repository);

  Future<ChatMessage> call({
    required String conversationId,
    required String messageId,
  }) =>
      _repository.deleteMessageForEveryone(
        conversationId: conversationId,
        messageId: messageId,
      );
}
