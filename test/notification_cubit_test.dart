import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/notification_type.dart';
import 'package:opshub/core/errors/failures.dart';
import 'package:opshub/features/notifications/domain/entities/notification_entity.dart';
import 'package:opshub/features/notifications/domain/repositories/notification_repository.dart';
import 'package:opshub/features/notifications/domain/usecases/mark_notification_read.dart';
import 'package:opshub/features/notifications/presentation/cubit/notification_cubit.dart';
import 'package:opshub/features/notifications/presentation/cubit/notification_state.dart';

/// Drives [NotificationCubit] over a controllable fake feed to verify the
/// read/unread model (Notifications V2 — Part 4), the badge count, action
/// delegation, growing-window pagination, and sign-out reset.
class _FakeNotificationRepository implements NotificationRepository {
  final StreamController<List<NotificationEntity>> _controller =
      StreamController<List<NotificationEntity>>.broadcast();

  int watchCount = 0;
  int lastLimit = 0;
  final List<String> markedRead = [];
  final List<String> markedAllReadUids = [];
  final List<String> deleted = [];
  final List<String> clearedArchivedUids = [];
  final List<(String, bool)> archivedCalls = [];
  final List<(String, bool)> pinnedCalls = [];

  /// When set, the next bulk action throws it — so a test can assert the cubit
  /// REPORTS the failure instead of swallowing it into a log.
  Object? bulkError;

  void emit(List<NotificationEntity> items) => _controller.add(items);

  @override
  Stream<List<NotificationEntity>> watch(String uid, {int limit = 30}) {
    watchCount++;
    lastLimit = limit;
    return _controller.stream;
  }

  @override
  Future<void> markRead(String id) async => markedRead.add(id);

  @override
  Future<void> markAllRead(String uid) async {
    if (bulkError != null) throw bulkError!;
    markedAllReadUids.add(uid);
  }

  @override
  Future<void> delete(String id) async => deleted.add(id);

  @override
  Future<void> deleteArchived(String uid) async {
    if (bulkError != null) throw bulkError!;
    clearedArchivedUids.add(uid);
  }

  @override
  Future<void> setArchived(String id, bool archived) async =>
      archivedCalls.add((id, archived));

  @override
  Future<void> setPinned(String id, bool pinned) async =>
      pinnedCalls.add((id, pinned));

  @override
  Future<void> create(NotificationEntity notification) async {}

  @override
  Future<void> createMany(List<NotificationEntity> notifications) async {}
}

NotificationEntity _n(
  String id, {
  bool read = false,
  bool archived = false,
  NotificationType type = NotificationType.taskAssigned,
}) {
  final at = DateTime(2026, 7, 10, 9);
  return NotificationEntity(
    id: id,
    recipientUid: 'u1',
    type: type,
    title: 'Title $id',
    body: 'Body',
    createdAt: at,
    readAt: read ? at : null,
    archivedAt: archived ? at : null,
  );
}

NotificationCubit _build(_FakeNotificationRepository repo) => NotificationCubit(
      repository: repo,
      markRead: MarkNotificationRead(repo),
    );

