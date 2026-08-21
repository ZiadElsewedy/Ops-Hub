import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/leave_type.dart';
import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/schedule/data/models/weekly_schedule_model.dart';

void main() {
  group('WeeklyScheduleModel — day notes + leave (Schedule 5.0)', () {
    test('round-trips dayNotes and leave through toMap/fromMap', () {
      final model = WeeklyScheduleModel.fromMap({
        'branchId': 'b1',
        'assignments': {
          'sunday': {
            'morning': ['u1'],
          },
        },
        'dayNotes': {'monday': 'Inventory'},
        'leave': {
          'sunday': {'u1': 'sick', 'u2': 'pending'},
        },
      }, id: 'b1_2026-06-14');

      expect(model.dayNotes, {ScheduleDay.monday: 'Inventory'});
      expect(model.leave, {
        ScheduleDay.sunday: {
          'u1': LeaveType.sick,
          'u2': LeaveType.pending,
        },
      });

      final map = model.toMap();
      expect(map['dayNotes'], {'monday': 'Inventory'});
      expect(map['leave'], {
        'sunday': {'u1': 'sick', 'u2': 'pending'},
      });

      final entity = model.toEntity();
      expect(entity.noteFor(ScheduleDay.monday), 'Inventory');
      expect(entity.leaveTypeOf('u1', ScheduleDay.sunday), LeaveType.sick);
      expect(entity.leaveTypeOf('u1', ScheduleDay.monday), isNull);
    });

    test('drops unknown leave values and blank notes instead of inventing '
        'entries', () {
      final model = WeeklyScheduleModel.fromMap({
        'branchId': 'b1',
        'dayNotes': {'monday': '   ', 'tuesday': 42},
        'leave': {
          'sunday': {'u1': 'sabbatical', 'u2': 'annual'},
        },
      });

      expect(model.dayNotes, isEmpty);
      expect(model.leave, {
        ScheduleDay.sunday: {'u2': LeaveType.annual},
      });
    });

    test('legacy docs without the new fields parse to empty maps and omit '
        'them when written back', () {
      final model = WeeklyScheduleModel.fromMap({'branchId': 'b1'});
      expect(model.dayNotes, isEmpty);
      expect(model.leave, isEmpty);

      final map = model.toMap();
      expect(map.containsKey('dayNotes'), isFalse);
      expect(map.containsKey('leave'), isFalse);
    });

    test('empty seeded schedule still stabilizes every day/shift list', () {
      final model = WeeklyScheduleModel.empty(
        id: 'b1_2026-06-14',
        branchId: 'b1',
        weekStart: DateTime(2026, 6, 14),
      );
      for (final day in ScheduleDay.values) {
        for (final shift in ScheduleShift.values) {
          expect(model.assignments[day]![shift], isEmpty);
        }
      }
    });
  });
}
