import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/features/task/data/models/task_model.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';

/// Task Scheduling V2 — `startsAt` persists round-trip and old docs (no
/// `startsAt`) degrade cleanly to null (additive, no migration).
void main() {
  test('startsAt survives entity → map → entity', () {
    final start = DateTime(2026, 7, 8, 8, 30);
    final due = DateTime(2026, 7, 8, 16, 30);
    final entity = TaskEntity(
      id: '1',
      title: 'Open the shop',
      startsAt: start,
      deadline: due,
    );

    final map = TaskModel.fromEntity(entity).toMap();
    expect(map['startsAt'], isNotNull);

    final back = TaskModel.fromMap(map).toEntity();
    expect(back.startsAt, start);
    expect(back.dueAt, due); // dueAt aliases deadline
    expect(back.hasSchedule, isTrue);
  });

  test('a legacy doc without startsAt reads as null', () {
    final back = TaskModel.fromMap({'id': '1', 'title': 't'}).toEntity();
    expect(back.startsAt, isNull);
    expect(back.hasSchedule, isFalse);
  });

  test(
    'server-owned missedAt round-trips without changing its terminal status',
    () {
      final missedAt = DateTime.utc(2026, 7, 8, 16, 31);
      final entity = TaskEntity(
        id: 'missed',
        title: 'Open the shop',
        status: TaskStatus.missed,
        missedAt: missedAt,
      );

      final map = TaskModel.fromEntity(entity).toMap();
      expect(map['missedAt'], isNotNull);

      final back = TaskModel.fromMap(map).toEntity();
      expect(back.status, TaskStatus.missed);
      expect(back.missedAt!.isAtSameMomentAs(missedAt), isTrue);
    },
  );
}
