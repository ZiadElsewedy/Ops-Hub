import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/presentation/submission_progress.dart';

part 'task_state.freezed.dart';

@freezed
class TaskState with _$TaskState {
  const factory TaskState.initial() = _Initial;

  /// First load (full-screen spinner).
  const factory TaskState.loading() = _Loading;

  /// Tasks loaded. [busy] marks an in-flight mutation (create/assign/status/…)
  /// while the list stays visible (no flicker). [directory] resolves assignee
  /// uids → users so cards can show real names/avatars (Phase 9); it fills in
  /// asynchronously after the tasks arrive.
  ///
  /// [isSubmitting] + [submissionProgress] drive the **shared** submission
  /// loading overlay — lifting it out of any single widget so the whole Task
  /// Details screen reacts and progress survives rebuilds / disposal.
  const factory TaskState.loaded(
    List<TaskEntity> tasks, {
    @Default(false) bool busy,
    @Default(<String, UserEntity>{}) Map<String, UserEntity> directory,
    @Default(false) bool isSubmitting,
    SubmissionProgress? submissionProgress,
  }) = _Loaded;

  /// Transient — surfaced as a snackbar; the cubit immediately re-emits the
  /// last-known [loaded] list so the UI never loses its data.
  const factory TaskState.error(String message) = _Error;
}
