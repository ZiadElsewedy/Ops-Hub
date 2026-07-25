import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/chat_attachment_kind.dart';
import 'package:drop/core/enums/chat_message_type.dart';
import 'package:drop/features/chat/domain/entities/chat_conversation.dart';
import 'package:drop/features/chat/domain/entities/chat_message.dart';
import 'package:drop/features/chat/domain/repositories/chat_repository.dart';
import 'package:drop/features/chat/domain/usecases/delete_chat_message_for_everyone.dart';
import 'package:drop/features/chat/domain/usecases/delete_chat_message_for_me.dart';
import 'package:drop/features/chat/domain/usecases/get_conversation.dart';
import 'package:drop/features/chat/domain/usecases/load_chat_history.dart';
import 'package:drop/features/chat/domain/usecases/mark_chat_read.dart';
import 'package:drop/features/chat/domain/usecases/send_chat_message.dart';
import 'package:drop/features/chat/presentation/cubit/chat_conversation_cubit.dart';

const _conv = 'c1';
const _me = 'me';
const _them = 'them';

ChatMessage _msg(int seq, {ChatMessageAttachment? attachment}) => ChatMessage(
      id: 'm$seq',
      conversationId: _conv,
      senderId: _them,
      type: attachment == null
          ? ChatMessageType.text
          : (attachment.kind.isImage
              ? ChatMessageType.image
              : ChatMessageType.document),
      body: attachment == null ? 'message $seq' : null,
      attachment: attachment,
      seq: BigInt.from(seq),
      status: 'SENT',
      createdAt: DateTime(2026, 7, 24, 10, seq),
    );

ChatMessageAttachment _att(ChatAttachmentKind kind) => ChatMessageAttachment(
      id: 'att-${kind.name}',
      kind: kind,
      format: kind.isImage ? 'JPG' : 'PDF',
      mimeType: kind.isImage ? 'image/jpeg' : 'application/pdf',
      originalFilename: kind.isImage ? 'photo.jpg' : 'report.pdf',
      byteSize: 1024,
    );

class _FakeRepo implements ChatRepository {
  final List<String> deletedForMe = [];

  @override
  Future<ChatConversation> getConversation(String conversationId) async =>
      ChatConversation(
        id: _conv,
        participantIds: const [_me, _them],
        createdAt: DateTime(2026, 7, 20),
      );

  @override
  Future<ChatMessagePage> getMessageHistory({
    required String conversationId,
    int? limit,
    String? cursor,
  }) async =>
      ChatMessagePage(items: [
        _msg(1),
        _msg(2),
        _msg(3, attachment: _att(ChatAttachmentKind.image)),
        _msg(4, attachment: _att(ChatAttachmentKind.document)),
      ]);

  @override
  Future<void> deleteMessageForMe({
    required String conversationId,
    required String messageId,
  }) async {
    deletedForMe.add(messageId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

ChatConversationCubit _cubit(_FakeRepo repo) => ChatConversationCubit(
      getConversation: GetConversation(repo),
      loadHistory: LoadChatHistory(repo),
      sendMessage: SendChatMessage(repo),
      markRead: MarkChatRead(repo),
      deleteForMe: DeleteChatMessageForMe(repo),
      deleteForEveryone: DeleteChatMessageForEveryone(repo),
      conversationId: _conv,
      counterpartUserId: _them,
    );

List<ChatMessage> _messagesOf(ChatConversationCubit c) => c.state.maybeMap(
    loaded: (s) => s.messages, orElse: () => const <ChatMessage>[]);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('sharedAttachmentCounts counts media and documents in the window',
      () async {
    final cubit = _cubit(_FakeRepo());
    await _settle();
    final counts = cubit.sharedAttachmentCounts;
    expect(counts.media, 1);
    expect(counts.documents, 1);
    await cubit.close();
  });

  test('clearChatForMe deletes every loaded message for me and empties the list',
      () async {
    final repo = _FakeRepo();
    final cubit = _cubit(repo);
    await _settle();
    expect(_messagesOf(cubit), hasLength(4));

    final ok = await cubit.clearChatForMe();
    expect(ok, isTrue);
    expect(repo.deletedForMe.toSet(), {'m1', 'm2', 'm3', 'm4'});
    expect(_messagesOf(cubit), isEmpty);
    await cubit.close();
  });
}
