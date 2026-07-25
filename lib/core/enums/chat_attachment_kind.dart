/// The high-level category of a chat attachment — mirrors the backend's
/// `AttachmentKind` enum (`drop-api` · `chat/attachments/domain/attachment-kind.ts`).
/// V1 supports exactly two kinds; audio/video are out of scope server-side.
enum ChatAttachmentKind {
  image,
  document;

  /// The exact wire value the API sends/expects (`IMAGE` / `DOCUMENT`).
  String get value => name.toUpperCase();

  bool get isImage => this == ChatAttachmentKind.image;

  /// Tolerant parse (case-insensitive). Falls back to [document] — the generic
  /// "file" rendering — so an unknown kind from a newer server degrades to an
  /// icon + filename row instead of crashing deserialization.
  static ChatAttachmentKind fromString(String? raw) {
    final needle = raw?.trim().toUpperCase();
    for (final kind in ChatAttachmentKind.values) {
      if (kind.value == needle) return kind;
    }
    return ChatAttachmentKind.document;
  }
}
