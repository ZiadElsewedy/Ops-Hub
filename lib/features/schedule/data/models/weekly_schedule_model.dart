import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:opshub/core/extensions/firestore_extensions.dart';
import 'package:opshub/core/enums/leave_type.dart';
import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:opshub/features/schedule/domain/shift_hours.dart';
import 'package:opshub/features/schedule/domain/shift_plan.dart';

/// Firestore (de)serialization for [WeeklyScheduleEntity] — collection
/// `weekly_schedules/{id}`. The `assignments` map is stored as
/// `{ <day>: { <shift>: [uid, …] } }`, `dayNotes` as `{ <day>: text }`,
/// `leave` as `{ <day>: { <uid>: <type> } }`, and `shiftHours` overrides as
/// `{ <day>: { <shift>: { start, end } } }`, all with lower-case string keys.
class WeeklyScheduleModel {
  final String id;
  final String branchId;
  final DateTime weekStart;
  final Map<ScheduleDay, Map<ScheduleShift, List<String>>> assignments;
  final Map<ScheduleDay, String> dayNotes;
  final Map<ScheduleDay, Map<String, LeaveType>> leave;
  final Map<ScheduleDay, Map<ScheduleShift, ShiftHours>> shiftHours;
  final ShiftPlan? shiftPlan;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WeeklyScheduleModel({
    required this.id,
    required this.branchId,
    required this.weekStart,
    this.assignments = const {},
    this.dayNotes = const {},
    this.leave = const {},
    this.shiftHours = const {},
    this.shiftPlan,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  factory WeeklyScheduleModel.fromMap(Map<String, dynamic> map, {String? id}) {
    final raw = map['assignments'] as Map<String, dynamic>? ?? const {};
    final assignments = <ScheduleDay, Map<ScheduleShift, List<String>>>{};
    for (final day in ScheduleDay.values) {
      final dayMap = raw[day.value] as Map<String, dynamic>?;
      assignments[day] = {
        for (final shift in ScheduleShift.values)
          shift: (dayMap?[shift.value] as List?)
                  ?.whereType<String>()
                  .toList() ??
              <String>[],
      };
    }
    final rawNotes = map['dayNotes'] as Map<String, dynamic>? ?? const {};
    final dayNotes = <ScheduleDay, String>{
      for (final day in ScheduleDay.values)
        if (rawNotes[day.value] is String &&
            (rawNotes[day.value] as String).trim().isNotEmpty)
          day: rawNotes[day.value] as String,
    };
    final rawLeave = map['leave'] as Map<String, dynamic>? ?? const {};
    final leave = <ScheduleDay, Map<String, LeaveType>>{};
    for (final day in ScheduleDay.values) {
      final dayMap = rawLeave[day.value] as Map<String, dynamic>?;
      if (dayMap == null) continue;
      final entries = <String, LeaveType>{
        for (final e in dayMap.entries)
          if (LeaveType.fromStringOrNull(e.value as String?) != null)
            e.key: LeaveType.fromStringOrNull(e.value as String?)!,
      };
      if (entries.isNotEmpty) leave[day] = entries;
    }
    final rawHours = map['shiftHours'] as Map<String, dynamic>? ?? const {};
    final shiftHours = <ScheduleDay, Map<ScheduleShift, ShiftHours>>{};
    for (final day in ScheduleDay.values) {
      final dayMap = rawHours[day.value] as Map<String, dynamic>?;
      if (dayMap == null) continue;
      final entries = <ScheduleShift, ShiftHours>{};
      for (final shift in ScheduleShift.values) {
        final hours = ShiftHours.fromMap(dayMap[shift.value]);
        if (hours != null) entries[shift] = hours;
      }
      if (entries.isNotEmpty) shiftHours[day] = entries;
    }
    return WeeklyScheduleModel(
      id: id ?? map['id'] as String? ?? '',
      branchId: map['branchId'] as String? ?? '',
      weekStart:
          map.date('weekStart') ?? DateTime(1970),
      assignments: assignments,
      dayNotes: dayNotes,
      leave: leave,
      shiftHours: shiftHours,
      // Absent on every legacy doc → null → the week resolves standard hours.
      shiftPlan: ShiftPlan.fromMap(map['shiftPlan']),
      createdBy: map['createdBy'] as String?,
      createdAt: map.date('createdAt'),
      updatedAt: map.date('updatedAt'),
    );
  }

  factory WeeklyScheduleModel.fromEntity(WeeklyScheduleEntity e) =>
      WeeklyScheduleModel(
        id: e.id,
        branchId: e.branchId,
        weekStart: e.weekStart,
        assignments: e.assignments,
        dayNotes: e.dayNotes,
        leave: e.leave,
        shiftHours: e.shiftHours,
        shiftPlan: e.shiftPlan,
        createdBy: e.createdBy,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
      );

  /// An empty schedule for [branchId] in the given [weekStart] week, with every
  /// day/shift seeded to an empty list so the roster grid is stable. The
  /// optional [shiftPlan] is the branch's shift-hours snapshot captured at
  /// creation (Schedule V2 · Pillar 5); null keeps the week on standard hours.
  factory WeeklyScheduleModel.empty({
    required String id,
    required String branchId,
    required DateTime weekStart,
    String? createdBy,
    ShiftPlan? shiftPlan,
  }) =>
      WeeklyScheduleModel(
        id: id,
        branchId: branchId,
        weekStart: weekStart,
        createdBy: createdBy,
        shiftPlan: shiftPlan,
        assignments: {
          for (final day in ScheduleDay.values)
            day: {for (final shift in ScheduleShift.values) shift: <String>[]},
        },
      );

  /// Persisted fields. `createdAt`/`updatedAt` are written by the datasource as
  /// server timestamps, so they're intentionally not included here.
  Map<String, dynamic> toMap() => {
        'id': id,
        'branchId': branchId,
        'weekStart': Timestamp.fromDate(weekStart),
        'assignments': {
          for (final entry in assignments.entries)
            entry.key.value: {
              for (final shiftEntry in entry.value.entries)
                shiftEntry.key.value: shiftEntry.value,
            },
        },
        if (dayNotes.isNotEmpty)
          'dayNotes': {
            for (final entry in dayNotes.entries) entry.key.value: entry.value,
          },
        if (leave.isNotEmpty)
          'leave': {
            for (final entry in leave.entries)
              entry.key.value: {
                for (final person in entry.value.entries)
                  person.key: person.value.value,
              },
          },
        if (shiftHours.isNotEmpty)
          'shiftHours': {
            for (final entry in shiftHours.entries)
              entry.key.value: {
                for (final shiftEntry in entry.value.entries)
                  shiftEntry.key.value: shiftEntry.value.toMap(),
              },
          },
        if (shiftPlan != null) 'shiftPlan': shiftPlan!.toMap(),
        'createdBy': createdBy,
      };

  WeeklyScheduleEntity toEntity() => WeeklyScheduleEntity(
        id: id,
        branchId: branchId,
        weekStart: weekStart,
        assignments: assignments,
        dayNotes: dayNotes,
        leave: leave,
        shiftHours: shiftHours,
        shiftPlan: shiftPlan,
        createdBy: createdBy,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
