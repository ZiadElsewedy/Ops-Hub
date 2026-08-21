import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/chat_attachment_kind.dart';
import 'package:opshub/core/errors/failures.dart';
import 'package:opshub/core/enums/chat_message_type.dart';
import 'package:opshub/features/chat/domain/entities/chat_conversation.dart';
import 'package:opshub/features/chat/domain/entities/chat_message.dart';
import 'package:opshub/features/chat/domain/repositories/chat_repository.dart';
import 'package:opshub/features/chat/domain/usecases/delete_chat_message_for_everyone.dart';
import 'package:opshub/features/chat/domain/usecases/delete_chat_message_for_me.dart';
import 'package:opshub/features/chat/domain/usecases/get_conversation.dart';
import 'package:opshub/features/chat/domain/usecases/load_chat_history.dart';
import 'package:opshub/features/chat/domain/usecases/mark_chat_read.dart';
import 'package:opshub/features/chat/domain/usecases/send_chat_message.dart';
import 'package:opshub/features/chat/presentation/cubit/chat_conversation_cubit.dart';

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

  // ─── Clearing drains the WHOLE history, not just the loaded window ────
  // The confirm dialog promises "removes every message from your view", but
  // this used to delete only what had been paged in — so on any thread longer
  // than the first page the older messages came straight back on scroll-up.

  test('clearChatForMe pages back through the entire history', () async {
    final repo = _PagedRepo(pages: 3, perPage: 4);
    final cubit = _pagedCubit(repo);
    await _settle();
    // Only the first page is on screen.
    expect(_messagesOf(cubit), hasLength(4));

    final ok = await cubit.clearChatForMe();

    expect(ok, isTrue);
    expect(repo.deletedForMe, hasLength(12));
    expect(repo.deletedForMe.toSet(), hasLength(12)); // no id deleted twice
    expect(_messagesOf(cubit), isEmpty);
    // Nothing older is left to page to, so no "load older" is offered.
    expect(
      cubit.state.maybeMap(loaded: (s) => s.hasMore, orElse: () => true),
      isFalse,
    );
    await cubit.close();
  });

  test('a history page that fails deletes NOTHING', () async {
    // All-or-nothing on the collect step: a half-clear against a promise of
    // "every message" is the bug being fixed, and a clean failure is retryable.
    final repo = _PagedRepo(pages: 3, perPage: 4, failOnPage: 2);
    final cubit = _pagedCubit(repo);
    await _settle();

    final ok = await cubit.clearChatForMe();

    expect(ok, isFalse);
    expect(repo.deletedForMe, isEmpty);
    await cubit.close();
  });

  test('a cursor that never advances raises instead of looping forever',
      () async {
    final repo = _PagedRepo(pages: 3, perPage: 4, stuckCursor: true);
    final cubit = _pagedCubit(repo);
    await _settle();

    final ok = await cubit.clearChatForMe();

    expect(ok, isFalse);
    expect(repo.deletedForMe, isEmpty);
    // The guard fired on the second page rather than paging the same slice
    // until the test timed out.
    expect(repo.historyCalls, lessThan(5));
    await cubit.close();
  });

  test('clearing an empty conversation succeeds without deleting anything',
      () async {
    final repo = _PagedRepo(pages: 0, perPage: 0);
    final cubit = _pagedCubit(repo);
    await _settle();

    final ok = await cubit.clearChatForMe();

    expect(ok, isTrue);
    expect(repo.deletedForMe, isEmpty);
    await cubit.close();
  });
}

/// One message on a given history page — a distinct id per page so the drain's
/// coverage is checkable.
ChatMessage _pagedMsg(String id, int seq) => ChatMessage(
      id: id,
      conversationId: _conv,
      senderId: _them,
      type: ChatMessageType.text,
      body: id,
      seq: BigInt.from(seq),
      status: 'SENT',
      createdAt: DateTime(2026, 7, 24, 10, seq),
    );

/// A repository whose history is [pages] pages deep, so a clear has to page
/// back to reach everything. Message ids are `p<page>-m<n>`.
class _PagedRepo implements ChatRepository {
  _PagedRepo({
    required this.pages,
    required this.perPage,
    this.failOnPage,
    this.stuckCursor = false,
  });

  final int pages;
  final int perPage;

  /// 1-based page index that throws when fetched (a mid-drain network failure).
  final int? failOnPage;

  /// Hands back the cursor it was given — the pagination bug the drain must
  /// refuse rather than spin on.
  final bool stuckCursor;

  final List<String> deletedForMe = [];
  int historyCalls = 0;

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
  }) async {
    historyCalls++;
    final page = cursor == null ? 1 : int.parse(cursor.split('-').last);
    if (failOnPage == page) throw const ServerFailure('history unavailable');
    if (page > pages) return const ChatMessagePage(items: []);
    final items = <ChatMessage>[
      for (var i = 1; i <= perPage; i++) _pagedMsg('p$page-m$i', i),
    ];
    final hasMore = page < pages;
    return ChatMessagePage(
      items: items,
      nextCursor: !hasMore
          ? null
          : stuckCursor
              ? (cursor ?? 'cursor-1')
              : 'cursor-${page + 1}',
    );
  }

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

ChatConversationCubit _pagedCubit(_PagedRepo repo) => ChatConversationCubit(
      getConversation: GetConversation(repo),
      loadHistory: LoadChatHistory(repo),
      sendMessage: SendChatMessage(repo),
      markRead: MarkChatRead(repo),
      deleteForMe: DeleteChatMessageForMe(repo),
      deleteForEveryone: DeleteChatMessageForEveryone(repo),
      conversationId: _conv,
      counterpartUserId: _them,
    );
