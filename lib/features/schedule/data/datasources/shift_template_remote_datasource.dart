import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:opshub/core/constants/app_constants.dart';
import 'package:opshub/core/enums/shift_template_role.dart';
import 'package:opshub/core/errors/exceptions.dart';
import 'package:opshub/features/schedule/data/models/shift_template_model.dart';
import 'package:opshub/features/schedule/domain/shift_template.dart';

/// Firestore access for shift templates (Schedule V2 · Pillar 5), collection
/// `shift_templates/{id}`. Branch/role access is enforced server-side in
/// `firestore.rules` (mirrors `weekly_schedules`).
abstract class ShiftTemplateRemoteDataSource {
  Stream<List<ShiftTemplateModel>> watchTemplates(String branchId);
  Future<List<ShiftTemplateModel>> getTemplates(String branchId);
  Future<void> upsertTemplate(ShiftTemplateModel template);
  Future<void> deleteTemplate(String id);

  /// Seeds the 3 standing templates for [branchId] **iff it has none**, then
  /// returns the resulting list. Deterministic ids (`{branch}__{role}`) keep it
  /// idempotent.
  Future<List<ShiftTemplateModel>> ensureDefaults(String branchId);
}

class ShiftTemplateRemoteDataSourceImpl implements ShiftTemplateRemoteDataSource {
  final FirebaseFirestore _firestore;

  ShiftTemplateRemoteDataSourceImpl(this._firestore);

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(AppConstants.shiftTemplatesCollection);

  static String templateId(String branchId, ShiftTemplateRole role) =>
      '${branchId}__${role.value}';

  List<ShiftTemplateModel> _sorted(
      Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final list =
        docs.map((d) => ShiftTemplateModel.fromMap(d.data(), id: d.id)).toList();
    // Morning → Weekday night → Weekend night → custom, then by name.
    list.sort((a, b) {
      final byRole = a.role.index.compareTo(b.role.index);
      return byRole != 0
          ? byRole
          : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  @override
  Stream<List<ShiftTemplateModel>> watchTemplates(String branchId) => _col
      .where('branchId', isEqualTo: branchId)
      .snapshots()
      .map((snap) => _sorted(snap.docs));

  @override
  Future<List<ShiftTemplateModel>> getTemplates(String branchId) async {
    try {
      final snap = await _col.where('branchId', isEqualTo: branchId).get();
      return _sorted(snap.docs);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load shift templates.');
    }
  }

  @override
  Future<void> upsertTemplate(ShiftTemplateModel template) async {
    try {
      await _col.doc(template.id).set({
        ...template.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to save the shift template.');
    }
  }

  @override
  Future<void> deleteTemplate(String id) async {
    try {
      await _col.doc(id).delete();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to delete the shift template.');
    }
  }

  @override
  Future<List<ShiftTemplateModel>> ensureDefaults(String branchId) async {
    try {
      final existing = await getTemplates(branchId);
      if (existing.isNotEmpty) return existing;
      final defaults = ShiftTemplateSet.defaultsFor(
        branchId,
        idFor: (role) => templateId(branchId, role),
      );
      final batch = _firestore.batch();
      for (final t in defaults) {
        batch.set(_col.doc(t.id), {
          ...ShiftTemplateModel.fromEntity(t).toMap(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      return [for (final t in defaults) ShiftTemplateModel.fromEntity(t)];
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to set up shift templates.');
    }
  }
}
