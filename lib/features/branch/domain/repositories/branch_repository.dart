import 'dart:io';

import 'package:drop/features/branch/domain/branch_geofence.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';

/// Contract for branch data access (Phase 5). Admin-only writes are enforced
/// server-side in `firestore.rules` (`branches/{branchId}`).
abstract class BranchRepository {
  /// Returns the branches. Cached in memory for a short TTL and shared across
  /// every caller (one repository instance); [forceRefresh] bypasses the cache.
  /// The cache is invalidated automatically after any branch write.
  Future<List<BranchEntity>> getBranches({
    bool includeDeleted = false,
    bool forceRefresh = false,
  });
  /// One branch by id, resolved from the same cached list as [getBranches].
  /// Null when the branch is unknown or soft-deleted. Any signed-in user may
  /// read branches, so this is the seam a role-scoped feature uses to resolve
  /// its own branch's configuration (e.g. `salesTargetEnabled`).
  Future<BranchEntity?> getBranch(String branchId, {bool forceRefresh = false});

  Future<BranchEntity> createBranch(BranchEntity branch);
  Future<void> updateBranch(BranchEntity branch);
  Future<void> setBranchActive(String branchId, bool isActive);

  /// Persists the branch's attendance [geofence] (dedicated path so a general
  /// branch-form save never clobbers it). Admin-only per `firestore.rules`.
  Future<void> setGeofence(String branchId, BranchGeofence geofence);

  /// Soft delete — marks the branch deleted/inactive rather than removing it.
  Future<void> deleteBranch(String branchId);

  /// Uploads a branch logo ([isLogo] true) or cover image, persists its URL on
  /// the branch doc, and returns the download URL. (§8 Branch Media.)
  Future<String> uploadBranchImage(
    String branchId,
    File file, {
    required bool isLogo,
  });
}
