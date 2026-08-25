import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/features/auth/domain/repositories/auth_repository.dart';
import 'package:opshub/features/auth/domain/usecases/get_users_by_branch.dart';
import 'package:opshub/features/branch/domain/repositories/branch_repository.dart';
import 'package:opshub/features/notifications/domain/repositories/notification_repository.dart';
import 'package:opshub/features/notifications/domain/usecases/notify_task_event.dart';
import 'package:opshub/features/schedule/domain/repositories/schedule_repository.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/domain/repositories/task_repository.dart';
import 'package:opshub/features/task/domain/usecases/assign_task.dart';
import 'package:opshub/features/task/domain/usecases/create_task.dart';
import 'package:opshub/features/task/domain/usecases/delete_task.dart';
import 'package:opshub/features/task/domain/usecases/update_task.dart';
import 'package:opshub/features/task/domain/usecases/upload_task_attachment.dart';
import 'package:opshub/features/task/domain/work_types/definitions/inventory_count_work_type.dart';
import 'package:opshub/features/task/presentation/cubit/task_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

/// The submission gate now routes through the work type: an inventory count with
/// no counted quantity must not reach `waitingReview`.
void main() {
  late _SpyTaskRepository repo;
  late TaskCubit cubit;

  TaskCubit build() => TaskCubit(
        repository: repo,
        branchRepository: _BranchRepository(),
        scheduleRepository: _ScheduleRepository(),
        createTask: CreateTask(repo),
        updateTask: UpdateTask(repo),
        deleteTask: DeleteTask(repo),
        assignTask: AssignTask(repo),
        uploadTaskAttachment: UploadTaskAttachment(repo),
        getUsersByBranch: GetUsersByBranch(_AuthRepository()),
        notifyTaskEvent: NotifyTaskEvent(_NotificationRepository()),
      );

  setUp(() {
    repo = _SpyTaskRepository();
    cubit = build();
  });

  tearDown(() => cubit.close());

  TaskEntity inventory({int? counted}) => TaskEntity(
        id: 't1',
        title: 'Count stockroom',
        workType: 'inventoryCount',
        status: TaskStatus.started,
        data: {
          InventoryCountWorkType.kArea: 'Stockroom',
          InventoryCountWorkType.kExpectedQty: 20,
          InventoryCountWorkType.kCountedQty: ?counted,
        },
      );

  Future<List<String>> errorsFrom(Future<void> Function() action) async {
    final errors = <String>[];
    final sub = cubit.stream.listen((s) {
      final m = s.maybeWhen(error: (msg) => msg, orElse: () => null);
      if (m != null) errors.add(m);
    });
    await action();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    return errors;
  }

  test('BLOCKS with the type-specific message when the count is missing',
      () async {
    final errors = await errorsFrom(() => cubit.submitForReview(inventory()));
    expect(errors, contains('Enter the counted quantity.'));
    expect(repo.updateCalled, isFalse,
        reason: 'the type gate must stop the write');
  });

  test('LETS a complete count through the gate (no gate error)', () async {
    final errors =
        await errorsFrom(() => cubit.submitForReview(inventory(counted: 20)));
    expect(errors, isNot(contains('Enter the counted quantity.')));
  });
}

class _SpyTaskRepository implements TaskRepository {
  bool updateCalled = false;

  @override
  Future<TaskEntity> updateTask(TaskEntity task) async {
    updateCalled = true;
    return task;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BranchRepository implements BranchRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ScheduleRepository implements ScheduleRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NotificationRepository implements NotificationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