void main() {
  test('load subscribes at the first page size and emits loaded', () async {
    final repo = _FakeNotificationRepository();
    final cubit = _build(repo);
    await cubit.load('u1');
    repo.emit([_n('a'), _n('b', read: true)]);
    await pumpEventQueue();

    expect(repo.watchCount, 1);
    expect(repo.lastLimit, NotificationCubit.pageSize);
    expect(cubit.state, isA<NotificationState>());
    expect(
      cubit.state.maybeWhen(loaded: (n) => n.length, orElse: () => -1),
      2,
    );
    await cubit.close();
  });

  test('unreadCount excludes read AND archived notifications', () async {
    final repo = _FakeNotificationRepository();
    final cubit = _build(repo);
    await cubit.load('u1');
    repo.emit([
      _n('unread1'),
      _n('unread2'),
      _n('read', read: true),
      _n('archivedUnread', archived: true), // unread but archived → not counted
    ]);
    await pumpEventQueue();

    expect(cubit.unreadCount, 2);
    await cubit.close();
  });

  test('markRead delegates to the repository', () async {
    final repo = _FakeNotificationRepository();
    final cubit = _build(repo);
    await cubit.load('u1');
    await cubit.markRead('n1');
    expect(repo.markedRead, ['n1']);
    await cubit.close();
  });

  test('markAllRead delegates for the loaded user', () async {
    final repo = _FakeNotificationRepository();
    final cubit = _build(repo);
    await cubit.load('u1');
    expect(await cubit.markAllRead(), isNull);
    expect(repo.markedAllReadUids, ['u1']);
    await cubit.close();
  });

  test('clearArchived sweeps SERVER-SIDE, not over the loaded page', () async {
    // The old implementation fanned out client-side deletes over `_items`,
    // which is capped at the pagination window — so a user with more archived
    // notifications than one page confirmed "delete all", saw the list refill,
    // and concluded the button was broken. It must delegate one sweep for the
    // user and never touch `delete`.
    final repo = _FakeNotificationRepository();
    final cubit = _build(repo);
    await cubit.load('u1');
    repo.emit([
      _n('a1', archived: true),
      _n('a2', archived: true),
      _n('n1'),
    ]);
    await pumpEventQueue();

    expect(await cubit.clearArchived(), isNull);
    expect(repo.clearedArchivedUids, ['u1']);
    expect(repo.deleted, isEmpty);
    await cubit.close();
  });

  test('both bulk actions REPORT failure instead of swallowing it', () async {
    // Every bulk failure used to end in a log line and nothing else, so an
    // offline "Mark all read" was indistinguishable from a successful one.
    final repo = _FakeNotificationRepository()
      ..bulkError = const ServerFailure('Network unavailable.');
    final cubit = _build(repo);
    await cubit.load('u1');

    expect(await cubit.markAllRead(), 'Network unavailable.');
    expect(await cubit.clearArchived(), 'Network unavailable.');
    expect(repo.markedAllReadUids, isEmpty);
    expect(repo.clearedArchivedUids, isEmpty);
    await cubit.close();
  });

  test('a non-Failure error still yields an action-specific sentence', () async {
    final repo = _FakeNotificationRepository()..bulkError = StateError('boom');
    final cubit = _build(repo);
    await cubit.load('u1');

    expect(await cubit.markAllRead(), contains('mark everything read'));
    expect(await cubit.clearArchived(), contains('clear archived'));
    await cubit.close();
  });

  test('bulk actions are a no-op before a user is loaded', () async {
    final repo = _FakeNotificationRepository();
    final cubit = _build(repo);
    expect(await cubit.markAllRead(), isNull);
    expect(await cubit.clearArchived(), isNull);
    expect(repo.markedAllReadUids, isEmpty);
    expect(repo.clearedArchivedUids, isEmpty);
    await cubit.close();
  });

  test('delete / setArchived / setPinned delegate', () async {
    final repo = _FakeNotificationRepository();
    final cubit = _build(repo);
    await cubit.load('u1');
    await cubit.delete('d1');
    await cubit.setArchived('a1', true);
    await cubit.setPinned('p1', true);
    expect(repo.deleted, ['d1']);
    expect(repo.archivedCalls, [('a1', true)]);
    expect(repo.pinnedCalls, [('p1', true)]);
    await cubit.close();
  });

  test('hasMore is true when the window is full, and loadMore grows it',
      () async {
    final repo = _FakeNotificationRepository();
    final cubit = _build(repo);
    await cubit.load('u1');
    // A full page implies another page may exist.
    repo.emit(List.generate(NotificationCubit.pageSize, (i) => _n('n$i')));
    await pumpEventQueue();
    expect(cubit.hasMore, isTrue);

    final more = cubit.loadMore();
    // Let the re-subscribe (cancel old + listen new) settle before emitting the
    // next window, so the broadcast snapshot reaches the fresh subscription.
    await pumpEventQueue();
    repo.emit(List.generate(NotificationCubit.pageSize + 1, (i) => _n('n$i')));
    await more;

    expect(repo.lastLimit, NotificationCubit.pageSize * 2);
    // A non-full window means we've reached the end.
    expect(cubit.hasMore, isFalse);
    await cubit.close();
  });

  test('clear resets to initial and stops watching', () async {
    final repo = _FakeNotificationRepository();
    final cubit = _build(repo);
    await cubit.load('u1');
    repo.emit([_n('a')]);
    await pumpEventQueue();

    await cubit.clear();
    expect(cubit.state, const NotificationState.initial());
    expect(cubit.unreadCount, 0);
    await cubit.close();
  });
}
