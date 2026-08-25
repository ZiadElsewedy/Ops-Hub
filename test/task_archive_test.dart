import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/features/task/data/datasources/task_remote_datasource.dart';
import 'package:opshub/features/task/data/models/task_model.dart';
import 'package:opshub/features/task/data/repositories/task_repository_impl.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';

/// Task retention (Home Dashboard redesign, P3): the server-managed `archivedAt`
/// field round-trips through serialization, and — critically — an archived task
/// is filtered out of every active list/stream by the repository while staying a
/// full record (so stats/deep-links still resolve it).
void main() {
  final archivedAt = DateTime.utc(2026, 6, 1, 9);

  group('TaskModel.archivedAt serialization', () {
    test('round-trips through fromMap → toMap', () {
      final map = TaskModel(id: '1', title: 't', archivedAt: archivedAt).toMap();
      expect(map.containsKey('archivedAt'), isTrue);
      // Timestamp.toDate() returns a local DateTime — compare the instant.
      expect(TaskModel.fromMap(map, id: '1').archivedAt!.isAtSameMomentAs(archivedAt),
          isTrue);
    });

    test('a live task writes null (so an admin reopen can clear it)', () {
      expect(const TaskModel(id: '1', title: 't').toMap()['archivedAt'], isNull);
    });

    test('reads a missing field as null (back-compat)', () {
      expect(TaskModel.fromMap(const {}).archivedAt, isNull);
    });

    test('round-trips through the entity boundary', () {
      final e = TaskEntity(id: '1', title: 't', archivedAt: archivedAt);
      expect(TaskModel.fromEntity(e).archivedAt, archivedAt);
      expect(TaskModel.fromEntity(e).toEntity().archivedAt, archivedAt);
      expect(e.isArchived, isTrue);
      expect(const TaskEntity(id: '2', title: 't').isArchived, isFalse);
    });
  });

  group('TaskRepositoryImpl drops archived from active views', () {
    final live = TaskModel(
      id: 'live',
      title: 'Live',
      status: TaskStatus.pending,
      createdAt: DateTime.utc(2026, 6, 30),
    );
    final archived = TaskModel(
      id: 'archived',
      title: 'Archived',
      status: TaskStatus.approved,
      approvedAt: DateTime.utc(2026, 5, 1),
      createdAt: DateTime.utc(2026, 5, 1),
      archivedAt: archivedAt,
    );

    test('getAllTasks() excludes archived, keeps live', () async {
      final repo = TaskRepositoryImpl(_FakeTaskDs([live, archived]));
      final ids = (await repo.getAllTasks()).map((t) => t.id).toList();
      expect(ids, ['live']);
    });

    test('watchAllTasks() excludes archived, keeps live', () async {
      final repo = TaskRepositoryImpl(_FakeTaskDs([live, archived]));
      final ids = (await repo.watchAllTasks().first).map((t) => t.id).toList();
      expect(ids, ['live']);
    });
  });
}

/// Minimal fake — only the two paths the test drives are implemented; everything
/// else throws via [noSuchMethod] so an accidental call surfaces loudly.
class _FakeTaskDs implements TaskRemoteDataSource {
  _FakeTaskDs(this.models);
  final List<TaskModel> models;

  @override
  Future<List<TaskModel>> getAllTasks() async => models;

  @override
  Stream<List<TaskModel>> watchAllTasks() => Stream.value(models);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
