import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/utils/app_logger.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/domain/usecases/get_users_by_branch.dart';
import 'package:drop/features/operations/domain/branch_workload.dart';
import 'package:drop/features/operations/domain/shift_filter.dart';
import 'package:drop/features/operations/presentation/cubit/branch_operations_state.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:drop/features/schedule/domain/repositories/schedule_repository.dart';
import 'package:drop/features/schedule/domain/schedule_week.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/domain/repositories/task_repository.dart';

/// Drives the Branch Operations cockpit (admin: any branch · manager: own).
/// **Read/derive only** — it composes three sources for one branch:
///   • `TaskRepository.watchTasksByBranch` (the live task stream),
///   • `GetUsersByBranch` (branch members — one-shot),
///   • `ScheduleRepository.getSchedule` (this week's roster — one-shot),
/// and derives the cockpit via the pure [computeBranchWorkload]. **Writes**
/// (create / assign / review) stay in `TaskCubit`; because both subscribe to the
/// same branch task stream, a write propagates here live with no manual refresh.
///
/// Repo-direct, matching the branch/admin/schedule cubit convention (it reuses
/// the auth `GetUsersByBranch` use case for the member list, like `ScheduleCubit`).
class BranchOperationsCubit extends Cubit<BranchOperationsState> {
  final TaskRepository _taskRepository;
  final ScheduleRepository _scheduleRepository;
  final GetUsersByBranch _getUsersByBranch;

  BranchOperationsCubit({
    required this._taskRepository,
    required this._scheduleRepository,
    required this._getUsersByBranch,
  }) : super(const BranchOperationsState.initial());

  StreamSubscription<List<TaskEntity>>? _sub;

  // Last-known raw inputs, so a filter change re-derives without any I/O.
  String _branchId = '';
  String? _branchName;
  ShiftFilter _filter = ShiftFilter.all;
  List<UserEntity> _employees = const [];
  Map<String, UserEntity> _directory = const {};
  WeeklyScheduleEntity? _schedule;
  List<TaskEntity> _tasks = const [];
  bool _hasTasks = false;

  /// Loads (or switches to) the cockpit for [branchId]. [branchName] is an
  /// optional display label the caller already knows (the admin branch list);
  /// the manager can omit it.
  Future<void> load(String branchId, {String? branchName}) async {
    if (branchId.isEmpty) {
      emit(const BranchOperationsState.error(
          'This account has no branch assigned yet.'));
      return;
    }
    _branchId = branchId;
    _branchName = branchName;
    _filter = ShiftFilter.all;
    _hasTasks = false;
    emit(const BranchOperationsState.loading());
    await _sub?.cancel();

    try {
      final users = await _getUsersByBranch(branchId);
      _directory = {for (final u in users) u.uid: u};
      _employees =
          users.where((u) => u.role.isEmployee && u.isActive).toList();
      _schedule = await _scheduleRepository.getSchedule(
          branchId, ScheduleWeek.currentWeekStart());
    } catch (e, st) {
      AppLog.error('operations', 'context load failed', e, st);
      emit(BranchOperationsState.error(_message(e)));
      return;
    }

    _sub = _taskRepository.watchTasksByBranch(branchId).listen(
      (tasks) {
        _tasks = tasks;
        _hasTasks = true;
        _emitLoaded();
      },
      onError: (Object e, StackTrace st) {
        AppLog.error('operations', 'task stream error', e, st);
        // Only surface if we never got a first snapshot; otherwise keep the
        // last good cockpit visible (mirrors TaskCubit).
        if (!_hasTasks) emit(BranchOperationsState.error(_message(e)));
      },
    );
  }

  /// Flip the shift lens — a pure re-derive over the cached inputs (no refetch).
  void setFilter(ShiftFilter filter) {
    if (_filter == filter) return;
    _filter = filter;
    if (_hasTasks) _emitLoaded();
  }

  /// Re-pull the branch context + re-subscribe (pull-to-refresh).
  Future<void> refresh() async {
    if (_branchId.isNotEmpty) {
      await load(_branchId, branchName: _branchName);
    }
  }

  void _emitLoaded() {
    emit(BranchOperationsState.loaded(
      branchId: _branchId,
      branchName: _branchName,
      directory: _directory,
      filter: _filter,
      workload: computeBranchWorkload(
        employees: _employees,
        tasks: _tasks,
        schedule: _schedule,
        filter: _filter,
      ),
    ));
  }

  String _message(Object e) => e is Failure
      ? e.message
      : 'Could not load branch operations. Pull to retry.';

  /// Drops the live branch task stream and every cached input, returning to
  /// [BranchOperationsState.initial]. This cubit is an app-wide singleton (it
  /// outlives the session), so on sign-out / single-active-session eviction its
  /// `watchTasksByBranch` listener would otherwise keep running against a
  /// signed-out user — permission-denied noise now, the previous user's branch
  /// still on screen for the next one. Wired into
  /// `AppDependencies.clearUserScopedState()`.
  void reset() {
    _sub?.cancel();
    _sub = null;
    _branchId = '';
    _branchName = null;
    _filter = ShiftFilter.all;
    _employees = const [];
    _directory = const {};
    _schedule = null;
    _tasks = const [];
    _hasTasks = false;
    if (!isClosed) emit(const BranchOperationsState.initial());
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
