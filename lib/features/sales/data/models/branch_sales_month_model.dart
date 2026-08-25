import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:opshub/core/extensions/firestore_extensions.dart';
import 'package:opshub/features/sales/domain/entities/branch_sales_month_entity.dart';

class BranchSalesMonthModel {
  const BranchSalesMonthModel({
    required this.id,
    required this.branchId,
    required this.monthKey,
    this.timeZone = 'Africa/Cairo',
    this.targetPiastres = 0,
    this.targetRevision = 1,
    this.createdAt,
    this.updatedAt,
    this.createdById,
    this.createdByName,
    this.createdByRole,
    this.updatedById,
    this.updatedByName,
    this.updatedByRole,
    this.lastChangeReason,
    this.schemaVersion = 1,
  });
  final String id, branchId, monthKey, timeZone;
  final int targetPiastres, targetRevision, schemaVersion;
  final DateTime? createdAt, updatedAt;
  final String? createdById,
      createdByName,
      createdByRole,
      updatedById,
      updatedByName,
      updatedByRole,
      lastChangeReason;

  factory BranchSalesMonthModel.fromMap(
    Map<String, dynamic> map, {
    String? id,
  }) => BranchSalesMonthModel(
    id: id ?? _string(map['id']) ?? '',
    branchId: _string(map['branchId']) ?? '',
    monthKey: _string(map['monthKey']) ?? '',
    timeZone: _string(map['timeZone']) ?? 'Africa/Cairo',
    targetPiastres: _int(map['targetPiastres']),
    targetRevision: _int(map['targetRevision'], 1),
    createdAt: map.date('createdAt'),
    updatedAt: map.date('updatedAt'),
    createdById: _string(map['createdById']),
    createdByName: _string(map['createdByName']),
    createdByRole: _string(map['createdByRole']),
    updatedById: _string(map['updatedById']),
    updatedByName: _string(map['updatedByName']),
    updatedByRole: _string(map['updatedByRole']),
    lastChangeReason: _string(map['lastChangeReason']),
    schemaVersion: _int(map['schemaVersion'], 1),
  );
  factory BranchSalesMonthModel.fromEntity(BranchSalesMonthEntity e) =>
      BranchSalesMonthModel(
        id: e.id,
        branchId: e.branchId,
        monthKey: e.monthKey,
        timeZone: e.timeZone,
        targetPiastres: e.targetPiastres,
        targetRevision: e.targetRevision,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
        createdById: e.createdById,
        createdByName: e.createdByName,
        createdByRole: e.createdByRole,
        updatedById: e.updatedById,
        updatedByName: e.updatedByName,
        updatedByRole: e.updatedByRole,
        lastChangeReason: e.lastChangeReason,
        schemaVersion: e.schemaVersion,
      );
  Map<String, dynamic> toMap() => {
    'id': id,
    'branchId': branchId,
    'monthKey': monthKey,
    'timeZone': timeZone,
    'targetPiastres': targetPiastres,
    'targetRevision': targetRevision,
    'createdAt': _timestamp(createdAt),
    'updatedAt': _timestamp(updatedAt),
    'createdById': createdById,
    'createdByName': createdByName,
    'createdByRole': createdByRole,
    'updatedById': updatedById,
    'updatedByName': updatedByName,
    'updatedByRole': updatedByRole,
    'lastChangeReason': lastChangeReason,
    'schemaVersion': schemaVersion,
  };
  BranchSalesMonthEntity toEntity() => BranchSalesMonthEntity(
    id: id,
    branchId: branchId,
    monthKey: monthKey,
    timeZone: timeZone,
    targetPiastres: targetPiastres,
    targetRevision: targetRevision,
    createdAt: createdAt,
    updatedAt: updatedAt,
    createdById: createdById,
    createdByName: createdByName,
    createdByRole: createdByRole,
    updatedById: updatedById,
    updatedByName: updatedByName,
    updatedByRole: updatedByRole,
    lastChangeReason: lastChangeReason,
    schemaVersion: schemaVersion,
  );
  static String? _string(dynamic v) => v is String ? v : null;
  static int _int(dynamic v, [int fallback = 0]) =>
      v is num ? v.toInt() : fallback;
  static Timestamp? _timestamp(DateTime? value) =>
      value == null ? null : Timestamp.fromDate(value);
}
