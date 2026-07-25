import 'package:drop/features/chat/domain/entities/chat_conversation.dart';
import 'package:drop/features/chat/domain/repositories/chat_repository.dart';

/// Reads the locally-cached conversation list (no network) so the inbox can
/// paint instantly on a cold start while [GetConversations] refreshes from the
/// server. Returns an empty list when nothing is cached.
class GetCachedConversations {
  final ChatRepository _repository;
  const GetCachedConversations(this._repository);

  Future<List<ChatConversationSummary>> call() =>
      _repository.getCachedConversations();
}
