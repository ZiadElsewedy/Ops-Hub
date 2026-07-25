import 'package:drop/features/chat/domain/entities/chat_conversation.dart';
import 'package:drop/features/chat/domain/repositories/chat_repository.dart';

/// Loads a single conversation the caller participates in (e.g. when deep
/// linking straight into a thread).
class GetConversation {
  final ChatRepository _repository;
  const GetConversation(this._repository);

  Future<ChatConversation> call(String conversationId) =>
      _repository.getConversation(conversationId);
}
