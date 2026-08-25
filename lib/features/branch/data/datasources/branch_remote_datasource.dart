import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:opshub/core/constants/app_constants.dart';
import 'package:opshub/core/errors/exceptions.dart';
import 'package:opshub/features/branch/data/models/branch_model.dart';
import 'package:opshub/features/branch/domain/branch_geofence.dart';

abstract class BranchRemoteDataSource {
  /// All branches; soft-deleted ones are excluded unless [includeDeleted].
  Future<List<BranchModel>> getBranches({bool includeDeleted = false});
  Future<BranchModel> createBranch(BranchModel branch);
  Future<void> updateBranch(BranchModel branch);
  Future<void> setBranchActive(String branchId, bool isActive);
  Future<void> softDeleteBranch(String branchId);

  /// Writes the branch's attendance geofence (dedicated field path so a general
  /// branch-form save never clobbers it).
  Future<void> setGeofence(String branchId, BranchGeofence geofence);

  /// Uploads a branch **logo** ([isLogo] true) or **cover** image to Storage,
  /// writes the resulting URL onto `branches/{branchId}` (so the field never
  /// rides through the edit form's `toMap`), and returns the download URL.
  /// (§8 Branch Media.)
  Future<String> uploadBranchImage(
    String branchId,
    File file, {
    required bool isLogo,
  });
}

class BranchRemoteDataSourceImpl implements BranchRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  BranchRemoteDataSourceImpl(this._firestore, this._storage);

  CollectionReference<Map<String, dynamic>> get _branches =>
      _firestore.collection(AppConstants.branchesCollection);

  @override
  Future<List<BranchModel>> getBranches({bool includeDeleted = false}) async {
    try {
      final snap = await _branches.orderBy('name').get();
      final all =
          snap.docs.map((d) => BranchModel.fromMap(d.data(), id: d.id));
      return (includeDeleted ? all : all.where((b) => b.deletedAt == null))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to load branches.');
    }
  }

  @override
  Future<BranchModel> createBranch(BranchModel branch) async {
    try {
      final docRef = _branches.doc();
      final created = branch.copyWithId(docRef.id);
      await docRef.set({
        ...created.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return created;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to create branch.');
    }
  }

  @override
  Future<void> updateBranch(BranchModel branch) async {
    try {
      await _branches.doc(branch.id).set({
        ...branch.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to update branch.');
    }
  }

  @override
  Future<void> setBranchActive(String branchId, bool isActive) async {
    try {
      await _branches.doc(branchId).set({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to update branch.');
    }
  }

  static const _uploadTimeout = Duration(seconds: 60);

  @override
  Future<String> uploadBranchImage(
    String branchId,
    File file, {
    required bool isLogo,
  }) async {
    final field = isLogo ? 'logoUrl' : 'coverUrl';
    final path = 'branches/$branchId/${isLogo ? 'logo' : 'cover'}.jpg';
    try {
      // Fixed path → overwrites the previous image; Firebase issues a fresh
      // token on overwrite so the saved URL changes (no stale cache).
      final ref = _storage.ref(path);
      final task =
          ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      final snapshot = await task.timeout(
        _uploadTimeout,
        onTimeout: () {
          task.cancel();
          throw const ServerException(
              'Upload timed out. Check your connection and try again.');
        },
      );
      final url = await snapshot.ref
          .getDownloadURL()
          .timeout(const Duration(seconds: 20));
      // Persist the URL on the branch doc (admin-only write per firestore.rules).
      await _branches.doc(branchId).set({
        field: url,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return url;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to upload branch image.');
    }
  }

  @override
  Future<void> setGeofence(String branchId, BranchGeofence geofence) async {
    try {
      await _branches.doc(branchId).set({
        'geofence': geofence.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to save the branch location.');
    }
  }

  @override
  Future<void> softDeleteBranch(String branchId) async {
    try {
      // Soft delete: keep the doc (shifts/tasks/users may reference it) but mark
      // it deleted + inactive so it drops out of the active branch list.
      await _branches.doc(branchId).set({
        'deletedAt': FieldValue.serverTimestamp(),
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Failed to delete branch.');
    }
  }
}
