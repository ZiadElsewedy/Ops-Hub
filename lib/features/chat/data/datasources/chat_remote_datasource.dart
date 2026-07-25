import 'package:drop/core/network/api_client.dart';
import 'package:drop/features/chat/data/models/chat_attachment_download_model.dart';
import 'package:drop/features/chat/data/models/chat_conversation_model.dart';
import 'package:drop/features/chat/data/models/chat_message_model.dart';
import 'package:drop/features/chat/domain/entities/chat_attachment_download.dart';
import 'package:drop/features/chat/domain/entities/chat_conversation.dart';
import 'package:drop/features/chat/domain/entities/chat_message.dart';
import 'package:drop/features/chat/domain/entities/chat_outgoing_attachment.dart';
import 'package:drop/features/chat/domain/entities/chat_read_receipt.dart';

/// Remote surface of the chat REST API. Thin by design — every method is one
/// [ApiClient] call plus one model parse. Paths mirror the backend controllers
/// verbatim (`ConversationsController` · `MessagesController`); auth, timeouts
/// and error translation are owned by [ApiClient] (failures arrive as the
/// `core/errors` exceptions, never Dio types).
abstract class ChatRemoteDataSource {
  Future<ChatConversationModel> createConversation(String targetUserId);
  Future<ChatConversationPage> listConversations({int? limit, String? cursor});
  Future<ChatConversationModel> getConversation(String conversationId);

  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String idempotencyKey,
    String? content,
    ChatOutgoingAttachment? attachment,
    String? replyToMessageId,
    void Function(int sent, int total)? onSendProgress,
  });

  Future<ChatMessagePage> loadHistory({
    required String conversationId,
    int? limit,
    String? cursor,
  });

  Future<ChatReadReceipt> markRead({
    required String conversationId,
    required BigInt upToSeq,
  });

  Future<void> deleteForMe({
    required String conversationId,
    required String messageId,
  });

  Future<ChatMessage> deleteForEveryone({
    required String conversationId,
    required String messageId,
  });

  Future<ChatAttachmentDownload> getAttachmentDownloadUrl({
    required String conversationId,
    required String messageId,
  });
}

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  final ApiClient _api;

  ChatRemoteDataSourceImpl(this._api);

  static String _messages(String conversationId) =>
      '/conversations/$conversationId/messages';

  static Map<String, dynamic>? _pageQuery(int? limit, String? cursor) {
    final query = <String, dynamic>{
      'limit': ?limit,
      'cursor': ?cursor,
    };
    return query.isEmpty ? null : query;
  }

  static Map<String, dynamic> _asJson(dynamic data) =>
      (data as Map).cast<String, dynamic>();

  // ─── Conversations ────────────────────────────────────────────────────

  @override
  Future<ChatConversationModel> createConversation(String targetUserId) async {
    final data = await _api.post(
      '/conversations',
      body: {'targetUserId': targetUserId},
    );
    return ChatConversationModel.fromJson(_asJson(data));
  }

  @override
  Future<ChatConversationPage> listConversations({
    int? limit,
    String? cursor,
  }) async {
    final data =
        await _api.get('/conversations', query: _pageQuery(limit, cursor));
    return ChatConversationModel.pageFromJson(_asJson(data));
  }

  @override
  Future<ChatConversationModel> getConversation(String conversationId) async {
    final data = await _api.get('/conversations/$conversationId');
    return ChatConversationModel.fromJson(_asJson(data));
  }

  // ─── Messages ─────────────────────────────────────────────────────────

  @override
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String idempotencyKey,
    String? content,
    ChatOutgoingAttachment? attachment,
    String? replyToMessageId,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final data = await _api.post(
      _messages(conversationId),
      body: ChatMessageModel.sendBody(
        idempotencyKey: idempotencyKey,
        content: content,
        attachment: attachment,
        replyToMessageId: replyToMessageId,
      ),
      onSendProgress: onSendProgress,
    );
    return ChatMessageModel.fromJson(_asJson(data));
  }

  @override
  Future<ChatMessagePage> loadHistory({
    required String conversationId,
    int? limit,
    String? cursor,
  }) async {
    final data = await _api.get(
      _messages(conversationId),
      query: _pageQuery(limit, cursor),
    );
    return ChatMessageModel.pageFromJson(_asJson(data));
  }

  @override
  Future<ChatReadReceipt> markRead({
    required String conversationId,
    required BigInt upToSeq,
  }) async {
    final data = await _api.post(
      '${_messages(conversationId)}/read',
      body: ChatMessageModel.markReadBody(upToSeq),
    );
    return ChatMessageModel.readReceiptFromJson(_asJson(data));
  }

  @override
  Future<void> deleteForMe({
    required String conversationId,
    required String messageId,
  }) async {
    // Response (`DeleteForMeResponseDto`) is a pure ack — nothing to parse.
    await _api.delete('${_messages(conversationId)}/$messageId');
  }

  @override
  Future<ChatMessage> deleteForEveryone({
    required String conversationId,
    required String messageId,
  }) async {
    final data = await _api
        .delete('${_messages(conversationId)}/$messageId/for-everyone');
    return ChatMessageModel.fromJson(_asJson(data));
  }

  @override
  Future<ChatAttachmentDownload> getAttachmentDownloadUrl({
    required String conversationId,
    required String messageId,
  }) async {
    final data =
        await _api.get('${_messages(conversationId)}/$messageId/attachment');
    return ChatAttachmentDownloadModel.fromJson(_asJson(data));
  }
}
