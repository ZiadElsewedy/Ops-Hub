import 'package:drop/features/chat/domain/repositories/chat_repository.dart';

/// Removes a message from the caller's view only — the other participant still
/// sees it. Idempotent.
class DeleteChatMessageForMe {
  final ChatRepository _repository;
  const DeleteChatMessageForMe(this._repository);

  Future<void> call({
    required String conversationId,
    required String messageId,
  }) =>
      _repository.deleteMessageForMe(
        conversationId: conversationId,
        messageId: messageId,
      );
}
