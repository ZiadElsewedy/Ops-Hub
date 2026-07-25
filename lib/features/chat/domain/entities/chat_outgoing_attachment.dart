import 'dart:typed_data';

import 'package:drop/core/enums/chat_attachment_format.dart';
import 'package:drop/core/enums/chat_attachment_kind.dart';

/// The attachment payload of an outgoing send — the client mirror of the
/// backend's `SendMessageAttachmentDto` (`drop-api` ·
/// `chat/messages/interface/http/dto/send-message.dto.ts`).
///
/// Declares a strict [ChatAttachmentFormat]; the kind is **derived** from it
/// ([ChatAttachmentFormat.kind]) so a send can never declare the mismatched
/// (kind, format) pair the server rejects. [bytes] are raw file bytes — the
/// data layer base64-encodes them into the JSON body (the backend's chosen
/// transport; no multipart).
class ChatOutgoingAttachment {
  const ChatOutgoingAttachment({
    required this.format,
    required this.mimeType,
    required this.originalFilename,
    required this.bytes,
  });

  final ChatAttachmentFormat format;
  final String mimeType;
  final String originalFilename;
  final Uint8List bytes;

  ChatAttachmentKind get kind => format.kind;
}
