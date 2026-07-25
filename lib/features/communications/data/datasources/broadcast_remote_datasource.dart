import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:drop/core/constants/app_constants.dart';
import 'package:drop/core/utils/app_logger.dart';
import 'package:drop/core/errors/exceptions.dart';
import 'package:drop/features/communications/data/models/broadcast_model.dart';

abstract class BroadcastRemoteDataSource {
  /// Sends a broadcast through the **callable `sendBroadcast` Cloud Function**
  /// (the authoritative engine: validates permissions, resolves recipients,
  /// persists the doc, pushes the notification). Returns the model carrying the
  /// generated id + the resolved recipient count. [targetUserIds] is the
  /// recipient list for a `custom` send; [roleFilter] restricts a branch/all
  /// send to one role.
  Future<BroadcastModel> sendBroadcast(
    BroadcastModel broadcast, {
    List<String> targetUserIds,
    String roleFilter,
  });

  /// [branchId] null → all broadcasts (admin). Set → that branch's broadcasts
  /// plus all-branches ones (the `''` sentinel). Direct messages never appear
  /// here (they use the [BroadcastModel.directBranchMarker]).
  Stream<List<BroadcastModel>> watchBroadcasts({String? branchId});

  /// One-shot read of a single `broadcasts/{id}` doc (the deep-link path).
  /// Returns `null` when the doc is missing or unreadable to the caller.
  Future<BroadcastModel?> getBroadcast(String id);

  /// Archives / unarchives a broadcast (sets / clears `archivedAt`). A
  /// field-restricted client write — the `broadcasts` rule permits an admin /
  /// owning-branch manager to touch **only** the lifecycle fields, never content
  /// or delivery stats.
  Future<void> setArchived(String id, bool archived);

  /// Permanently deletes the `broadcasts/{id}` doc. The `broadcasts` rule permits
  /// this for an admin, the original sender, or the owning-branch manager.
  Future<void> delete(String id);
}

class BroadcastRemoteDataSourceImpl implements BroadcastRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  BroadcastRemoteDataSourceImpl(this._firestore, this._functions);

  CollectionReference<Map<String, dynamic>> get _broadcasts =>
      _firestore.collection(AppConstants.broadcastsCollection);

  @override
  Future<BroadcastModel> sendBroadcast(
    BroadcastModel broadcast, {
    List<String> targetUserIds = const [],
    String roleFilter = '',
  }) async {
    try {
      final callable = _functions.httpsCallable('sendBroadcast');
      final payload = {
        ...broadcast.toCallablePayload(),
        'targetUserIds': targetUserIds,
        'roleFilter': roleFilter,
      };
      final result = await callable.call<Map<String, dynamic>>(payload);
      final data = result.data;
      return broadcast.copyWith(
        id: data['broadcastId'] as String? ?? '',
        recipientCount: (data['recipientCount'] as num?)?.toInt(),
        deliveredCount: (data['deliveredCount'] as num?)?.toInt(),
      );
    } on FirebaseFunctionsException catch (e, st) {
      AppLog.error('communications',
          'sendBroadcast callable failed: code=${e.code} message=${e.message}',
          e, st);
      throw ServerException(_friendlyFunctionsError(e));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to send broadcast.');
    }
  }

  /// Maps a callable failure to a user-facing message. The function raises
  /// full-sentence `HttpsError` messages for permission/validation problems
  /// (surfaced verbatim); the transport/gateway layer raises single upper-case
  /// codes ("UNAUTHENTICATED", "INTERNAL", …) which are replaced with guidance.
  String _friendlyFunctionsError(FirebaseFunctionsException e) {
    final msg = (e.message ?? '').trim();
    final looksHuman = msg.contains(' '); // a real sentence vs. a raw code token
    if (looksHuman) return msg;
    switch (e.code) {
      case 'unauthenticated':
      case 'permission-denied':
        // Almost always the send engine being unreachable (the `sendBroadcast`
        // Cloud Function not deployed / not invokable yet), not a real auth loss.
        return 'Couldn’t reach the broadcast service. Please try again in a '
            'moment.';
      case 'unavailable':
        return 'Network problem — check your connection and try again.';
      case 'not-found':
        return 'The broadcast service isn’t available yet. Please try again '
            'later.';
      default:
        return 'Couldn’t send the broadcast right now. Please try again.';
    }
  }

  @override
  Future<void> setArchived(String id, bool archived) async {
    try {
      await _broadcasts.doc(id).set(
        {'archivedAt': archived ? FieldValue.serverTimestamp() : null},
        SetOptions(merge: true),
      );
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to update the broadcast.');
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _broadcasts.doc(id).delete();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to delete the broadcast.');
    }
  }

  @override
  Future<BroadcastModel?> getBroadcast(String id) async {
    if (id.isEmpty) return null;
    try {
      final doc = await _broadcasts.doc(id).get();
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return BroadcastModel.fromMap(data, id: doc.id);
    } on FirebaseException catch (e, st) {
      // A permission-denied here means the caller can't read this broadcast
      // (not a recipient) — treat as "unavailable", never a crash.
      AppLog.error('communications', 'getBroadcast failed: ${e.code}', e, st);
      return null;
    }
  }

  @override
  Stream<List<BroadcastModel>> watchBroadcasts({String? branchId}) {
    // Admin (no branch): server-side newest-first (single-field order, index-free).
    // Branch member: a `whereIn` on the single `branchId` field — their branch +
    // the all-branches `''` sentinel — which is provably safe under the read rule
    // and uses the automatic index. A filter + orderBy on a different field would
    // need a composite index (the project avoids those), so the branch feed is
    // ordered client-side via [_newestFirst]. Direct messages carry the
    // [BroadcastModel.directBranchMarker] branchId, so neither query returns them.
    final Query<Map<String, dynamic>> query = branchId == null
        ? _broadcasts.orderBy('createdAt', descending: true)
        : _broadcasts.where('branchId', whereIn: [branchId, '']);

    return query.snapshots().map((snap) {
      final models =
          snap.docs.map((d) => BroadcastModel.fromMap(d.data(), id: d.id));
      return branchId == null
          ? models.toList()
          : (models.toList()..sort(_newestFirst));
    });
  }

  /// Newest first; a doc with a pending server timestamp (`createdAt == null`)
  /// sorts to the top.
  int _newestFirst(BroadcastModel a, BroadcastModel b) {
    final ad = a.createdAt, bd = b.createdAt;
    if (ad == null && bd == null) return 0;
    if (ad == null) return -1;
    if (bd == null) return 1;
    return bd.compareTo(ad);
  }
}
