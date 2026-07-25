import 'package:drop/features/chat/domain/entities/chat_attachment_download.dart';
import 'package:drop/features/chat/domain/repositories/chat_repository.dart';

/// Fetches a short-lived download URL for a message's attachment. The bytes
/// are then fetched directly from that URL; request a fresh one once expired.
class GetChatAttachmentUrl {
  final ChatRepository _repository;
  const GetChatAttachmentUrl(this._repository);

  Future<ChatAttachmentDownload> call({
    required String conversationId,
    required String messageId,
  }) =>
      _repository.getAttachmentDownloadUrl(
        conversationId: conversationId,
        messageId: messageId,
      );
}
