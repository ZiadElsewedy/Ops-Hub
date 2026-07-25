import 'package:drop/core/enums/user_role.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/chat/domain/entities/chat_message.dart';

/// Presentation-side formatting for the chat feature (the `case_format.dart`
/// sibling). Pure functions only.

/// A neutral fallback label for a conversation counterpart, used only when the
/// real profile can't be resolved from the directory (a deep link before the
/// directory has loaded). **Never derived from any id** — a Firebase uid or
/// internal user id is an implementation detail and must not surface in the UI,
/// even as a truncated tag. The directory resolves the real name in practice;
/// this is just a graceful, id-free placeholder.
String chatCounterpartLabel(String counterpartUserId) => 'Teammate';

/// The best display name for a resolved teammate — their display name, else
/// email, else the deterministic fallback tag for [fallbackId].
String chatDisplayName(UserEntity? user, {required String fallbackId}) {
  if (user == null) return chatCounterpartLabel(fallbackId);
  final name = user.displayName?.trim();
  if (name != null && name.isNotEmpty) return name;
  final email = user.email.trim();
  if (email.isNotEmpty) return email;
  return chatCounterpartLabel(fallbackId);
}

/// Human-readable role label, local to chat so the feature stays self-contained.
String chatRoleLabel(UserRole role) => switch (role) {
      UserRole.admin => 'Admin',
      UserRole.manager => 'Store Manager',
      UserRole.employee => 'Employee',
    };

/// A resolved inbox preview: the last message's text plus whether it was the
/// caller's own message (rendered with a "You: " prefix, WhatsApp-style).
class ChatPreview {
  const ChatPreview(this.text, {this.mine = false});
  final String text;
  final bool mine;

  /// The line as shown in the inbox row — prefixed with "You: " for own
  /// messages so a glance tells you who spoke last.
  String get line => mine && text.isNotEmpty ? 'You: $text' : text;
}

/// The preview text for one message: its body, else "Photo" for an image or the
/// file name for a document, else the tombstone for a deleted message. Never a
/// "no messages"/"tap to open" placeholder — the inbox only shows conversations
/// that actually have a message, so there is always something real to preview.
String chatMessagePreviewText(ChatMessage message) {
  if (message.deletedForEveryone) return chatDeletedForEveryonePlaceholder;
  final body = (message.body ?? '').trim();
  if (body.isNotEmpty) return body;
  final attachment = message.attachment;
  if (attachment != null) {
    return attachment.kind.isImage ? 'Photo' : attachment.originalFilename;
  }
  return '';
}
