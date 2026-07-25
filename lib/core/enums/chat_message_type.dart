/// The kind of a chat message — mirrors the backend's `MessageType` enum
/// (`drop-api` · `chat/messages/domain/message-type.ts`). Wire values are the
/// backend's exact uppercase strings (`TEXT` / `IMAGE` / `DOCUMENT`); the
/// mapping lives here so models never hand-roll string comparisons.
enum ChatMessageType {
  text,
  image,
  document;

  /// The exact wire value the API sends/expects.
  String get value => name.toUpperCase();

  bool get isText => this == ChatMessageType.text;
  bool get hasAttachment => this != ChatMessageType.text;

  /// Tolerant parse (case-insensitive). Falls back to [text] so an unknown
  /// value from a newer server degrades to a renderable message instead of
  /// crashing deserialization.
  static ChatMessageType fromString(String? raw) {
    final needle = raw?.trim().toUpperCase();
    for (final type in ChatMessageType.values) {
      if (type.value == needle) return type;
    }
    return ChatMessageType.text;
  }
}
