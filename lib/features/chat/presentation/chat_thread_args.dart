import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/chat/domain/entities/chat_conversation.dart';
import 'package:opshub/features/chat/presentation/chat_format.dart';

/// Navigation payload for opening a chat thread (`/chat/:conversationId`
/// route `extra`). Carries the resolved counterpart profile so the thread can
/// show a real name + avatar in its header without a round trip — the backend
/// exposes no name for the counterpart id, so the opener (inbox tile / picker),
/// which already resolved the teammate from the Firebase directory, passes it
/// along. A bare deep link arrives without this and falls back to a generic
/// label.
class ChatThreadArgs {
  const ChatThreadArgs({
    this.counterpartUserId,
    this.counterpartExternalId,
    this.counterpartName,
    this.counterpartPhotoUrl,
    this.counterpartRoleLine,
  });

  /// The counterpart's **backend-internal** id — for own-message alignment
  /// before the first send (never shown to the user).
  final String? counterpartUserId;

  /// The counterpart's OpsHub user id (Firebase uid) — the directory key, so the
  /// Conversation Info screen can resolve their role/branch. Null on a bare
  /// deep link.
  final String? counterpartExternalId;

  /// The counterpart's real display name (from the Firebase directory).
  final String? counterpartName;

  /// The counterpart's avatar URL, if any.
  final String? counterpartPhotoUrl;

  /// Counterpart position and role, already formatted for the compact thread
  /// header (for example, `Floor Lead · Employee`).
  final String? counterpartRoleLine;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatThreadArgs &&
          counterpartUserId == other.counterpartUserId &&
          counterpartExternalId == other.counterpartExternalId &&
          counterpartName == other.counterpartName &&
          counterpartPhotoUrl == other.counterpartPhotoUrl &&
          counterpartRoleLine == other.counterpartRoleLine;

  @override
  int get hashCode => Object.hash(
        counterpartUserId,
        counterpartExternalId,
        counterpartName,
        counterpartPhotoUrl,
        counterpartRoleLine,
      );
}

/// Resolves the thread header from an inbox row and the session directory.
/// Both are already available locally on a cache-painted inbox; no API call is
/// needed to draw the counterpart identity.
ChatThreadArgs chatThreadArgsFromSummary(
  ChatConversationSummary summary,
  Map<String, UserEntity> directory,
) {
  final user = summary.counterpartExternalId == null
      ? null
      : directory[summary.counterpartExternalId];
  final role = user == null ? null : chatRoleLabel(user.role);
  final position = user?.position?.trim();
  return ChatThreadArgs(
    counterpartUserId: summary.counterpartUserId,
    counterpartExternalId: summary.counterpartExternalId,
    counterpartName: chatDisplayName(
      user,
      fallbackId: summary.counterpartUserId,
    ),
    counterpartPhotoUrl: user?.photoUrl,
    counterpartRoleLine: role == null
        ? null
        : position == null || position.isEmpty ? role : '$position · $role',
  );
}
