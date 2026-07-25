import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/core/widgets/drop_empty_state.dart';
import 'package:drop/features/chat/domain/entities/chat_attachment_download.dart';
import 'package:drop/features/chat/domain/entities/chat_conversation.dart';
import 'package:drop/features/chat/domain/entities/chat_message.dart';
import 'package:drop/features/chat/domain/entities/chat_outgoing_attachment.dart';
import 'package:drop/features/chat/domain/entities/chat_read_receipt.dart';
import 'package:drop/features/chat/domain/repositories/chat_repository.dart';
import 'package:drop/features/chat/domain/usecases/get_conversations.dart';
import 'package:drop/features/chat/domain/usecases/start_conversation.dart';
import 'package:drop/features/chat/presentation/chat_format.dart';
import 'package:drop/features/chat/presentation/cubit/chat_list_cubit.dart';
import 'package:drop/features/chat/presentation/pages/chat_screen.dart';
import 'package:drop/features/chat/presentation/widgets/chat_conversation_tile.dart';

/// List-endpoint-only fake — every other repository call is out of scope for
/// the inbox screen and throws if reached.
class _FakeChatRepository implements ChatRepository {
  @override
  Future<List<ChatConversationSummary>> getCachedConversations() async =>
      const [];

  _FakeChatRepository(this.onGetConversations);

  final Future<ChatConversationPage> Function({int? limit, String? cursor})
      onGetConversations;

  @override
  Future<ChatConversationPage> getConversations({int? limit, String? cursor}) =>
      onGetConversations(limit: limit, cursor: cursor);

  @override
  Future<ChatConversation> startConversation(String targetUserId) =>
      throw UnimplementedError();

  @override
  Future<ChatConversation> getConversation(String conversationId) =>
      throw UnimplementedError();

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
  Future<ChatMessagePage> getMessageHistory({
    required String conversationId,
    int? limit,
    String? cursor,
  }) =>
      throw UnimplementedError();

  @override
  Future<ChatReadReceipt> markMessagesRead({
    required String conversationId,
    required BigInt upToSeq,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> deleteMessageForMe({
    required String conversationId,
    required String messageId,
  }) =>
      throw UnimplementedError();

  @override
  Future<ChatMessage> deleteMessageForEveryone({
    required String conversationId,
    required String messageId,
  }) =>
      throw UnimplementedError();

  @override
  Future<ChatAttachmentDownload> getAttachmentDownloadUrl({
    required String conversationId,
    required String messageId,
  }) =>
      throw UnimplementedError();
}

ChatConversationSummary _summary(String id) => ChatConversationSummary(
      id: id,
      counterpartUserId: 'user-$id',
      participantIds: ['me', 'user-$id'],
      createdAt: DateTime(2026, 7, 20),
      lastMessageAt: DateTime(2026, 7, 22, 10),
    );

void main() {
  ChatListCubit cubit(_FakeChatRepository repo) => ChatListCubit(
        getConversations: GetConversations(repo),
        startConversation: StartConversation(repo),
      );

  Widget host(ChatListCubit c) => MaterialApp(
        home: BlocProvider.value(value: c, child: const ChatScreen()),
      );

  testWidgets('loads and renders the conversation list', (tester) async {
    final c = cubit(_FakeChatRepository(
      ({int? limit, String? cursor}) async =>
          ChatConversationPage(items: [_summary('a'), _summary('b')]),
    ));
    await tester.pumpWidget(host(c));
    await tester.pump(); // post-frame load
    await tester.pump(); // resolve the page future
    expect(find.byType(ChatConversationTile), findsNWidgets(2));
    // With no directory resolution both rows fall back to the neutral, id-free
    // label (never a truncated internal id) — so it appears on both tiles.
    expect(find.text(chatCounterpartLabel('user-a')), findsNWidgets(2));
    await c.close();
  });

  testWidgets('an empty page renders the branded empty state', (tester) async {
    final c = cubit(_FakeChatRepository(
      ({int? limit, String? cursor}) async =>
          const ChatConversationPage(items: []),
    ));
    await tester.pumpWidget(host(c));
    await tester.pump();
    await tester.pump();
    expect(find.byType(DropEmptyState), findsOneWidget);
    expect(find.text('No conversations yet'), findsOneWidget);
    await c.close();
  });

  testWidgets('a first-load failure renders the full-screen retry',
      (tester) async {
    var calls = 0;
    final c = cubit(_FakeChatRepository(({int? limit, String? cursor}) async {
      calls++;
      if (calls == 1) throw const ServerFailure('Chat is unreachable.');
      return ChatConversationPage(items: [_summary('a')]);
    }));
    await tester.pumpWidget(host(c));
    await tester.pump();
    await tester.pump();
    expect(find.text('Chat is unreachable.'), findsOneWidget);

    // Retry recovers into the loaded list.
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(ChatConversationTile), findsOneWidget);
    await c.close();
  });

  testWidgets('pull-to-refresh re-pulls page one', (tester) async {
    var calls = 0;
    final c = cubit(_FakeChatRepository(({int? limit, String? cursor}) async {
      calls++;
      return ChatConversationPage(
          items: [for (var i = 0; i < calls; i++) _summary('r$i')]);
    }));
    await tester.pumpWidget(host(c));
    await tester.pump();
    await tester.pump();
    expect(find.byType(ChatConversationTile), findsOneWidget);

    await tester.fling(
        find.byType(ChatConversationTile).first, const Offset(0, 300), 1000);
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.byType(ChatConversationTile), findsNWidgets(2));
    await c.close();
  });
}
