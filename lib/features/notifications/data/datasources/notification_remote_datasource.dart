import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:drop/core/constants/app_constants.dart';
import 'package:drop/core/errors/exceptions.dart';
import 'package:drop/features/notifications/data/models/notification_model.dart';

abstract class NotificationRemoteDataSource {
  /// Creates notifications via the validated `sendNotification` callable
  /// (M2 fix, 2026-07-03) — direct `notifications/{id}` writes are denied by
  /// rules, so type whitelist / branch-scoped recipients / length caps /
  /// server-stamped senderUid are enforced for every client-produced doc.
  Future<void> create(NotificationModel notification);
  Future<void> createMany(List<NotificationModel> notifications);

  /// Realtime feed of the most recent [limit] notifications for [uid], newest
  /// first (server-ordered — uses the `recipientUid + createdAt` composite
  /// index). A growing [limit] gives offline-resilient infinite pagination.
  Stream<List<NotificationModel>> watch(String uid, {int limit = 30});
  Future<void> markRead(String id);

  /// Marks **every** unread notification for [uid] read, however many there are.
  /// Paged and chunked — see [NotificationRemoteDataSourceImpl._sweep].
  Future<void> markAllRead(String uid);

  /// Permanently deletes one notification (the recipient dismissing it).
  Future<void> delete(String id);

  /// Permanently deletes **every** archived notification for [uid] — the
  /// "Clear archived" action. Server-side and complete, rather than a client
  /// fan-out over whatever page happens to be loaded.
  Future<void> deleteArchived(String uid);

  /// Archives / unarchives one notification (sets / clears `archivedAt`).
  Future<void> setArchived(String id, bool archived);

  /// Pins / unpins one notification (sets / clears `pinnedAt`).
  Future<void> setPinned(String id, bool pinned);
}

