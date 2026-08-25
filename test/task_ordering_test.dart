import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/domain/task_ordering.dart';

TaskEntity _task(String id, DateTime? createdAt) =>
    TaskEntity(id: id, title: id, createdAt: createdAt);

void main() {
  group('sortTasksNewestFirst', () {
    test('orders by createdAt descending (newest first)', () {
      final out = sortTasksNewestFirst([
        _task('old', DateTime(2026, 6, 1)),
        _task('new', DateTime(2026, 6, 20)),
        _task('mid', DateTime(2026, 6, 10)),
      ]);
      expect(out.map((t) => t.id).toList(), ['new', 'mid', 'old']);
    });

    test('a pending (null createdAt) task sorts to the very top', () {
      final out = sortTasksNewestFirst([
        _task('old', DateTime(2026, 6, 1)),
        _task('pending', null),
        _task('new', DateTime(2026, 6, 20)),
      ]);
      expect(out.first.id, 'pending');
      expect(out.map((t) => t.id).toList(), ['pending', 'new', 'old']);
    });

    test('does not mutate the input list', () {
      final input = [
        _task('a', DateTime(2026, 6, 1)),
        _task('b', DateTime(2026, 6, 2)),
      ];
      sortTasksNewestFirst(input);
      expect(input.map((t) => t.id).toList(), ['a', 'b']);
    });
  });
}
