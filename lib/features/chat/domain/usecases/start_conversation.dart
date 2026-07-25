import 'package:drop/features/chat/domain/entities/chat_conversation.dart';
import 'package:drop/features/chat/domain/repositories/chat_repository.dart';

/// Starts (get-or-creates) the 1:1 conversation with another user — the entry
/// point for "message this person". Idempotent per pair.
class StartConversation {
  final ChatRepository _repository;
  const StartConversation(this._repository);

  Future<ChatConversation> call(String targetUserId) =>
      _repository.startConversation(targetUserId);
}