class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  NotificationRemoteDataSourceImpl(this._firestore, this._functions);

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection(AppConstants.notificationsCollection);

  @override
  Future<void> create(NotificationModel notification) =>
      createMany([notification]);

  @override
  Future<void> createMany(List<NotificationModel> notifications) async {
    if (notifications.isEmpty) return;
    try {
      // The callable validates + writes with the Admin SDK; `senderUid` is
      // server-stamped from the caller's auth, so it is not sent here.
      final callable = _functions.httpsCallable('sendNotification');
      await callable.call<Map<String, dynamic>>({
        'notifications': [
          for (final n in notifications)
            {
              'recipientUid': n.recipientUid,
              'type': n.type.value,
              'title': n.title,
              'body': n.body,
              'payload': n.payload,
            },
        ],
      });
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(e.message ?? 'Failed to send notifications.');
    }
  }

  @override
  Stream<List<NotificationModel>> watch(String uid, {int limit = 30}) {
    // recipientUid equality + createdAt order → the `recipientUid + createdAt`
    // composite index (firestore.indexes.json). A growing [limit] window keeps
    // reads bounded while supporting infinite pagination + realtime updates.
    return _notifications
        .where('recipientUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => NotificationModel.fromMap(d.data(), id: d.id)).toList());
  }

  @override
  Future<void> markRead(String id) async {
    try {
      await _notifications
          .doc(id)
          .set({'readAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to update notification.');
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _notifications.doc(id).delete();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to delete notification.');
    }
  }

  @override
  Future<void> setArchived(String id, bool archived) async {
    try {
      await _notifications.doc(id).set(
        {'archivedAt': archived ? FieldValue.serverTimestamp() : null},
        SetOptions(merge: true),
      );
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to update notification.');
    }
  }

  @override
  Future<void> setPinned(String id, bool pinned) async {
    try {
      await _notifications.doc(id).set(
        {'pinnedAt': pinned ? FieldValue.serverTimestamp() : null},
        SetOptions(merge: true),
      );
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to update notification.');
    }
  }

  @override
  Future<void> markAllRead(String uid) => _sweep(
        uid,
        selects: (data) => data['readAt'] == null,
        apply: (batch, ref) => batch.set(
          ref,
          {'readAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        ),
        failureMessage: 'Failed to update notifications.',
      );

  @override
  Future<void> deleteArchived(String uid) => _sweep(
        uid,
        selects: (data) => data['archivedAt'] != null,
        apply: (batch, ref) => batch.delete(ref),
        failureMessage: 'Failed to clear archived notifications.',
      );

  /// How many documents one sweep page reads, and how many operations it can
  /// therefore put in one `WriteBatch`.
  ///
  /// **Firestore hard-caps a batch at 500 operations.** The previous
  /// `markAllRead` read the user's ENTIRE notification collection in one
  /// unbounded query and committed every unread document in a single batch — so
  /// past 500 unread it failed with `INVALID_ARGUMENT` and, because
  /// `NotificationCubit.markAllRead` swallows errors into a log, the button
  /// simply stopped working forever with no visible reason. `runTaskReminders`
  /// fires every 30 minutes on a per-task ladder, so 500 is reachable.
  ///
  /// 300 leaves generous headroom under the cap while keeping the page count
  /// (and therefore the round trips) low.
  static const int _sweepPageSize = 300;

  /// Safety valve: at most 15,000 documents per sweep. An inbox larger than
  /// this is a different problem, and running unbounded loops against Firestore
  /// from a phone is not the way to discover it.
  static const int _maxSweepPages = 50;

  /// Pages [uid]'s notifications newest-first, and for every page applies
  /// [apply] to the documents [selects] accepts, one `WriteBatch` per page.
  ///
  /// Uses the **existing** `recipientUid + createdAt` composite index (the same
  /// one [watch] uses), so the predicate stays client-side and this needs **no
  /// new index and no deploy**. Paging by `startAfterDocument` is stable for
  /// both callers: `markAllRead` only updates documents, and the cursor keeps
  /// its ordering position even for a document `deleteArchived` has removed,
  /// because Firestore resolves it from the snapshot's order-by values. Ties on
  /// `createdAt` (a batch of notifications shares one server timestamp) are
  /// broken by the implicit `__name__` ordering, which the cursor carries too —
  /// so a page boundary landing mid-batch neither skips nor repeats a document.
  ///
  /// ⚠️ `orderBy('createdAt')` **excludes documents missing that field**, which
  /// the previous unordered `markAllRead` query did not. That is not a
  /// regression: [watch] orders by `createdAt` as well, so such a document was
  /// already invisible in the inbox — there is nothing for the user to mark read
  /// or clear. Every producer stamps it (`sendNotification` and each server
  /// writer set `serverTimestamp()`), so the case is theoretical either way.
  ///
  /// Throws when the page cap is exhausted rather than returning quietly — the
  /// caller promised the user "all", and a silent partial is the exact defect
  /// `clearArchived` was fixed for.
  Future<void> _sweep(
    String uid, {
    required bool Function(Map<String, dynamic> data) selects,
    required void Function(
      WriteBatch batch,
      DocumentReference<Map<String, dynamic>> ref,
    ) apply,
    required String failureMessage,
  }) async {
    try {
      DocumentSnapshot<Map<String, dynamic>>? cursor;
      for (var page = 0; page < _maxSweepPages; page++) {
        var query = _notifications
            .where('recipientUid', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .limit(_sweepPageSize);
        if (cursor != null) query = query.startAfterDocument(cursor);

        final snap = await query.get();
        if (snap.docs.isEmpty) return;
        cursor = snap.docs.last;

        final hits = snap.docs.where((d) => selects(d.data())).toList();
        if (hits.isNotEmpty) {
          final batch = _firestore.batch();
          for (final d in hits) {
            apply(batch, d.reference);
          }
          await batch.commit();
        }
        // A short page is the last page.
        if (snap.docs.length < _sweepPageSize) return;
      }
      throw ServerException(
        'There were too many notifications to do that in one go. '
        'Please try again.',
      );
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? failureMessage);
    }
  }
}
