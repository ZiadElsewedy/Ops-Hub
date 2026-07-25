import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/chat_message_type.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/features/chat/domain/entities/chat_attachment_download.dart';
import 'package:drop/features/chat/domain/entities/chat_conversation.dart';
import 'package:drop/features/chat/domain/entities/chat_message.dart';
import 'package:drop/features/chat/domain/entities/chat_outgoing_attachment.dart';
import 'package:drop/features/chat/domain/entities/chat_read_receipt.dart';
import 'package:drop/features/chat/domain/repositories/chat_repository.dart';
import 'package:drop/features/chat/domain/usecases/delete_chat_message_for_everyone.dart';
import 'package:drop/features/chat/domain/usecases/delete_chat_message_for_me.dart';
import 'package:drop/features/chat/domain/usecases/get_conversation.dart';
import 'package:drop/features/chat/domain/usecases/load_chat_history.dart';
import 'package:drop/features/chat/domain/usecases/mark_chat_read.dart';
import 'package:drop/features/chat/domain/usecases/send_chat_message.dart';
import 'package:drop/features/chat/presentation/cubit/chat_conversation_cubit.dart';
import 'package:drop/features/chat/presentation/widgets/chat_conversation_view.dart';

const _me = 'me-uuid';
const _them = 'them-uuid';
const _convId = 'conv-1';

ChatMessage _message(String id, int seq, String sender, String body,
        {bool deleted = false}) =>
    ChatMessage(
      id: id,
      conversationId: _convId,
      senderId: sender,
      type: ChatMessageType.text,
      body: deleted ? chatDeletedForEveryonePlaceholder : body,
      seq: BigInt.from(seq),
      status: 'SENT',
      createdAt: DateTime(2026, 7, 22, 9, seq),
      deletedForEveryone: deleted,
    );

class _FakeChatRepository implements ChatRepository {
  @override
  Future<List<ChatConversationSummary>> getCachedConversations() async =>
      const [];

  _FakeChatRepository({
    required this.messages,
    this.onDeleteForMe,
    this.onDeleteForEveryone,
  });

  final List<ChatMessage> messages;
  final Future<void> Function(String messageId)? onDeleteForMe;
  final Future<ChatMessage> Function(String messageId)? onDeleteForEveryone;

  @override
  Future<ChatConversation> getConversation(String conversationId) async =>
      ChatConversation(
        id: _convId,
        participantIds: const [_me, _them],
        createdAt: DateTime(2026, 7, 20),
      );

  @override
  Future<ChatMessagePage> getMessageHistory({
    required String conversationId,
    int? limit,
    String? cursor,
  }) async =>
      ChatMessagePage(items: messages);

  @override
  Future<void> deleteMessageForMe(
      {required String conversationId, required String messageId}) {
    final handler = onDeleteForMe;
    if (handler == null) throw UnimplementedError();
    return handler(messageId);
  }

  @override
  Future<ChatMessage> deleteMessageForEveryone(
      {required String conversationId, required String messageId}) {
    final handler = onDeleteForEveryone;
    if (handler == null) throw UnimplementedError();
    return handler(messageId);
  }

  @override
  Future<ChatReadReceipt> markMessagesRead({
    required String conversationId,
    required BigInt upToSeq,
  }) async =>
      ChatReadReceipt(
          conversationId: conversationId,
          markedCount: 0,
          readAt: DateTime(2026, 7, 22));

  @override
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String idempotencyKey,
    String? content,
    ChatOutgoingAttachment? attachment,
    String? replyToMessageId,
    void Function(int sent, int total)? onSendProgress,
  }) =>
      throw UnimplementedError();

  @override
  Future<ChatConversation> startConversation(String targetUserId) =>
      throw UnimplementedError();

  @override
  Future<ChatConversationPage> getConversations(
          {int? limit, String? cursor}) =>
      throw UnimplementedError();

  @override
  Future<ChatAttachmentDownload> getAttachmentDownloadUrl(
          {required String conversationId, required String messageId}) =>
      throw UnimplementedError();
}

ChatConversationCubit _cubit(_FakeChatRepository repo) => ChatConversationCubit(
      getConversation: GetConversation(repo),
      loadHistory: LoadChatHistory(repo),
      sendMessage: SendChatMessage(repo),
      markRead: MarkChatRead(repo),
      deleteForMe: DeleteChatMessageForMe(repo),
      deleteForEveryone: DeleteChatMessageForEveryone(repo),
      conversationId: _convId,
      counterpartUserId: _them,
    );

Widget _host(ChatConversationCubit cubit) => MaterialApp(
      home: Scaffold(
        body: BlocProvider.value(
            value: cubit, child: const ChatConversationView()),
      ),
    );

