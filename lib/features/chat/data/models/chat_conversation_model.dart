import 'package:opshub/features/chat/domain/entities/chat_conversation.dart';

/// JSON (de)serialization for conversations — the exact wire shapes of the
/// backend's `ConversationResponseDto` and `ConversationListItemResponseDto`
/// (`drop-api` · `chat/conversations/interface/http/dto/`). Field names are
/// verbatim from those DTOs; timestamps are ISO-8601 strings.
class ChatConversationModel {
  final String id;
  final List<String> participantIds;
  final DateTime createdAt;
  final DateTime? lastMessageAt;

  const ChatConversationModel({
    required this.id,
    required this.participantIds,
    required this.createdAt,
    this.lastMessageAt,
  });

  factory ChatConversationModel.fromJson(Map<String, dynamic> json) =>
      ChatConversationModel(
        id: json['id'] as String,
        participantIds: _stringList(json['participantIds']),
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastMessageAt: _optionalDate(json['lastMessageAt']),
      );

  ChatConversation toEntity() => ChatConversation(
        id: id,
        participantIds: participantIds,
        createdAt: createdAt,
        lastMessageAt: lastMessageAt,
      );

  // ─── Conversation list (`GET /conversations`) ─────────────────────────

  /// One list row — `ConversationListItemResponseDto` (adds the
  /// server-computed `counterpartUserId`).
  static ChatConversationSummary summaryFromJson(Map<String, dynamic> json) =>
      ChatConversationSummary(
        id: json['id'] as String,
        counterpartUserId: json['counterpartUserId'] as String,
        counterpartExternalId: json['counterpartExternalId'] as String?,
        participantIds: _stringList(json['participantIds']),
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastMessageAt: _optionalDate(json['lastMessageAt']),
        unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
        lastMessage: _lastMessage(json['lastMessage']),
      );

  /// Absent/null on a server that predates the preview field — the inbox then
  /// falls back to resolving previews itself, so this stays additive.
  static ChatLastMessage? _lastMessage(dynamic raw) {
    if (raw is! Map) return null;
    final json = raw.cast<String, dynamic>();
    final id = json['id'];
    final senderId = json['senderId'];
    if (id is! String || senderId is! String) return null;
    return ChatLastMessage(
      id: id,
      senderId: senderId,
      type: (json['type'] as String?) ?? 'TEXT',
      body: json['body'] as String?,
      deletedForEveryoneAt: _optionalDate(json['deletedForEveryoneAt']),
    );
  }

  /// A page — `ConversationListResponseDto` (`{items, nextCursor}`).
  static ChatConversationPage pageFromJson(Map<String, dynamic> json) =>
      ChatConversationPage(
        items: [
          for (final item in (json['items'] as List? ?? const []))
            summaryFromJson((item as Map).cast<String, dynamic>()),
        ],
        nextCursor: json['nextCursor'] as String?,
      );

  // ─── Shared field helpers ─────────────────────────────────────────────

  static List<String> _stringList(dynamic raw) =>
      raw is List ? raw.whereType<String>().toList() : const <String>[];

  static DateTime? _optionalDate(dynamic raw) =>
      raw is String && raw.isNotEmpty ? DateTime.parse(raw) : null;
}
