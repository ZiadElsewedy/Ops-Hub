import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:opshub/features/branch/domain/branch_geofence.dart';
import 'package:opshub/features/schedule/domain/swap_policy.dart';

part 'branch_entity.freezed.dart';

/// A store branch (Phase 5). Branches scope the whole app: managers and
/// employees belong to a branch via `users/{uid}.branchId`, and shifts/tasks
/// carry a `branchId`. Admin-only to create/edit; "delete" is a soft delete
/// ([deletedAt] set), so historical references stay intact.
@freezed
class BranchEntity with _$BranchEntity {
  const BranchEntity._();

  const factory BranchEntity({
    required String id,
    required String name,
    /// Optional area / address label.
    String? location,
    @Default(true) bool isActive,
    /// Branch **logo** (square mark) — Storage `branches/{id}/logo.jpg`. Drives
    /// [BranchAvatar]; null falls back to initials. (§8 Branch Media.)
    String? logoUrl,
    /// Branch **cover** banner — Storage `branches/{id}/cover.jpg`. Null = none.
    String? coverUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    /// Soft-delete marker; null while the branch is live.
    DateTime? deletedAt,
    /// Optional branch-level shift-swap rules (role compatibility, rest hours).
    /// Null = [SwapPolicy.permissive] (any role can swap, no rest rule). Stored
    /// as a nested map under `swapPolicy`.
    SwapPolicy? swapPolicy,

    /// Whether this branch's **managers** may clock in / out. Employees always
    /// can. Defaults to true so branches created before this field existed keep
    /// the clock behaviour they already had.
    @Default(true) bool managersCanClock,

    /// Optional attendance **geofence** (lat/lng · allowed radius · min GPS
    /// accuracy). Null = GPS attendance not configured here yet. Stored as a
    /// nested map under `geofence`.
    BranchGeofence? geofence,

    /// Whether this branch runs the **monthly sales target** workflow. Not every
    /// branch sells: when this is false the feature behaves as if it does not
    /// exist — no Home card, no sales pages, no target management, no
    /// submissions. Admin-only to toggle (branch writes are admin-only).
    ///
    /// Defaults to **false** so a branch is opted in deliberately rather than
    /// inheriting a workflow it does not run.
    @Default(false) bool salesTargetEnabled,
  }) = _BranchEntity;

  bool get isDeleted => deletedAt != null;

  /// The branch's swap rules, or the permissive default when none is set.
  SwapPolicy get effectiveSwapPolicy => swapPolicy ?? SwapPolicy.permissive;

  /// Whether an admin has configured this branch's attendance geofence.
  bool get hasGeofence => geofence != null;
}
