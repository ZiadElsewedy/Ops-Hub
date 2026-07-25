import 'package:drop/features/chat/domain/entities/chat_conversation.dart';
import 'package:drop/features/chat/domain/repositories/chat_repository.dart';

/// Loads a page of the caller's conversation list, most-recent-activity first.
/// Pass the previous page's `nextCursor` to load the next page.
class GetConversations {
  final ChatRepository _repository;
  const GetConversations(this._repository);

  Future<ChatConversationPage> call({int? limit, String? cursor}) =>
      _repository.getConversations(limit: limit, cursor: cursor);
}
