import 'package:opshub/features/task/domain/repositories/task_repository.dart';

/// Deletes a task (manager / admin).
class DeleteTask {
  final TaskRepository _repository;
  const DeleteTask(this._repository);

  Future<void> call(String taskId) => _repository.deleteTask(taskId);
}
