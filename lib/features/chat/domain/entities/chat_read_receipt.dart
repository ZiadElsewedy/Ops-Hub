/// The result of a mark-messages-read call — the client mirror of the
/// backend's `MarkMessagesReadResponseDto`. [markedCount] is how many messages
/// newly transitioned to read; 0 on an idempotent replay (still a success).
class ChatReadReceipt {
  const ChatReadReceipt({
    required this.conversationId,
    required this.markedCount,
    required this.readAt,
  });

  final String conversationId;
  final int markedCount;
  final DateTime readAt;
}
