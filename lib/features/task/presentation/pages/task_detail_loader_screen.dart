import 'package:flutter/material.dart';
import 'package:opshub/core/di/injection.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/adaptive_scaffold.dart';
import 'package:opshub/core/widgets/app_empty_state.dart';
import 'package:opshub/core/widgets/list_skeleton.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/presentation/pages/task_details_screen.dart';

/// Loads a single task by id and shows [TaskDetailsScreen]. The deep-link target
/// for the `/task/:taskId` route, so a task notification opens the **exact task**
/// (not the task list). [TaskDetailsScreen] then keeps itself live from the
/// app-wide `TaskCubit` stream; this loader only resolves the initial snapshot.
class TaskDetailLoaderScreen extends StatefulWidget {
  const TaskDetailLoaderScreen({super.key, required this.taskId});

  final String taskId;

  @override
  State<TaskDetailLoaderScreen> createState() => _TaskDetailLoaderScreenState();
}

class _TaskDetailLoaderScreenState extends State<TaskDetailLoaderScreen> {
  late Future<TaskEntity?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<TaskEntity?> _load() =>
      AppDependencies.taskRepository.getTask(widget.taskId);

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TaskEntity?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.darkBg,
            body: ListSkeleton(),
          );
        }
        final task = snap.data;
        if (snap.hasError || task == null) {
          return AdaptiveScaffold(
            title: 'Task',
            body: AppEmptyState(
              icon: Icons.inbox_outlined,
              title: 'Task unavailable',
              message: snap.hasError
                  ? 'Could not load this task. Check your connection and try again.'
                  : 'This task no longer exists, or you no longer have access to it.',
              action: snap.hasError
                  ? TextButton(
                      onPressed: _retry,
                      child: Text('Retry',
                          style: AppTypography.label
                              .copyWith(color: AppColors.primary)),
                    )
                  : null,
            ),
          );
        }
        return TaskDetailsScreen(task: task);
      },
    );
  }
}
