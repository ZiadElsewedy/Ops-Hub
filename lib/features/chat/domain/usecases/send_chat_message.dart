import 'package:drop/features/chat/domain/entities/chat_message.dart';
import 'package:drop/features/chat/domain/entities/chat_outgoing_attachment.dart';
import 'package:drop/features/chat/domain/repositories/chat_repository.dart';

/// Sends one message — text, attachment, or both. The caller owns the
/// [idempotencyKey] (a UUID minted once per logical send and reused on retry,
/// so a flaky network can never duplicate a message).
class SendChatMessage {
  final ChatRepository _repository;
  const SendChatMessage(this._repository);

  Future<ChatMessage> call({
    required String conversationId,
    required String idempotencyKey,
    String? content,
    ChatOutgoingAttachment? attachment,
    String? replyToMessageId,
    void Function(int sent, int total)? onSendProgress,
  }) =>
      _repository.sendMessage(
        conversationId: conversationId,
        idempotencyKey: idempotencyKey,
        content: content,
        attachment: attachment,
        replyToMessageId: replyToMessageId,
        onSendProgress: onSendProgress,
      );
}
