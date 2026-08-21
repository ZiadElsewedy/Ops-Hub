import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opshub/core/errors/failures.dart';
import 'package:opshub/features/communications/domain/entities/broadcast_schedule_entity.dart';
import 'package:opshub/features/communications/domain/repositories/broadcast_schedule_repository.dart';
import 'broadcast_schedule_state.dart';

/// Scheduled / recurring broadcasts (Communications Center — Phase 2 Commit 4).
/// Repo-direct (mirrors `BranchCubit`). The `runBroadcastSchedules` Cloud
/// Function does the actual firing + nextRunAt advancement; this cubit is the
/// management surface (create / pause / resume / cancel / edit future runs).
class BroadcastScheduleCubit extends Cubit<BroadcastScheduleState> {
  final BroadcastScheduleRepository _repository;

  BroadcastScheduleCubit(this._repository)
      : super(const BroadcastScheduleState.initial());

  String _uid = '';
  bool _isAdmin = false;

  List<BroadcastScheduleEntity> get _schedules =>
      state.maybeWhen(loaded: (s, _) => s, orElse: () => const []);

  bool get _busy => state.maybeWhen(
        loaded: (_, busy) => busy,
        loading: () => true,
        orElse: () => false,
      );

  Future<void> load({required String uid, required bool isAdmin}) async {
    _uid = uid;
    _isAdmin = isAdmin;
    emit(const BroadcastScheduleState.loading());
    try {
      emit(BroadcastScheduleState.loaded(
          await _repository.getSchedules(uid: uid, isAdmin: isAdmin)));
    } on Failure catch (e) {
      emit(BroadcastScheduleState.error(e.message));
    } catch (_) {
      emit(const BroadcastScheduleState.error('Failed to load schedules.'));
    }
  }

  /// Creates a schedule whose first run is its [BroadcastScheduleEntity.startDate].
  /// [targetUserIds] carries a custom schedule's recipients.
  Future<void> create(
    BroadcastScheduleEntity schedule, {
    List<String> targetUserIds = const [],
  }) =>
      _mutate(() => _repository.create(
            schedule.copyWith(nextRunAt: schedule.startDate),
            targetUserIds: targetUserIds,
          ));

  /// Pause / resume (`enabled` flag).
  Future<void> setEnabled(BroadcastScheduleEntity s, bool enabled) =>
      _mutate(() => _repository.setEnabled(s.id, enabled));

  /// Cancel (hard delete — a schedule has no history to preserve; the fired
  /// broadcasts already live in `broadcasts`).
  Future<void> cancel(String id) => _mutate(() => _repository.delete(id));

  /// Edit future runs (recurrence / interval / end date).
  Future<void> updateSchedule(BroadcastScheduleEntity schedule) =>
      _mutate(() => _repository.update(schedule));

  Future<void> _mutate(Future<void> Function() action) async {
    if (_busy) return;
    final prev = _schedules;
    emit(BroadcastScheduleState.loaded(prev, busy: true));
    try {
      await action();
      emit(BroadcastScheduleState.loaded(
          await _repository.getSchedules(uid: _uid, isAdmin: _isAdmin)));
    } on Failure catch (e) {
      emit(BroadcastScheduleState.error(e.message));
      emit(BroadcastScheduleState.loaded(prev));
    } catch (_) {
      emit(const BroadcastScheduleState.error(
          'Something went wrong. Please try again.'));
      emit(BroadcastScheduleState.loaded(prev));
    }
  }
}
