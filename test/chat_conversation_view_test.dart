import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/chat_attachment_format.dart';
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
import 'package:drop/features/chat/presentation/chat_attachment_picker.dart';
import 'package:drop/features/chat/presentation/cubit/chat_conversation_cubit.dart';
import 'package:drop/features/chat/presentation/widgets/chat_conversation_view.dart';

const _me = 'me-uuid';
const _them = 'them-uuid';
const _convId = 'conv-1';

ChatConversation _conversation() => ChatConversation(
      id: _convId,
      participantIds: const [_me, _them],
      createdAt: DateTime(2026, 7, 20),
      lastMessageAt: DateTime(2026, 7, 22, 10),
    );

ChatMessage _message(String id, int seq, String sender, String body,
        {DateTime? at}) =>
    ChatMessage(
      id: id,
      conversationId: _convId,
      senderId: sender,
      type: ChatMessageType.text,
      body: body,
      seq: BigInt.from(seq),
      status: 'SENT',
      createdAt: at ?? DateTime(2026, 7, 22, 9, seq),
    );

/// Thread-scoped fake — only the four calls the conversation cubit makes.
class _FakeChatRepository implements ChatRepository {
  @override
  Future<List<ChatConversationSummary>> getCachedConversations() async =>
      const [];

  _FakeChatRepository({
    required this.onHistory,
    this.onSend,
    this.progressTicks = const [(50, 100), (100, 100)],
  });

  final Future<ChatMessagePage> Function({String? cursor}) onHistory;
  final Future<ChatMessage> Function(String content)? onSend;

  /// Transfer-progress ticks the fake emits on each send (sent, total).
  final List<(int, int)> progressTicks;
  final List<BigInt> markedUpTo = [];

  /// The attachment passed to the most recent send (null if text-only).
  ChatOutgoingAttachment? lastAttachment;

  /// The `replyToMessageId` passed to the most recent send (null when the last
  /// send did not quote anything) — lets a test assert the reply was threaded.
  String? lastReplyTo;

  @override
  Future<ChatConversation> getConversation(String conversationId) async =>
      _conversation();

  @override
  Future<ChatMessagePage> getMessageHistory({
    required String conversationId,
    int? limit,
    String? cursor,
  }) =>
      onHistory(cursor: cursor);

  @override
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String idempotencyKey,
    String? content,
    ChatOutgoingAttachment? attachment,
    String? replyToMessageId,
    void Function(int sent, int total)? onSendProgress,
  }) {
    lastReplyTo = replyToMessageId;
    lastAttachment = attachment;
    // Emulate transfer-progress ticks so the ring path is exercised.
    for (final (sent, total) in progressTicks) {
      onSendProgress?.call(sent, total);
    }
    final handler = onSend;
    if (handler == null) throw UnimplementedError();
    return handler(content ?? '');
  }

  @override
  Future<ChatReadReceipt> markMessagesRead({
    required String conversationId,
    required BigInt upToSeq,
  }) async {
    markedUpTo.add(upToSeq);
    return ChatReadReceipt(
      conversationId: conversationId,
      markedCount: 1,
      readAt: DateTime(2026, 7, 22, 12),
    );
  }

  @override
  Future<ChatConversation> startConversation(String targetUserId) =>
      throw UnimplementedError();

  @override
  Future<ChatConversationPage> getConversations(
          {int? limit, String? cursor}) =>
      throw UnimplementedError();

  @override
  Future<void> deleteMessageForMe(
          {required String conversationId, required String messageId}) =>
      throw UnimplementedError();

  @override
  Future<ChatMessage> deleteMessageForEveryone(
          {required String conversationId, required String messageId}) =>
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

Widget _host(ChatConversationCubit cubit, {ChatAttachmentSource? source}) =>
    MaterialApp(
      home: Scaffold(
        body: BlocProvider.value(
          value: cubit,
          child: ChatConversationView(attachmentSource: source),
        ),
      ),
    );

/// A canned attachment source — returns a small document on the document path
/// (no image decode), so the composer's attach→preview→send flow is testable
/// without the platform pickers.
class _FakeAttachmentSource implements ChatAttachmentSource {
  @override
  Future<ChatOutgoingAttachment?> pickCameraImage() async => null;
  @override
  Future<ChatOutgoingAttachment?> pickGalleryImage() async => null;
  @override
  Future<ChatOutgoingAttachment?> pickDocument() async => ChatOutgoingAttachment(
        format: ChatAttachmentFormat.pdf,
        mimeType: 'application/pdf',
        originalFilename: 'report.pdf',
        bytes: Uint8List.fromList(const [1, 2, 3, 4]),
      );
}

