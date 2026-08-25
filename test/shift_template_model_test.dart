import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/enums/shift_template_role.dart';
import 'package:opshub/features/schedule/data/models/shift_template_model.dart';
import 'package:opshub/features/schedule/data/models/weekly_schedule_model.dart';
import 'package:opshub/features/schedule/domain/shift_hours.dart';
import 'package:opshub/features/schedule/domain/shift_plan.dart';
import 'package:opshub/features/schedule/domain/shift_template.dart';

/// Schedule V2 · Pillar 5 — persistence: template (de)serialization and the
/// **additive, backward-compatible** week snapshot (a legacy doc with no
/// `shiftPlan` must round-trip to standard hours, unchanged).
void main() {
  group('ShiftTemplateModel', () {
    test('round-trips flat start/end minutes, incl. overnight', () {
      const t = ShiftTemplate(
        id: 'b1__weekendNight',
        branchId: 'b1',
        name: 'Weekend night',
        role: ShiftTemplateRole.weekendNight,
        hours: ShiftHours(960, 1500), // 16:00 → 01:00
      );
      final map = ShiftTemplateModel.fromEntity(t).toMap();
      expect(map['startMinutes'], 960);
      expect(map['endMinutes'], 1500);
      expect(map['role'], 'weekendNight');
      expect(ShiftTemplateModel.fromMap(map, id: t.id).toEntity(), t);
    });

    test('fromMap guards a malformed range → standard morning', () {
      final back = ShiftTemplateModel.fromMap({
        'branchId': 'b1',
        'name': 'Broken',
        'role': 'morning',
        'startMinutes': 1000,
        'endMinutes': 500, // end < start, invalid
      }).toEntity();
      expect(back.hours,
          ShiftHours.standard(ScheduleDay.sunday, ScheduleShift.morning));
    });
  });

  group('WeeklyScheduleModel.shiftPlan', () {
    test('legacy doc without shiftPlan → null, resolves standard', () {
      final model = WeeklyScheduleModel.fromMap({
        'branchId': 'b1',
        'weekStart': Timestamp.fromDate(DateTime(2026, 7, 5)),
      });
      expect(model.shiftPlan, isNull);
      expect(
        model.toEntity().hoursFor(ScheduleDay.thursday, ScheduleShift.night),
        ShiftHours.standard(ScheduleDay.thursday, ScheduleShift.night),
      );
    });

    test('shiftPlan round-trips through the doc map', () {
      final plan = ShiftPlan(
        morning: const ShiftHours(540, 1020),
        weekdayNight: const ShiftHours(900, 1380),
        weekendNight: const ShiftHours(960, 1500),
      );
      final model = WeeklyScheduleModel(
        id: 'x',
        branchId: 'b1',
        weekStart: DateTime(2026, 7, 5),
        shiftPlan: plan,
      );
      final map = model.toMap();
      expect(map.containsKey('shiftPlan'), isTrue);
      expect(WeeklyScheduleModel.fromMap(map, id: 'x').shiftPlan, plan);
    });

    test('toMap omits shiftPlan when null (lean legacy docs)', () {
      final model = WeeklyScheduleModel(
        id: 'x',
        branchId: 'b1',
        weekStart: DateTime(2026, 7, 5),
      );
      expect(model.toMap().containsKey('shiftPlan'), isFalse);
    });
  });
}
