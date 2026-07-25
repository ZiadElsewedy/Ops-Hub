import 'package:drop/features/chat/domain/entities/chat_message.dart';
import 'package:drop/features/chat/domain/repositories/chat_repository.dart';

/// Loads a page of a conversation's history (newest page first; pass the
/// previous page's `nextCursor` to page back through older messages). Loading
/// history does NOT mark anything read — that's an explicit, separate signal
/// (`MarkChatRead`) fired when messages are actually visible.
class LoadChatHistory {
  final ChatRepository _repository;
  const LoadChatHistory(this._repository);

  Future<ChatMessagePage> call({
    required String conversationId,
    int? limit,
    String? cursor,
  }) =>
      _repository.getMessageHistory(
        conversationId: conversationId,
        limit: limit,
        cursor: cursor,
      );
}
