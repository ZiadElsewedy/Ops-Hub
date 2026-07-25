/// A brokered, short-lived attachment download — the client mirror of the
/// backend's `AttachmentDownloadResponseDto`. Fetch the bytes directly from
/// [url] until [expiresAt]; after that, request a fresh URL (the storage
/// locator itself is never exposed by the API).
class ChatAttachmentDownload {
  const ChatAttachmentDownload({
    required this.url,
    required this.expiresAt,
  });

  final String url;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt.toUtc());
}
