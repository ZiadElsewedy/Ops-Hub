import 'package:drop/core/enums/broadcast_audience.dart';
import 'package:drop/core/enums/broadcast_category.dart';
import 'package:drop/core/enums/broadcast_recurrence.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/features/communications/domain/recurrence_rule.dart';

/// A scheduled / recurring broadcast (Communications Center — Phase 2 Commit 4).
/// Persisted at `broadcastSchedules/{id}`; the `runBroadcastSchedules` Cloud
/// Function fires due schedules through the same `dispatchBroadcast` engine the
/// instant-send uses, then advances [nextRunAt] from the recurrence rule.
///
/// **Plain immutable class (not freezed) by design** — a deliberate choice for a
/// value object with this many fields (no generated-file churn). It still honours
/// the domain-layer contract (pure Dart, no Flutter/Firebase imports).
/// [targetUserIds] for a `custom` schedule lives on the model/doc (not needed for
/// list display), mirroring the instant-send design.
class BroadcastScheduleEntity {
  final String id;

  // ── Broadcast content ──
  final String title;
  final String message;
  final BroadcastCategory category;
  final bool sendsPush;

  // ── Targeting ──
  final BroadcastAudience audience;
  final String? branchId;
  final String roleFilter;

  // ── Sender ──
  final String senderId;
  final String senderName;
  final UserRole senderRole;

  // ── Recurrence ──
  final BroadcastRecurrence recurrenceType;
  final int interval; // custom = every N days
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? nextRunAt;
  final bool enabled;
  final DateTime? lastRunAt;
  final int runCount;
  final DateTime? createdAt;

  const BroadcastScheduleEntity({
    required this.id,
    required this.title,
    required this.message,
    this.category = BroadcastCategory.announcement,
    this.sendsPush = true,
    this.audience = BroadcastAudience.allBranches,
    this.branchId,
    this.roleFilter = 'all',
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

  bool get isRecurring => recurrenceType.isRecurring;

  /// Whether the schedule is currently live (enabled + has a future run that
  /// hasn't passed its end date).
  bool isActive({DateTime? now}) => RecurrenceRule.isActive(
    enabled,
    nextRunAt: nextRunAt,
    endDate: endDate,
    now: now,
  );

  /// Whether the schedule has finished (one-time already run, or past endDate).
  bool get isCompleted => nextRunAt == null;

  BroadcastScheduleEntity copyWith({
    String? id,
    bool? enabled,
    DateTime? nextRunAt,
    DateTime? lastRunAt,
    int? runCount,
    DateTime? endDate,
    BroadcastRecurrence? recurrenceType,
    int? interval,
  }) => BroadcastScheduleEntity(
    id: id ?? this.id,
    title: title,
    message: message,
    category: category,
    sendsPush: sendsPush,
    audience: audience,
    branchId: branchId,
    roleFilter: roleFilter,
    senderId: senderId,
    senderName: senderName,
    senderRole: senderRole,
    recurrenceType: recurrenceType ?? this.recurrenceType,
    interval: interval ?? this.interval,
    startDate: startDate,
    endDate: endDate ?? this.endDate,
    nextRunAt: nextRunAt ?? this.nextRunAt,
    enabled: enabled ?? this.enabled,
    lastRunAt: lastRunAt ?? this.lastRunAt,
    runCount: runCount ?? this.runCount,
    createdAt: createdAt,
  );
}
