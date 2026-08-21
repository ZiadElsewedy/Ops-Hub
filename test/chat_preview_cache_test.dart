import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/features/chat/presentation/chat_format.dart';
import 'package:opshub/features/chat/presentation/cubit/chat_list_cubit.dart';
import 'package:opshub/features/chat/domain/repositories/chat_repository.dart';
import 'package:opshub/features/chat/domain/usecases/get_conversations.dart';
import 'package:opshub/features/chat/domain/usecases/start_conversation.dart';

/// The cache under test never touches the network, so the repository only has
/// to exist.
class _InertRepository implements ChatRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// **Inbox preview churn.**
///
/// The conversation list endpoint returns `lastMessageAt` but not the message,
/// so the inbox resolves one preview per row. Two things about that memo caused
/// the "chat keeps requesting things / keeps changing" behaviour:
///
///  1. a lookup that came back with **nothing** was dropped instead of
///     recorded, so the row looked unresolved forever and re-queued its fetch
///     on every rebuild — and since each landing fetch caused a rebuild, the
///     two fed each other; and
///  2. the memo lived on the screen's `State`, so walking into a conversation
///     and back re-fetched every row from scratch.
///
/// Both are properties of the cubit's cache now, so both are pinned here.
void main() {
  ChatListCubit build() => ChatListCubit(
        getConversations: GetConversations(_InertRepository()),
        startConversation: StartConversation(_InertRepository()),
      );

  test('an empty result is remembered, not retried', () {
    final cubit = build();
    addTearDown(cubit.close);

    expect(cubit.isPreviewResolved('c1'), isFalse);

    cubit.cacheResolvedPreview('c1', null);

    // The distinction that matters: resolved, with nothing to show. Reading
    // back a null preview must NOT read as "never tried".
    expect(cubit.isPreviewResolved('c1'), isTrue);
    expect(cubit.resolvedPreview('c1'), isNull);
  });

  test('a resolved preview is kept and formatted for the row', () {
    final cubit = build();
    addTearDown(cubit.close);

    cubit.cacheResolvedPreview('c1', const ChatPreview('On my way', mine: true));

    expect(cubit.isPreviewResolved('c1'), isTrue);
    expect(cubit.resolvedPreview('c1')!.line, 'You: On my way');
  });

  test('previews survive the screen, so returning does not re-fetch', () {
    // The cubit is an app-wide singleton; this stands in for the inbox being
    // disposed and rebuilt while it lives on.
    final cubit = build();
    addTearDown(cubit.close);

    cubit.cacheResolvedPreview('c1', const ChatPreview('Done'));
    cubit.cacheResolvedPreview('c2', null);

    expect(cubit.isPreviewResolved('c1'), isTrue);
    expect(cubit.isPreviewResolved('c2'), isTrue);
  });

  test('opening a conversation invalidates only that row', () {
    final cubit = build();
    addTearDown(cubit.close);

    cubit.cacheResolvedPreview('c1', const ChatPreview('Old'));
    cubit.cacheResolvedPreview('c2', const ChatPreview('Other'));

    cubit.invalidateResolvedPreview('c1');

    expect(cubit.isPreviewResolved('c1'), isFalse);
    expect(cubit.resolvedPreview('c2')!.line, 'Other');
  });

  test('reset clears them — one account never sees the previous one\'s', () {
    final cubit = build();
    addTearDown(cubit.close);

    cubit.cacheResolvedPreview('c1', const ChatPreview('Private'));
    cubit.cacheResolvedPreview('c2', null);

    cubit.reset();

    expect(cubit.isPreviewResolved('c1'), isFalse);
    expect(cubit.isPreviewResolved('c2'), isFalse);
    expect(cubit.resolvedPreview('c1'), isNull);
  });
}
