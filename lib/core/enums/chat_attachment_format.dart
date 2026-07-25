import 'package:drop/core/enums/chat_attachment_kind.dart';

/// The concrete file format of an **outgoing** chat attachment — mirrors the
/// backend's `AttachmentFormat` enum and its kind/format agreement rule
/// (`drop-api` · `chat/attachments/domain/attachment-format.ts` +
/// `attachment-validation.ts`, AR-1/AR-2). These are the only formats the
/// server accepts in V1; declaring them client-side lets the picker reject an
/// unsupported file before uploading bytes.
///
/// Note: **received** attachments carry their format as a raw string (see
/// `ChatMessageAttachment.format`) so a newer server adding formats can never
/// break deserialization of history.
enum ChatAttachmentFormat {
  // Images (AR-1).
  jpg,
  jpeg,
  png,
  // Documents (AR-2).
  pdf,
  doc,
  docx,
  xls,
  xlsx,
  ppt,
  pptx,
  txt,
  zip;

  /// The exact wire value the API expects (`JPG`, `PDF`, …).
  String get value => name.toUpperCase();

  /// The kind this format belongs to — the client-side mirror of the backend's
  /// `kindOfFormat`, so a send can never declare a mismatched (kind, format)
  /// pair (the server would reject it with a 400 anyway).
  ChatAttachmentKind get kind => switch (this) {
        jpg || jpeg || png => ChatAttachmentKind.image,
        _ => ChatAttachmentKind.document,
      };

  /// Resolves a format from a filename extension (e.g. `report.PDF` → [pdf]).
  /// Returns null for anything the server does not accept — the caller should
  /// surface "unsupported file type" instead of attempting the upload.
  static ChatAttachmentFormat? fromExtension(String? extension) {
    final needle = extension?.trim().toLowerCase().replaceFirst('.', '');
    if (needle == null || needle.isEmpty) return null;
    for (final format in ChatAttachmentFormat.values) {
      if (format.name == needle) return format;
    }
    return null;
  }
}
