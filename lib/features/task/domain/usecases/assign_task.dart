import 'package:opshub/features/task/domain/repositories/task_repository.dart';

/// Sets a task's assignees (Phase 9 — multi-assignee) and optionally a shift; an
/// empty list unassigns.
class AssignTask {
  final TaskRepository _repository;
  const AssignTask(this._repository);

  Future<void> call({
    required String taskId,
    required List<String> employeeIds,
    String? assignedShiftId,
  }) =>
      _repository.assignTask(
        taskId: taskId,
        employeeIds: employeeIds,
        assignedShiftId: assignedShiftId,
      );
}
