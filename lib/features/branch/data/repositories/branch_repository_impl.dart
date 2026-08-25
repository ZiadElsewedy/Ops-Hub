import 'dart:io';

import 'package:opshub/core/errors/exceptions.dart';
import 'package:opshub/core/errors/failures.dart';
import 'package:opshub/core/network/network_guard.dart';
import 'package:opshub/features/branch/data/datasources/branch_remote_datasource.dart';
import 'package:opshub/features/branch/data/models/branch_model.dart';
import 'package:opshub/features/branch/domain/branch_geofence.dart';
import 'package:opshub/features/branch/domain/entities/branch_entity.dart';
import 'package:opshub/features/branch/domain/repositories/branch_repository.dart';

class BranchRepositoryImpl implements BranchRepository {
  final BranchRemoteDataSource _remote;

  BranchRepositoryImpl(this._remote);

  // In-memory cache of the active (non-deleted) branch list, shared across every
  // caller since the repository is a single instance. Branches change rarely and
  // are global (not user-scoped), so a 10-minute TTL + invalidate-on-write keeps
  // the many branch reads (cubit, pickers, task branch-names) off Firestore
  // without risking staleness.
  static const _branchesTtl = Duration(minutes: 10);
  List<BranchEntity>? _cachedBranches;
  DateTime? _branchesFetchedAt;

  bool get _branchesFresh =>
      _cachedBranches != null &&
      _branchesFetchedAt != null &&
      DateTime.now().difference(_branchesFetchedAt!) < _branchesTtl;

  @override
  Future<List<BranchEntity>> getBranches({
    bool includeDeleted = false,
    bool forceRefresh = false,
  }) async {
    // The includeDeleted variant is admin-rare and never cached — always fresh.
    if (includeDeleted) return _fetchBranches(includeDeleted: true);

    if (!forceRefresh && _branchesFresh) return _cachedBranches!;
    final list = await _fetchBranches(includeDeleted: false);
    _cachedBranches = list;
    _branchesFetchedAt = DateTime.now();
    return list;
  }

  @override
  Future<BranchEntity?> getBranch(
    String branchId, {
    bool forceRefresh = false,
  }) async {
    if (branchId.isEmpty) return null;
    final branches = await getBranches(forceRefresh: forceRefresh);
    for (final branch in branches) {
      if (branch.id == branchId) return branch;
    }
    return null;
  }

  Future<List<BranchEntity>> _fetchBranches({
    required bool includeDeleted,
  }) async {
    try {
      final models = await _remote.getBranches(includeDeleted: includeDeleted);
      return models.map((m) => m.toEntity()).toList();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  void _invalidateBranches() {
    _cachedBranches = null;
    _branchesFetchedAt = null;
  }

  @override
  Future<BranchEntity> createBranch(BranchEntity branch) async {
    NetworkGuard.ensureWritable();
    try {
      final created = await _remote.createBranch(BranchModel.fromEntity(branch));
      _invalidateBranches();
      return created.toEntity();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> updateBranch(BranchEntity branch) async {
    NetworkGuard.ensureWritable();
    try {
      await _remote.updateBranch(BranchModel.fromEntity(branch));
      _invalidateBranches();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> setBranchActive(String branchId, bool isActive) async {
    NetworkGuard.ensureWritable();
    try {
      await _remote.setBranchActive(branchId, isActive);
      _invalidateBranches();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> setGeofence(String branchId, BranchGeofence geofence) async {
    NetworkGuard.ensureWritable();
    try {
      await _remote.setGeofence(branchId, geofence);
      _invalidateBranches();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> deleteBranch(String branchId) async {
    NetworkGuard.ensureWritable();
    try {
      await _remote.softDeleteBranch(branchId);
      _invalidateBranches();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<String> uploadBranchImage(
    String branchId,
    File file, {
    required bool isLogo,
  }) async {
    try {
      final url =
          await _remote.uploadBranchImage(branchId, file, isLogo: isLogo);
      // The URL is now on the branch doc — drop the cache so the next read
      // (and the cubit reload) reflects the new media everywhere.
      _invalidateBranches();
      return url;
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }
}