void main() {
  testWidgets('renders the thread with a date separator and both sides',
      (tester) async {
    // Dates are relative to now so the Today/Yesterday separators hold
    // regardless of the wall clock (a midnight rollover used to flake this).
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 9);
    final yesterday = today.subtract(const Duration(days: 1));
    final repo = _FakeChatRepository(
      onHistory: ({String? cursor}) async => ChatMessagePage(items: [
        _message('m1', 1, _them, 'Hey — shift swap tomorrow?', at: yesterday),
        _message('m2', 2, _me, 'Works for me.', at: today),
      ]),
    );
    final cubit = _cubit(repo);
    await tester.pumpWidget(_host(cubit));
    await tester.pump();
    await tester.pump();

    expect(find.text('Hey — shift swap tomorrow?'), findsOneWidget);
    expect(find.text('Works for me.'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    await cubit.close();
  });

  testWidgets('marks the visible thread read up to the newest seq',
      (tester) async {
    final repo = _FakeChatRepository(
      onHistory: ({String? cursor}) async => ChatMessagePage(items: [
        _message('m1', 1, _them, 'One'),
        _message('m2', 7, _them, 'Two'),
      ]),
    );
    final cubit = _cubit(repo);
    await tester.pumpWidget(_host(cubit));
    await tester.pump();
    await tester.pump();
    await tester.pump(); // post-frame visible signal

    expect(repo.markedUpTo, [BigInt.from(7)]);
    await cubit.close();
  });

  testWidgets('an empty thread shows the empty line with the composer ready',
      (tester) async {
    final repo = _FakeChatRepository(
      onHistory: ({String? cursor}) async =>
          const ChatMessagePage(items: []),
    );
    final cubit = _cubit(repo);
    await tester.pumpWidget(_host(cubit));
    await tester.pump();
    await tester.pump();

    expect(find.text('Say hello'), findsOneWidget);
    expect(find.text('This is the beginning of your conversation.'),
        findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    await cubit.close();
  });

  testWidgets('a first-load failure renders the full-screen retry and recovers',
      (tester) async {
    var calls = 0;
    final repo = _FakeChatRepository(
      onHistory: ({String? cursor}) async {
        calls++;
        if (calls == 1) throw const ServerFailure('Chat is unreachable.');
        return ChatMessagePage(items: [_message('m1', 1, _them, 'Back!')]);
      },
    );
    final cubit = _cubit(repo);
    await tester.pumpWidget(_host(cubit));
    await tester.pump();
    await tester.pump();
    expect(find.text('Chat is unreachable.'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Back!'), findsOneWidget);
    await cubit.close();
  });

  testWidgets('sending appends the server message and clears the field',
      (tester) async {
    final repo = _FakeChatRepository(
      onHistory: ({String? cursor}) async =>
          ChatMessagePage(items: [_message('m1', 1, _them, 'Hi')]),
      onSend: (content) async => _message('m2', 2, _me, content),
    );
    final cubit = _cubit(repo);
    await tester.pumpWidget(_host(cubit));
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'On my way');
    // The send button animates in once there's text — settle before tapping.
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    expect(find.text('On my way'), findsOneWidget); // now a bubble
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
    await cubit.close();
  });

  testWidgets('an optimistic send that fails shows a failed bubble with retry',
      (tester) async {
    var attempts = 0;
    final repo = _FakeChatRepository(
      onHistory: ({String? cursor}) async =>
          ChatMessagePage(items: [_message('m1', 1, _them, 'Hi')]),
      onSend: (content) async {
        attempts++;
        throw const ServerFailure('Send failed.');
      },
    );
    final cubit = _cubit(repo);
    await tester.pumpWidget(_host(cubit));
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Important reply');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    // Optimistic: the field clears immediately and the message shows as a
    // failed bubble the user can retry — not retained text + a snackbar.
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
    expect(find.text('Important reply'), findsOneWidget); // the failed bubble
    expect(find.textContaining('Tap to retry'), findsOneWidget);
    expect(attempts, 1);

    await tester.tap(find.textContaining('Tap to retry'));
    await tester.pumpAndSettle();
    expect(attempts, 2); // retry re-dispatches the same send
    await cubit.close();
  });

  testWidgets('scrolling to the top loads and prepends the older page',
      (tester) async {
    var historyCalls = 0;
    final repo = _FakeChatRepository(
      onHistory: ({String? cursor}) async {
        historyCalls++;
        if (cursor == null) {
          return ChatMessagePage(
            items: [
              for (var i = 30; i < 60; i++)
                _message('m$i', i, i.isEven ? _them : _me, 'Message $i',
                    at: DateTime(2026, 7, 22, 8, i)),
            ],
            nextCursor: 'older',
          );
        }
        return ChatMessagePage(items: [
          for (var i = 0; i < 30; i++)
            _message('m$i', i, _them, 'Older $i',
                at: DateTime(2026, 7, 20, 8, i)),
        ]);
      },
    );
    final cubit = _cubit(repo);
    await tester.pumpWidget(_host(cubit));
    await tester.pump();
    await tester.pump();
    expect(historyCalls, 1);

    // Drag down repeatedly to reach the top of the thread.
    for (var i = 0; i < 12 && historyCalls < 2; i++) {
      await tester.drag(
          find.byType(ListView), const Offset(0, 600), warnIfMissed: false);
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(historyCalls, 2);
    // The older page is prepended into the thread (the top rows themselves
    // stay lazily unbuilt above the preserved scroll position).
    final messages = cubit.state.maybeMap(
        loaded: (s) => s.messages, orElse: () => throw StateError('not loaded'));
    expect(messages.length, 60);
    expect(messages.first.body, 'Older 0');
    await cubit.close();
  });

  testWidgets('a reply renders the quoted preview above its own body',
      (tester) async {
    final quoted = ChatMessage(
      id: 'm2',
      conversationId: _convId,
      senderId: _me,
      type: ChatMessageType.text,
      body: 'Yes exactly that one',
      seq: BigInt.from(2),
      status: 'SENT',
      createdAt: DateTime(2026, 7, 22, 9, 2),
      replyTo: const ChatReplyPreview(
        id: 'm1',
        senderId: _them,
        type: ChatMessageType.text,
        body: 'Shift swap tomorrow?',
      ),
    );
    final repo = _FakeChatRepository(
      onHistory: ({String? cursor}) async => ChatMessagePage(items: [
        _message('m1', 1, _them, 'Shift swap tomorrow?'),
        quoted,
      ]),
    );
    final cubit = _cubit(repo);
    await tester.pumpWidget(_host(cubit));
    await tester.pump();
    await tester.pump();

    // The quoted snippet appears both as the original message and inside the
    // reply's quote block; the reply's own body appears once.
    expect(find.text('Shift swap tomorrow?'), findsNWidgets(2));
    expect(find.text('Yes exactly that one'), findsOneWidget);
    await cubit.close();
  });

  testWidgets('long-press Reply banners the target and threads the next send',
      (tester) async {
    final repo = _FakeChatRepository(
      onHistory: ({String? cursor}) async => ChatMessagePage(items: [
        _message('m1', 1, _them, 'Shift swap tomorrow?'),
      ]),
      onSend: (content) async => _message('m2', 2, _me, content),
    );
    final cubit = _cubit(repo);
    await tester.pumpWidget(_host(cubit));
    await tester.pump();
    await tester.pump();

    await tester.longPress(find.text('Shift swap tomorrow?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reply'));
    await tester.pumpAndSettle();

    // The composer now shows the reply banner for that message.
    expect(find.textContaining('Replying to'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'On it');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    // The send carried the quoted message id, and the banner cleared.
    expect(repo.lastReplyTo, 'm1');
    expect(find.textContaining('Replying to'), findsNothing);
    await cubit.close();
  });

  testWidgets('attaching a document previews it, then sends it optimistically',
      (tester) async {
    final repo = _FakeChatRepository(
      onHistory: ({String? cursor}) async =>
          ChatMessagePage(items: [_message('m1', 1, _them, 'Hi')]),
      onSend: (content) async => _message('m2', 2, _me, content),
    );
    final cubit = _cubit(repo);
    await tester.pumpWidget(_host(cubit, source: _FakeAttachmentSource()));
    await tester.pump();
    await tester.pump();

    // Open the attachment sheet and choose Document.
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Documents'));
    await tester.pumpAndSettle();

    // The staged attachment previews in the composer (filename shown), and the
    // send button appears even with no text typed.
    expect(find.text('report.pdf'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    // The send carried the attachment, and the staged preview cleared.
    expect(repo.lastAttachment, isNotNull);
    expect(repo.lastAttachment!.originalFilename, 'report.pdf');
    await cubit.close();
  });

  testWidgets('an in-flight attachment shows a determinate upload progress ring',
      (tester) async {
    final held = Completer<ChatMessage>();
    final repo = _FakeChatRepository(
      onHistory: ({String? cursor}) async =>
          ChatMessagePage(items: [_message('m1', 1, _them, 'Hi')]),
      onSend: (_) => held.future, // stays pending → the bubble stays SENDING
      progressTicks: const [(40, 100)], // one mid-upload tick
    );
    final cubit = _cubit(repo);
    await tester.pumpWidget(_host(cubit, source: _FakeAttachmentSource()));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Documents'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump(); // optimistic insert + the 40% progress tick

    // A determinate ring reflects the upload progress while it's in flight.
    final ring = tester.widgetList<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(ring.any((r) => r.value != null && (r.value! - 0.4).abs() < 0.001),
        isTrue);

    held.complete(_message('m2', 2, _me, ''));
    await tester.pumpAndSettle();
    await cubit.close();
  });
}
