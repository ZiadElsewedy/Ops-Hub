import 'package:drop/core/extensions/firestore_extensions.dart';
import 'package:drop/features/branch/domain/branch_geofence.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/schedule/domain/swap_policy.dart';

/// Firestore (de)serialization for [BranchEntity] — collection `branches/{id}`.
class BranchModel {
  final String id;
  final String name;
  final String? location;
  final bool isActive;
  final String? logoUrl;
  final String? coverUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final SwapPolicy? swapPolicy;
  final bool managersCanClock;
  final BranchGeofence? geofence;

  const BranchModel({
    required this.id,
    required this.name,
    this.location,
    this.isActive = true,
    this.logoUrl,
    this.coverUrl,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.swapPolicy,
    this.managersCanClock = true,
    this.geofence,
  });

  factory BranchModel.fromMap(Map<String, dynamic> map, {String? id}) =>
      BranchModel(
        id: id ?? map['id'] as String? ?? '',
        name: map['name'] as String? ?? '',
        location: map['location'] as String?,
        isActive: map['isActive'] as bool? ?? true,
        logoUrl: map['logoUrl'] as String?,
        coverUrl: map['coverUrl'] as String?,
        createdAt: map.date('createdAt'),
        updatedAt: map.date('updatedAt'),
        deletedAt: map.date('deletedAt'),
        swapPolicy: map['swapPolicy'] == null
            ? null
            : SwapPolicy.fromMap(
                (map['swapPolicy'] as Map).cast<String, dynamic>()),
        managersCanClock: map['managersCanClock'] as bool? ?? true,
        geofence: map['geofence'] == null
            ? null
            : BranchGeofence.fromMap(
                (map['geofence'] as Map).cast<String, dynamic>()),
      );

  factory BranchModel.fromEntity(BranchEntity e) => BranchModel(
        id: e.id,
        name: e.name,
        location: e.location,
        isActive: e.isActive,
        logoUrl: e.logoUrl,
        coverUrl: e.coverUrl,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
        deletedAt: e.deletedAt,
        swapPolicy: e.swapPolicy,
        managersCanClock: e.managersCanClock,
        geofence: e.geofence,
      );

  /// Writable fields. Timestamps + `deletedAt` are managed by the datasource
  /// (server timestamps / soft-delete), so they're excluded here. Media URLs are
  /// written by the dedicated upload path (`setBranchImage`), not `toMap`, so an
  /// edit-form save never clobbers an existing logo/cover. [swapPolicy] **is**
  /// included — it is edited inside the same branch form, which always carries the
  /// loaded policy, so a save can't clobber it; null = permissive.
  /// [managersCanClock] is also included because the same form always carries
  /// its loaded value. [geofence] is **omitted** here so a general branch-form
  /// save never clobbers it — the
  /// attendance geofence is written by its own dedicated editor path
  /// (`BranchRepository.setGeofence`).
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'location': location,
        'isActive': isActive,
        'swapPolicy': swapPolicy?.toMap(),
        'managersCanClock': managersCanClock,
      };

  BranchModel copyWithId(String id) => BranchModel(
        id: id,
        name: name,
        location: location,
        isActive: isActive,
        logoUrl: logoUrl,
        coverUrl: coverUrl,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
        swapPolicy: swapPolicy,
        managersCanClock: managersCanClock,
        geofence: geofence,
      );

  BranchEntity toEntity() => BranchEntity(
        id: id,
        name: name,
        location: location,
        isActive: isActive,
        logoUrl: logoUrl,
        coverUrl: coverUrl,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
        swapPolicy: swapPolicy,
        managersCanClock: managersCanClock,
        geofence: geofence,
      );
}
