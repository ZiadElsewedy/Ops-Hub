import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/schedule/domain/entities/weekly_schedule_entity.dart';

part 'schedule_state.freezed.dart';

@freezed
class ScheduleState with _$ScheduleState {
  const factory ScheduleState.initial() = _Initial;

  /// First load of a (branch, week) view — full-screen spinner.
  const factory ScheduleState.loading() = _Loading;

  /// A (branch, week) view is loaded. [schedule] is null when no schedule has
  /// been created for the week yet. [members] are the branch's users (used for
  /// uid→name display, the assignee picker, and resolving the manager). [busy]
  /// marks an in-flight mutation while the view stays visible.
  const factory ScheduleState.loaded({
    required String branchId,
    required DateTime weekStart,
    required WeeklyScheduleEntity? schedule,
    @Default(<UserEntity>[]) List<UserEntity> members,
    @Default(false) bool busy,
  }) = _Loaded;

  /// Transient — surfaced as a snackbar; the cubit immediately re-emits the
  /// last-known [loaded] view so the UI never loses its data.
  const factory ScheduleState.error(String message) = _Error;
}
