import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/core/utils/app_logger.dart';
import 'package:drop/features/notifications/domain/entities/notification_entity.dart';
import 'package:drop/features/notifications/domain/repositories/notification_repository.dart';
import 'package:drop/features/notifications/domain/usecases/mark_notification_read.dart';
import 'package:drop/features/notifications/presentation/cubit/notification_state.dart';

/// Drives the in-app notification inbox (Notification System Phase 1). Subscribes
/// to the signed-in user's notification feed and exposes the unread count + the
/// mark-read actions. Mirrors `BroadcastCubit`: repository directly for the live
/// stream, a use case for the write; last-good snapshot kept on a stream error.
class NotificationCubit extends Cubit<NotificationState> {
  final NotificationRepository _repository;
  final MarkNotificationRead _markRead;

  NotificationCubit({
    required this._repository,
    required this._markRead,
  }) : super(const NotificationState.initial());

  /// How many notifications each page loads.
  static const int pageSize = 30;

  StreamSubscription<List<NotificationEntity>>? _sub;
  String? _uid;
  bool _hasSnapshot = false;

  /// When the initial subscription started — times the first snapshot.
  DateTime? _subscribedAt;

  /// The current growing-window size (grows by [pageSize] on each [loadMore]).
  int _limit = pageSize;

  /// Size of the last snapshot — used to infer whether more pages exist.
  int _lastCount = 0;

  /// Completes when the next snapshot after a [loadMore] arrives.
  Completer<void>? _pageCompleter;

  List<NotificationEntity> get _items =>
      state.maybeWhen(loaded: (n) => n, orElse: () => const []);

  /// Unread, non-archived notifications in the current feed (drives the badge).
  int get unreadCount =>
      _items.where((n) => n.isUnread && !n.isArchived).length;

  /// Whether another page likely exists (the last window came back full).
  bool get hasMore => _lastCount >= _limit;

  /// Subscribes to [uid]'s live notification feed. A no-op if already watching
  /// the same user.
  Future<void> load(String uid) async {
    if (_uid == uid && _sub != null) return;
    AppLog.call('notifications', 'load', details: 'uid=$uid');
    _uid = uid;
    _hasSnapshot = false;
    _limit = pageSize;
    _subscribedAt = DateTime.now();
    emit(const NotificationState.loading());
    await _subscribe();
  }

  /// Grows the window by one page (infinite pagination). Resolves when the next
  /// snapshot arrives (or immediately if there is nothing more to load).
  Future<void> loadMore() async {
    if (_uid == null || !hasMore) return;
    _limit += pageSize;
    final completer = Completer<void>();
    _pageCompleter = completer;
    await _subscribe();
    return completer.future;
  }

  /// (Re)subscribes to the feed at the current [_limit].
  Future<void> _subscribe() async {
    final uid = _uid;
    if (uid == null) return;
    await _sub?.cancel();
    _sub = _repository.watch(uid, limit: _limit).listen(
      (items) {
        // Stream-based fetch: time-to-first-snapshot is the load duration.
        final started = _subscribedAt;
        if (!_hasSnapshot && started != null) {
          _subscribedAt = null;
          final ms = DateTime.now().difference(started).inMilliseconds;
          final message =
              '⏱ first snapshot: ${items.length} notifications in ${ms}ms';
          ms >= AppLog.slowThreshold.inMilliseconds
              ? AppLog.warning('notifications', '$message (slow)')
              : AppLog.success('notifications', message);
        }
        _hasSnapshot = true;
        _lastCount = items.length;
        emit(NotificationState.loaded(items));
        _pageCompleter?.complete();
        _pageCompleter = null;
      },
      onError: (Object e, StackTrace st) {
        AppLog.error('notifications', 'feed stream error', e, st);
        if (!_hasSnapshot) emit(NotificationState.error(_message(e)));
        _pageCompleter?.complete();
        _pageCompleter = null;
      },
    );
  }

  /// Stops watching and resets (call on sign-out).
  Future<void> clear() async {
    await _sub?.cancel();
    _sub = null;
    _uid = null;
    _hasSnapshot = false;
    _limit = pageSize;
    _lastCount = 0;
    emit(const NotificationState.initial());
  }

  Future<void> markRead(String id) async {
    try {
      await _markRead(id);
      // The stream re-emits with the updated readAt — no optimistic write needed.
    } catch (e, st) {
      AppLog.error('notifications', 'markRead failed', e, st);
    }
  }

  /// Marks every unread notification read. Returns the failure message when it
  /// could not, or `null` on success.
  ///
  /// It reports rather than swallowing because it is now [NetworkGuard]-guarded
  /// and paged: offline, or on an inbox past the sweep ceiling, it genuinely
  /// does nothing, and a bulk action that silently does nothing is
  /// indistinguishable from one that worked.
  Future<String?> markAllRead() async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      await _repository.markAllRead(uid);
      return null;
    } catch (e, st) {
      AppLog.error('notifications', 'markAllRead failed', e, st);
      return _message(e,
          fallback: 'Could not mark everything read. Please try again.');
    }
  }

  /// Permanently deletes one notification. The stream re-emits without it.
  Future<void> delete(String id) async {
    try {
      await _repository.delete(id);
    } catch (e, st) {
      AppLog.error('notifications', 'delete failed', e, st);
    }
  }

  /// Archives ([archived] true) / unarchives one notification.
  Future<void> setArchived(String id, bool archived) async {
    try {
      await _repository.setArchived(id, archived);
    } catch (e, st) {
      AppLog.error('notifications', 'setArchived failed', e, st);
    }
  }

  /// Bulk "Clear archived" — permanently deletes **every** archived
  /// notification for this user, not just the ones in the loaded page.
  ///
  /// It used to fan out client-side deletes over `_items`, which is capped at
  /// the pagination window (30 by default). So a user with 90 archived
  /// notifications confirmed a dialog reading *"Permanently delete all archived
  /// notifications"*, watched the stream backfill the list straight back to
  /// full, and reasonably concluded the button was broken. The sweep now happens
  /// in the datasource, paged and batched, and the promise the dialog makes is
  /// the promise the code keeps.
  ///
  /// Returns the failure message when it could not complete, or `null` on
  /// success — the caller surfaces it. The old fan-out swallowed every error
  /// individually, so a permission failure looked identical to success.
  Future<String?> clearArchived() async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      await _repository.deleteArchived(uid);
      return null;
    } catch (e, st) {
      AppLog.error('notifications', 'clearArchived failed', e, st);
      return _message(e,
          fallback: 'Could not clear archived notifications. Please try again.');
    }
  }

  /// Pins ([pinned] true) / unpins one notification.
  Future<void> setPinned(String id, bool pinned) async {
    try {
      await _repository.setPinned(id, pinned);
    } catch (e, st) {
      AppLog.error('notifications', 'setPinned failed', e, st);
    }
  }

  /// A user-facing sentence for [e]. A [Failure] already carries one written for
  /// this exact situation (including `NetworkGuard`'s offline sentence), so it
  /// always wins; [fallback] covers anything else.
  String _message(
    Object e, {
    String fallback = 'Could not load notifications. Please try again.',
  }) =>
      e is Failure ? e.message : fallback;

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
