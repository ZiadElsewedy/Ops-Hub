import 'package:drop/features/chat/domain/entities/chat_attachment_download.dart';

/// JSON deserialization for the brokered attachment download — the exact wire
/// shape of the backend's `AttachmentDownloadResponseDto`
/// (`{url, expiresAt}`, ISO-8601 expiry).
class ChatAttachmentDownloadModel {
  const ChatAttachmentDownloadModel._();

  static ChatAttachmentDownload fromJson(Map<String, dynamic> json) =>
      ChatAttachmentDownload(
        url: json['url'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );
}
