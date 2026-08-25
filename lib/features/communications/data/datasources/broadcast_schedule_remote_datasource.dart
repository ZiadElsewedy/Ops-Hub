import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:opshub/core/constants/app_constants.dart';
import 'package:opshub/core/errors/exceptions.dart';
import 'package:opshub/features/communications/data/models/broadcast_schedule_model.dart';

abstract class BroadcastScheduleRemoteDataSource {
  /// All schedules for an admin; an own-created subset for a manager
  /// (single-field `senderId` query — index-free).
  Future<List<BroadcastScheduleModel>> getSchedules({
    required String uid,
    required bool isAdmin,
  });
  Future<BroadcastScheduleModel> create(BroadcastScheduleModel schedule);
  Future<void> update(BroadcastScheduleModel schedule);
  Future<void> setEnabled(String id, bool enabled);
  Future<void> delete(String id);
}

class BroadcastScheduleRemoteDataSourceImpl
    implements BroadcastScheduleRemoteDataSource {
  final FirebaseFirestore _firestore;

  BroadcastScheduleRemoteDataSourceImpl(this._firestore);

  CollectionReference<Map<String, dynamic>> get _schedules =>
      _firestore.collection(AppConstants.broadcastSchedulesCollection);

  @override
  Future<List<BroadcastScheduleModel>> getSchedules({
    required String uid,
    required bool isAdmin,
  }) async {
    try {
      final query = isAdmin
          ? await _schedules.get()
          : await _schedules.where('senderId', isEqualTo: uid).get();
      final list = query.docs
          .map((d) => BroadcastScheduleModel.fromMap(d.data(), id: d.id))
          .toList();
      // Client-sorted: soonest next-run first; completed (null) last.
      list.sort((a, b) {
        final an = a.nextRunAt, bn = b.nextRunAt;
        if (an == null && bn == null) return 0;
        if (an == null) return 1;
        if (bn == null) return -1;
        return an.compareTo(bn);
      });
      return list;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load schedules.');
    }
  }

  @override
  Future<BroadcastScheduleModel> create(BroadcastScheduleModel schedule) async {
    try {
      final ref = _schedules.doc();
      final created = schedule.copyWithId(ref.id);
      await ref.set({
        ...created.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      return created;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to create schedule.');
    }
  }

  @override
  Future<void> update(BroadcastScheduleModel schedule) async {
    try {
      await _schedules
          .doc(schedule.id)
          .set(schedule.toMap(), SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to update schedule.');
    }
  }

  @override
  Future<void> setEnabled(String id, bool enabled) async {
    try {
      await _schedules.doc(id).set({'enabled': enabled}, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to update schedule.');
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _schedules.doc(id).delete();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to cancel schedule.');
    }
  }
}
