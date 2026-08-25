import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:opshub/core/enums/broadcast_audience.dart';
import 'package:opshub/core/enums/broadcast_category.dart';
import 'package:opshub/core/enums/broadcast_recurrence.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/core/extensions/firestore_extensions.dart';
import 'package:opshub/features/communications/domain/entities/broadcast_schedule_entity.dart';

/// Firestore (de)serialization for [BroadcastScheduleEntity] — collection
/// `broadcastSchedules/{id}`. Hand-written like the project's other models.
/// [targetUserIds] (a `custom` schedule's recipients) lives on the model/doc
/// only; the scheduler Cloud Function reads it when dispatching.
class BroadcastScheduleModel {
  final String id;
  final String title;
  final String message;
  final BroadcastCategory category;
  final bool sendsPush;
  final BroadcastAudience audience;
  final String branchId; // '' for all-branches / non-branch
  final String roleFilter;
  final List<String> targetUserIds;
  final String senderId;
  final String senderName;
  final UserRole senderRole;
  final BroadcastRecurrence recurrenceType;
  final int interval;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? nextRunAt;
  final bool enabled;
  final DateTime? lastRunAt;
  final int runCount;
  final DateTime? createdAt;

  const BroadcastScheduleModel({
    required this.id,
    required this.title,
    required this.message,
    this.category = BroadcastCategory.announcement,
    this.sendsPush = true,
    this.audience = BroadcastAudience.allBranches,
    this.branchId = '',
    this.roleFilter = 'all',
    this.targetUserIds = const [],
    this.senderId = '',
    this.senderName = '',
    this.senderRole = UserRole.manager,
    this.recurrenceType = BroadcastRecurrence.oneTime,
    this.interval = 1,
    this.startDate,
    this.endDate,
    this.nextRunAt,
    this.enabled = true,
    this.lastRunAt,
    this.runCount = 0,
    this.createdAt,
  });

  factory BroadcastScheduleModel.fromMap(
    Map<String, dynamic> map, {
    String? id,
  }) => BroadcastScheduleModel(
    id: id ?? map['id'] as String? ?? '',
    title: map['title'] as String? ?? '',
    message: map['message'] as String? ?? '',
    category: BroadcastCategory.fromString(map['category'] as String?),
    sendsPush:
        map['sendsPush'] as bool? ??
        ((map['category'] as String?) != 'announcement'),
    audience: BroadcastAudience.fromString(map['audience'] as String?),
    branchId: map['branchId'] as String? ?? '',
    roleFilter: map['roleFilter'] as String? ?? 'all',
    targetUserIds:
        (map['targetUserIds'] as List?)?.map((e) => e.toString()).toList() ??
        const [],
    senderId: map['senderId'] as String? ?? '',
    senderName: map['senderName'] as String? ?? '',
    senderRole: UserRole.fromString(map['senderRole'] as String?),
    recurrenceType: BroadcastRecurrence.fromString(
      map['recurrenceType'] as String?,
    ),
    interval: (map['interval'] as num?)?.toInt() ?? 1,
    startDate: map.date('startDate'),
    endDate: map.date('endDate'),
    nextRunAt: map.date('nextRunAt'),
    enabled: map['enabled'] as bool? ?? true,
    lastRunAt: map.date('lastRunAt'),
    runCount: (map['runCount'] as num?)?.toInt() ?? 0,
    createdAt: map.date('createdAt'),
  );

  factory BroadcastScheduleModel.fromEntity(
    BroadcastScheduleEntity e, {
    List<String> targetUserIds = const [],
  }) => BroadcastScheduleModel(
    id: e.id,
    title: e.title,
    message: e.message,
    category: e.category,
    sendsPush: e.sendsPush,
    audience: e.audience,
    branchId: e.branchId ?? '',
    roleFilter: e.roleFilter,
    targetUserIds: targetUserIds,
    senderId: e.senderId,
    senderName: e.senderName,
    senderRole: e.senderRole,
    recurrenceType: e.recurrenceType,
    interval: e.interval,
    startDate: e.startDate,
    endDate: e.endDate,
    nextRunAt: e.nextRunAt,
    enabled: e.enabled,
    lastRunAt: e.lastRunAt,
    runCount: e.runCount,
    createdAt: e.createdAt,
  );

  Timestamp? _ts(DateTime? d) => d == null ? null : Timestamp.fromDate(d);

  /// Writable fields (`createdAt`/`runCount`/`lastRunAt` are managed
  /// server-side once running; written here on create with safe initial values).
  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'message': message,
    'category': category.value,
    'sendsPush': sendsPush,
    'audience': audience.value,
    'branchId': branchId,
    'roleFilter': roleFilter,
    'targetUserIds': targetUserIds,
    'senderId': senderId,
    'senderName': senderName,
    'senderRole': senderRole.value,
    'recurrenceType': recurrenceType.value,
    'interval': interval,
    'startDate': _ts(startDate),
    'endDate': _ts(endDate),
    'nextRunAt': _ts(nextRunAt),
    'enabled': enabled,
    'lastRunAt': _ts(lastRunAt),
    'runCount': runCount,
  };

  BroadcastScheduleModel copyWithId(String newId) => BroadcastScheduleModel(
    id: newId,
    title: title,
    message: message,
    category: category,
    sendsPush: sendsPush,
    audience: audience,
    branchId: branchId,
    roleFilter: roleFilter,
    targetUserIds: targetUserIds,
    senderId: senderId,
    senderName: senderName,
    senderRole: senderRole,
    recurrenceType: recurrenceType,
    interval: interval,
    startDate: startDate,
    endDate: endDate,
    nextRunAt: nextRunAt,
    enabled: enabled,
    lastRunAt: lastRunAt,
    runCount: runCount,
    createdAt: createdAt,
  );

  BroadcastScheduleEntity toEntity() => BroadcastScheduleEntity(
    id: id,
    title: title,
    message: message,
    category: category,
    sendsPush: sendsPush,
    audience: audience,
    branchId: branchId.isEmpty ? null : branchId,
    roleFilter: roleFilter,
    senderId: senderId,
    senderName: senderName,
    senderRole: senderRole,
    recurrenceType: recurrenceType,
    interval: interval,
    startDate: startDate,
    endDate: endDate,
    nextRunAt: nextRunAt,
    enabled: enabled,
    lastRunAt: lastRunAt,
    runCount: runCount,
    createdAt: createdAt,
  );
}
