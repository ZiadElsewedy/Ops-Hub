import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drop/core/enums/sales_submission_status.dart';
import 'package:drop/core/extensions/firestore_extensions.dart';
import 'package:drop/features/sales/domain/entities/daily_sales_submission_entity.dart';

class DailySalesSubmissionModel {
  const DailySalesSubmissionModel({
    required this.id,
    required this.branchId,
    required this.monthKey,
    required this.businessDateKey,
    this.businessTimeZone = 'Africa/Cairo',
    this.amountPiastres = 0,
    this.status = SalesSubmissionStatus.pending,
    this.revision = 1,
    this.approvedRevision,
    this.submittedById,
    this.submittedByName,
    this.submittedAt,
    this.lastEditedById,
    this.lastEditedByName,
    this.lastEditedAt,
    this.decisionById,
    this.decisionByName,
    this.decisionByRole,
    this.decisionAt,
    this.decisionReason,
    this.createdAt,
    this.updatedAt,
    this.schemaVersion = 1,
  });
  final String id, branchId, monthKey, businessDateKey, businessTimeZone;
  final int amountPiastres, revision, schemaVersion;
  final SalesSubmissionStatus status;
  final int? approvedRevision;
  final String? submittedById,
      submittedByName,
      lastEditedById,
      lastEditedByName,
      decisionById,
      decisionByName,
      decisionByRole,
      decisionReason;
  final DateTime? submittedAt, lastEditedAt, decisionAt, createdAt, updatedAt;
  factory DailySalesSubmissionModel.fromMap(
    Map<String, dynamic> map, {
    String? id,
  }) => DailySalesSubmissionModel(
    id: id ?? _string(map['id']) ?? '',
    branchId: _string(map['branchId']) ?? '',
    monthKey: _string(map['monthKey']) ?? '',
    businessDateKey: _string(map['businessDateKey']) ?? '',
    businessTimeZone: _string(map['businessTimeZone']) ?? 'Africa/Cairo',
    amountPiastres: _int(map['amountPiastres']),
    status: SalesSubmissionStatus.fromString(_string(map['status'])),
    revision: _int(map['revision'], 1),
    approvedRevision: _nullableInt(map['approvedRevision']),
    submittedById: _string(map['submittedById']),
    submittedByName: _string(map['submittedByName']),
    submittedAt: map.date('submittedAt'),
    lastEditedById: _string(map['lastEditedById']),
    lastEditedByName: _string(map['lastEditedByName']),
    lastEditedAt: map.date('lastEditedAt'),
    decisionById: _string(map['decisionById']),
    decisionByName: _string(map['decisionByName']),
    decisionByRole: _string(map['decisionByRole']),
    decisionAt: map.date('decisionAt'),
    decisionReason: _string(map['decisionReason']),
    createdAt: map.date('createdAt'),
    updatedAt: map.date('updatedAt'),
    schemaVersion: _int(map['schemaVersion'], 1),
  );
  factory DailySalesSubmissionModel.fromEntity(DailySalesSubmissionEntity e) =>
      DailySalesSubmissionModel(
        id: e.id,
        branchId: e.branchId,
        monthKey: e.monthKey,
        businessDateKey: e.businessDateKey,
        businessTimeZone: e.businessTimeZone,
        amountPiastres: e.amountPiastres,
        status: e.status,
        revision: e.revision,
        approvedRevision: e.approvedRevision,
        submittedById: e.submittedById,
        submittedByName: e.submittedByName,
        submittedAt: e.submittedAt,
        lastEditedById: e.lastEditedById,
        lastEditedByName: e.lastEditedByName,
        lastEditedAt: e.lastEditedAt,
        decisionById: e.decisionById,
        decisionByName: e.decisionByName,
        decisionByRole: e.decisionByRole,
        decisionAt: e.decisionAt,
        decisionReason: e.decisionReason,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
        schemaVersion: e.schemaVersion,
      );
  Map<String, dynamic> toMap() => {
    'id': id,
    'branchId': branchId,
    'monthKey': monthKey,
    'businessDateKey': businessDateKey,
    'businessTimeZone': businessTimeZone,
    'amountPiastres': amountPiastres,
    'status': status.value,
    'revision': revision,
    'approvedRevision': approvedRevision,
    'submittedById': submittedById,
    'submittedByName': submittedByName,
    'submittedAt': _timestamp(submittedAt),
    'lastEditedById': lastEditedById,
    'lastEditedByName': lastEditedByName,
    'lastEditedAt': _timestamp(lastEditedAt),
    'decisionById': decisionById,
    'decisionByName': decisionByName,
    'decisionByRole': decisionByRole,
    'decisionAt': _timestamp(decisionAt),
    'decisionReason': decisionReason,
    'createdAt': _timestamp(createdAt),
    'updatedAt': _timestamp(updatedAt),
    'schemaVersion': schemaVersion,
  };
  DailySalesSubmissionEntity toEntity() => DailySalesSubmissionEntity(
    id: id,
    branchId: branchId,
    monthKey: monthKey,
    businessDateKey: businessDateKey,
    businessTimeZone: businessTimeZone,
    amountPiastres: amountPiastres,
    status: status,
    revision: revision,
    approvedRevision: approvedRevision,
    submittedById: submittedById,
    submittedByName: submittedByName,
    submittedAt: submittedAt,
    lastEditedById: lastEditedById,
    lastEditedByName: lastEditedByName,
    lastEditedAt: lastEditedAt,
    decisionById: decisionById,
    decisionByName: decisionByName,
    decisionByRole: decisionByRole,
    decisionAt: decisionAt,
    decisionReason: decisionReason,
    createdAt: createdAt,
    updatedAt: updatedAt,
    schemaVersion: schemaVersion,
  );
  static String? _string(dynamic v) => v is String ? v : null;
  static int _int(dynamic v, [int fallback = 0]) =>
      v is num ? v.toInt() : fallback;
  static int? _nullableInt(dynamic v) => v is num ? v.toInt() : null;
  static Timestamp? _timestamp(DateTime? v) =>
      v == null ? null : Timestamp.fromDate(v);
}
