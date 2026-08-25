import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/task/data/models/task_model.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';

/// Verifies the new `tasks.shift` field round-trips through serialization and is
/// back-compatible — a missing or unknown value reads as null ("any"), never
/// coerced to morning.
void main() {
  group('TaskModel.shift serialization', () {
    test('writes the lower-case shift name (or null for "any")', () {
      expect(
          const TaskModel(id: '1', title: 't', shift: ScheduleShift.morning)
              .toMap()['shift'],
          'morning');
      expect(
          const TaskModel(id: '1', title: 't', shift: ScheduleShift.night)
              .toMap()['shift'],
          'night');
      expect(const TaskModel(id: '1', title: 't').toMap()['shift'], isNull);
    });

    test('reads morning / night and preserves absence', () {
      expect(TaskModel.fromMap(const {'shift': 'morning'}).shift,
          ScheduleShift.morning);
      expect(TaskModel.fromMap(const {'shift': 'night'}).shift,
          ScheduleShift.night);
      expect(TaskModel.fromMap(const {}).shift, isNull);
    });

    test('an unknown value degrades to null, not morning', () {
      expect(TaskModel.fromMap(const {'shift': 'graveyard'}).shift, isNull);
    });

    test('round-trips through the entity boundary', () {
      const e = TaskEntity(id: '1', title: 't', shift: ScheduleShift.night);
      expect(TaskModel.fromEntity(e).shift, ScheduleShift.night);
      expect(TaskModel.fromEntity(e).toEntity().shift, ScheduleShift.night);
    });
  });

  // Recurrence lineage (Automated Task Engine) — the deterministic-successor
  // fields written by `_spawnNextRecurrence`. Additive + nullable: absent on
  // every pre-existing / non-recurring task.
  group('TaskModel recurrence lineage serialization', () {
    test('writes recurrenceRootId + occurrenceKey', () {
      final map = const TaskModel(
        id: 'rec_t1',
        title: 't',
        recurrenceRootId: 't1',
        occurrenceKey: '2026-01-11',
      ).toMap();
      expect(map['recurrenceRootId'], 't1');
      expect(map['occurrenceKey'], '2026-01-11');
    });

    test('absent on a plain task (back-compat)', () {
      expect(TaskModel.fromMap(const {}).recurrenceRootId, isNull);
      expect(TaskModel.fromMap(const {}).occurrenceKey, isNull);
      final map = const TaskModel(id: '1', title: 't').toMap();
      expect(map['recurrenceRootId'], isNull);
      expect(map['occurrenceKey'], isNull);
    });

    test('round-trips through the entity boundary', () {
      const e = TaskEntity(
        id: 'rec_t1',
        title: 't',
        recurrenceRootId: 't1',
        occurrenceKey: '2026-01-11',
      );
      final back = TaskModel.fromEntity(e).toEntity();
      expect(back.recurrenceRootId, 't1');
      expect(back.occurrenceKey, '2026-01-11');
    });
  });

  // The automation-execution correlation id links a generated task back to its
  // run / notifications / audit (§Correlation ID). Additive + nullable, so it is
  // absent on every non-automation task.
  group('TaskModel correlationId serialization', () {
    test('writes and reads the correlation id', () {
      final map = const TaskModel(
        id: 'rt_tpl_2026-07-18',
        title: 't',
        correlationId: 'AUT-20260718-A3F9C1',
      ).toMap();
      expect(map['correlationId'], 'AUT-20260718-A3F9C1');
      expect(
        TaskModel.fromMap(map).correlationId,
        'AUT-20260718-A3F9C1',
      );
    });

    test('absent on a plain task (back-compat)', () {
      expect(TaskModel.fromMap(const {}).correlationId, isNull);
      expect(const TaskModel(id: '1', title: 't').toMap()['correlationId'],
          isNull);
    });

    test('round-trips through the entity boundary', () {
      const e = TaskEntity(
        id: 'rt_tpl_2026-07-18',
        title: 't',
        correlationId: 'AUT-20260718-A3F9C1',
      );
      final back = TaskModel.fromEntity(e).toEntity();
      expect(back.correlationId, 'AUT-20260718-A3F9C1');
    });
  });
}
