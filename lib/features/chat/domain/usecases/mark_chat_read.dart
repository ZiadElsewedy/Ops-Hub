import 'package:drop/features/chat/domain/entities/chat_read_receipt.dart';
import 'package:drop/features/chat/domain/repositories/chat_repository.dart';

/// Marks a conversation read up to the highest **visible** message's seq — the
/// opened-and-visible signal, not a side effect of fetching. Idempotent.
class MarkChatRead {
  final ChatRepository _repository;
  const MarkChatRead(this._repository);

  Future<ChatReadReceipt> call({
    required String conversationId,
    required BigInt upToSeq,
  }) =>
      _repository.markMessagesRead(
        conversationId: conversationId,
        upToSeq: upToSeq,
      );
}