Future<void> _openMenu(WidgetTester tester, String bubbleText) async {
  await tester.longPress(find.text(bubbleText));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'long-press on my own message offers both delete actions; '
      'a received message offers only Delete for me', (tester) async {
    final repo = _FakeChatRepository(messages: [
      _message('m1', 1, _me, 'Mine'),
      _message('m2', 2, _them, 'Theirs'),
    ]);
    final cubit = _cubit(repo);
    await tester.pumpWidget(_host(cubit));
    await tester.pump();
    await tester.pump();

    await _openMenu(tester, 'Mine');
    expect(find.text('Delete for me'), findsOneWidget);
    expect(find.text('Delete for everyone'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10)); // dismiss the sheet
    await tester.pumpAndSettle();

    await _openMenu(tester, 'Theirs');
    expect(find.text('Delete for me'), findsOneWidget);
    expect(find.text('Delete for everyone'), findsNothing);
    await cubit.close();
  });

  testWidgets('an already-tombstoned message never offers Delete for everyone',
      (tester) async {
    final repo = _FakeChatRepository(messages: [
      _message('m1', 1, _me, '', deleted: true),
    ]);
    final cubit = _cubit(repo);
    await tester.pumpWidget(_host(cubit));
    await tester.pump();
    await tester.pump();

    await _openMenu(tester, chatDeletedForEveryonePlaceholder);
    expect(find.text('Delete for me'), findsOneWidget);
    expect(find.text('Delete for everyone'), findsNothing);
    await cubit.close();
  });

  testWidgets('Delete for me removes the message after confirmation',
      (tester) async {
    final deleted = <String>[];
    final repo = _FakeChatRepository(
      messages: [
        _message('m1', 1, _them, 'Keep this'),
        _message('m2', 2, _them, 'Hide this'),
      ],
      onDeleteForMe: (id) async => deleted.add(id),
    );
    final cubit = _cubit(repo);
    await tester.pumpWidget(_host(cubit));
    await tester.pump();
    await tester.pump();

    await _openMenu(tester, 'Hide this');
    await tester.tap(find.text('Delete for me'));
    await tester.pumpAndSettle();
    expect(find.text('Delete for me?'), findsOneWidget); // confirmation
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(deleted, ['m2']);
    expect(find.text('Hide this'), findsNothing);
    expect(find.text('Keep this'), findsOneWidget);
    await cubit.close();
  });

  testWidgets('cancelling the confirmation performs nothing', (tester) async {
    final deleted = <String>[];
    final repo = _FakeChatRepository(
      messages: [_message('m1', 1, _them, 'Precious')],
      onDeleteForMe: (id) async => deleted.add(id),
    );
    final cubit = _cubit(repo);
    await tester.pumpWidget(_host(cubit));
    await tester.pump();
    await tester.pump();

    await _openMenu(tester, 'Precious');
    await tester.tap(find.text('Delete for me'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(deleted, isEmpty);
    expect(find.text('Precious'), findsOneWidget);
    await cubit.close();
  });

  testWidgets(
      'Delete for everyone swaps in the server tombstone (italic placeholder)',
      (tester) async {
    final repo = _FakeChatRepository(
      messages: [_message('m1', 1, _me, 'Sent in haste')],
      onDeleteForEveryone: (id) async => _message('m1', 1, _me, '', deleted: true),
    );
    final cubit = _cubit(repo);
    await tester.pumpWidget(_host(cubit));
    await tester.pump();
    await tester.pump();

    await _openMenu(tester, 'Sent in haste');
    await tester.tap(find.text('Delete for everyone'));
    await tester.pumpAndSettle();
    expect(find.text('Delete for everyone?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Sent in haste'), findsNothing);
    final placeholder =
        tester.widget<Text>(find.text(chatDeletedForEveryonePlaceholder));
    expect(placeholder.style?.fontStyle, FontStyle.italic);
    await cubit.close();
  });

  testWidgets(
      'a server refusal (403 outside the window) keeps the message and '
      'surfaces the server message', (tester) async {
    final repo = _FakeChatRepository(
      messages: [_message('m1', 1, _me, 'Too old now')],
      onDeleteForEveryone: (id) async => throw const ServerFailure(
          'The time window for deleting this message for everyone has passed.'),
    );
    final cubit = _cubit(repo);
    await tester.pumpWidget(_host(cubit));
    await tester.pump();
    await tester.pump();

    await _openMenu(tester, 'Too old now');
    await tester.tap(find.text('Delete for everyone'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Too old now'), findsOneWidget); // unchanged
    expect(
        find.text(
            'The time window for deleting this message for everyone has passed.'),
        findsOneWidget); // snackbar with the server's own words
    await cubit.close();
  });

  testWidgets('a failed Delete for me keeps the message and shows the error',
      (tester) async {
    final repo = _FakeChatRepository(
      messages: [_message('m1', 1, _them, 'Sticky')],
      onDeleteForMe: (id) async =>
          throw const ServerFailure('Message not found.'),
    );
    final cubit = _cubit(repo);
    await tester.pumpWidget(_host(cubit));
    await tester.pump();
    await tester.pump();

    await _openMenu(tester, 'Sticky');
    await tester.tap(find.text('Delete for me'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Sticky'), findsOneWidget);
    expect(find.text('Message not found.'), findsOneWidget);
    await cubit.close();
  });
}
