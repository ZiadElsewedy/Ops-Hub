import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:opshub/core/extensions/firestore_extensions.dart';
import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/enums/swap_status.dart';
import 'package:opshub/features/schedule/domain/entities/shift_swap_entity.dart';

/// Firestore (de)serialization for [ShiftSwapEntity] — collection
/// `shift_swaps/{id}`.
class ShiftSwapModel {
  final String id;
  final String branchId;
  final DateTime weekStart;
  final ScheduleDay day;
  final ScheduleShift shift;
  final String requesterId;
  final String? requesterName;
  final String targetId;
  final String? targetName;
  final SwapStatus status;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? managerApprovedById;
  final String? managerApprovedByName;
  final DateTime? managerApprovedAt;

  const ShiftSwapModel({
    required this.id,
    required this.branchId,
    required this.weekStart,
    required this.day,
    required this.shift,
    required this.requesterId,
    this.requesterName,
    required this.targetId,
    this.targetName,
    this.status = SwapStatus.pending,
    this.note,
    this.createdAt,
    this.updatedAt,
    this.managerApprovedById,
    this.managerApprovedByName,
    this.managerApprovedAt,
  });

  factory ShiftSwapModel.fromMap(Map<String, dynamic> map, {String? id}) =>
      ShiftSwapModel(
        id: id ?? map['id'] as String? ?? '',
        branchId: map['branchId'] as String? ?? '',
        weekStart: map.date('weekStart') ?? DateTime(1970),
        day: ScheduleDay.fromString(map['day'] as String?),
        shift: ScheduleShift.fromString(map['shift'] as String?),
        requesterId: map['requesterId'] as String? ?? '',
        requesterName: map['requesterName'] as String?,
        targetId: map['targetId'] as String? ?? '',
        targetName: map['targetName'] as String?,
        status: SwapStatus.fromString(map['status'] as String?),
        note: map['note'] as String?,
        createdAt: map.date('createdAt'),
        updatedAt: map.date('updatedAt'),
        managerApprovedById: map['managerApprovedById'] as String?,
        managerApprovedByName: map['managerApprovedByName'] as String?,
        managerApprovedAt: map.date('managerApprovedAt'),
      );

  factory ShiftSwapModel.fromEntity(ShiftSwapEntity e) => ShiftSwapModel(
    id: e.id,
    branchId: e.branchId,
    weekStart: e.weekStart,
    day: e.day,
    shift: e.shift,
    requesterId: e.requesterId,
    requesterName: e.requesterName,
    targetId: e.targetId,
    targetName: e.targetName,
    status: e.status,
    note: e.note,
    createdAt: e.createdAt,
    updatedAt: e.updatedAt,
    managerApprovedById: e.managerApprovedById,
    managerApprovedByName: e.managerApprovedByName,
    managerApprovedAt: e.managerApprovedAt,
  );

  /// Persisted fields. `createdAt`/`updatedAt` are written by the datasource as
  /// server timestamps, so they're intentionally not included here.
  Map<String, dynamic> toMap() => {
    'id': id,
    'branchId': branchId,
    'weekStart': Timestamp.fromDate(weekStart),
    'day': day.value,
    'shift': shift.value,
    'requesterId': requesterId,
    'requesterName': requesterName,
    'targetId': targetId,
    'targetName': targetName,
    'status': status.value,
    'note': note,
    'managerApprovedById': managerApprovedById,
    'managerApprovedByName': managerApprovedByName,
    'managerApprovedAt': managerApprovedAt == null
        ? null
        : Timestamp.fromDate(managerApprovedAt!),
  };

  ShiftSwapModel copyWithId(String id) => ShiftSwapModel(
    id: id,
    branchId: branchId,
    weekStart: weekStart,
    day: day,
    shift: shift,
    requesterId: requesterId,
    requesterName: requesterName,
    targetId: targetId,
    targetName: targetName,
    status: status,
    note: note,
    createdAt: createdAt,
    updatedAt: updatedAt,
    managerApprovedById: managerApprovedById,
    managerApprovedByName: managerApprovedByName,
    managerApprovedAt: managerApprovedAt,
  );

  ShiftSwapEntity toEntity() => ShiftSwapEntity(
    id: id,
    branchId: branchId,
    weekStart: weekStart,
    day: day,
    shift: shift,
    requesterId: requesterId,
    requesterName: requesterName,
    targetId: targetId,
    targetName: targetName,
    status: status,
    note: note,
    createdAt: createdAt,
    updatedAt: updatedAt,
    managerApprovedById: managerApprovedById,
    managerApprovedByName: managerApprovedByName,
    managerApprovedAt: managerApprovedAt,
  );
}
