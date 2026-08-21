import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:opshub/core/constants/app_constants.dart';
import 'package:opshub/core/errors/exceptions.dart';
import 'package:opshub/features/communications/data/models/broadcast_template_model.dart';

abstract class BroadcastTemplateRemoteDataSource {
  /// All templates (global + per-branch). The collection is small, so a full
  /// read is acceptable and branch filtering is applied client-side (mirrors
  /// `task_templates`).
  Future<List<BroadcastTemplateModel>> getTemplates();
  Future<BroadcastTemplateModel> create(BroadcastTemplateModel template);
  Future<void> update(BroadcastTemplateModel template);
  Future<void> setFavorite(String id, bool favorite);
  Future<void> incrementUsage(String id);
  Future<void> delete(String id);
}

class BroadcastTemplateRemoteDataSourceImpl
    implements BroadcastTemplateRemoteDataSource {
  final FirebaseFirestore _firestore;

  BroadcastTemplateRemoteDataSourceImpl(this._firestore);

  CollectionReference<Map<String, dynamic>> get _templates =>
      _firestore.collection(AppConstants.broadcastTemplatesCollection);

  @override
  Future<List<BroadcastTemplateModel>> getTemplates() async {
    try {
      final snap = await _templates.get();
      return snap.docs
          .map((d) => BroadcastTemplateModel.fromMap(d.data(), id: d.id))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load templates.');
    }
  }

  @override
  Future<BroadcastTemplateModel> create(BroadcastTemplateModel template) async {
    try {
      final ref = _templates.doc();
      final created = template.copyWithId(ref.id);
      await ref.set({
        ...created.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return created;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to save template.');
    }
  }

  @override
  Future<void> update(BroadcastTemplateModel template) async {
    try {
      await _templates.doc(template.id).set({
        ...template.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to update template.');
    }
  }

  @override
  Future<void> setFavorite(String id, bool favorite) async {
    try {
      await _templates.doc(id).set({
        'isFavorite': favorite,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to update template.');
    }
  }

  @override
  Future<void> incrementUsage(String id) async {
    try {
      await _templates.doc(id).set({
        'usageCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to update template.');
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _templates.doc(id).delete();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to delete template.');
    }
  }
}
