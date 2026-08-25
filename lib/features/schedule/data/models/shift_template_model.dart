import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/enums/shift_template_role.dart';
import 'package:opshub/features/schedule/domain/shift_hours.dart';
import 'package:opshub/features/schedule/domain/shift_template.dart';

/// Firestore (de)serialization for [ShiftTemplate] — collection
/// `shift_templates/{id}`. Hours are stored **flat** as `startMinutes` /
/// `endMinutes` (minutes past midnight; `end > 1440` for an overnight close),
/// mirroring [ShiftHours].
class ShiftTemplateModel {
  const ShiftTemplateModel({
    required this.id,
    required this.branchId,
    required this.name,
    required this.role,
    required this.hours,
  });

  final String id;
  final String branchId;
  final String name;
  final ShiftTemplateRole role;
  final ShiftHours hours;

  factory ShiftTemplateModel.fromMap(Map<String, dynamic> map, {String? id}) {
    final start = (map['startMinutes'] as num?)?.toInt();
    final end = (map['endMinutes'] as num?)?.toInt();
    // Guarded through ShiftHours.fromMap so a malformed doc can never invent an
    // impossible range; falls back to the standard morning window.
    final hours = ShiftHours.fromMap({'start': start, 'end': end}) ??
        ShiftHours.standard(ScheduleDay.sunday, ScheduleShift.morning);
    return ShiftTemplateModel(
      id: id ?? map['id'] as String? ?? '',
      branchId: map['branchId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      role: ShiftTemplateRole.fromString(map['role'] as String?),
      hours: hours,
    );
  }

  factory ShiftTemplateModel.fromEntity(ShiftTemplate t) => ShiftTemplateModel(
        id: t.id,
        branchId: t.branchId,
        name: t.name,
        role: t.role,
        hours: t.hours,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'branchId': branchId,
        'name': name,
        'role': role.value,
        'startMinutes': hours.startMinutes,
        'endMinutes': hours.endMinutes,
      };

  ShiftTemplate toEntity() => ShiftTemplate(
        id: id,
        branchId: branchId,
        name: name,
        role: role,
        hours: hours,
      );
}
