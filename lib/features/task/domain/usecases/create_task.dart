import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/domain/repositories/task_repository.dart';

/// Creates a task (manager / admin) and returns it with its generated id.
class CreateTask {
  final TaskRepository _repository;
  const CreateTask(this._repository);

  Future<TaskEntity> call(TaskEntity task) => _repository.createTask(task);
}
