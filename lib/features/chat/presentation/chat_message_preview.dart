import 'package:drop/features/chat/domain/entities/chat_message.dart';

/// A one-line textual preview of a message's content — the body when there is
/// one, otherwise the attachment's filename, otherwise a generic label. Shared
/// by the reply-quote block in a bubble and the "Replying to …" composer banner
/// so both render the same snippet from the same rule.
String chatReplySnippet({String? body, ChatMessageAttachment? attachment}) {
  final text = (body ?? '').trim();
  if (text.isNotEmpty) return text;
  if (attachment != null) return attachment.originalFilename;
  return 'Attachment';
}

/// A compact human-readable byte size (binary units): `842 B`, `12 KB`, `3.4 MB`.
String chatHumanBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
}
