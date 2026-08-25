import 'package:opshub/core/utils/concurrent.dart';
import 'package:opshub/features/chat/domain/repositories/chat_repository.dart';

/// Deletes **every** message in a conversation for the caller only
/// (delete-for-me) — the bulk clear behind "Delete conversation" from the
/// inbox, where no open-thread cubit is loaded to page from. It fetches the
/// whole history first, then deletes each server message for me (pooled, a few
/// at a time). The counterpart keeps their copy.
///
/// Idempotent per message, so a retry after a partial failure simply finishes
/// the job. Mirrors the open-thread `ChatConversationCubit.clearChatForMe`,
/// which clears from already-loaded state; this one starts from scratch by id.
class ClearChatForMe {
  const ClearChatForMe(this._repo);
  final ChatRepository _repo;

  /// Guards against a cursor that never terminates (or never advances) — reached
  /// only by a broken backend, treated as a failure rather than an infinite loop.
  static const _maxPages = 500;

  Future<void> call(String conversationId) async {
    final ids = <String>{};
    String? cursor;
    var pages = 0;
    while (true) {
      final page = await _repo.getMessageHistory(
        conversationId: conversationId,
        cursor: cursor,
      );
      for (final m in page.items) {
        ids.add(m.id);
      }
      final next = page.nextCursor;
      // A null cursor is the end; a cursor handing back itself would loop forever.
      if (next == null || next == cursor || pages++ >= _maxPages) break;
      cursor = next;
    }
    if (ids.isEmpty) return;
    await mapPooled(3, [
      for (final id in ids)
        () => _repo.deleteMessageForMe(
              conversationId: conversationId,
              messageId: id,
            ),
    ]);
  }
}
