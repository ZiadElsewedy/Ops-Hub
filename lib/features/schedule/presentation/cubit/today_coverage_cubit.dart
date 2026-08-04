import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/utils/concurrent.dart';
import 'package:drop/features/auth/domain/usecases/get_users_by_branch.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/schedule/domain/schedule_week.dart';
import 'package:drop/features/schedule/domain/today_coverage.dart';
import 'package:drop/features/schedule/domain/today_roster.dart';
import 'package:drop/features/schedule/domain/repositories/schedule_repository.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'today_coverage_state.dart';

/// Owns the admin Today read path. It intentionally never reads or writes the
/// app-wide ScheduleCubit, whose selected week/branch belongs to the editor.
class TodayCoverageCubit extends Cubit<TodayCoverageState> {
  /// Positional, like `ScheduleCubit` — a private field can't be an
  /// initializing formal on a *named* parameter, so named ctor args here would
  /// mean assigning in the initializer list and tripping
  /// `prefer_initializing_formals`.
  TodayCoverageCubit(this._scheduleRepository, this._getUsersByBranch)
    : super(const TodayCoverageInitial());

  final ScheduleRepository _scheduleRepository;
  final GetUsersByBranch _getUsersByBranch;

  Future<void> load(List<BranchEntity> branches) async {
    if (branches.isEmpty) {
      emit(const TodayCoverageLoaded([]));
      return;
    }
    emit(const TodayCoverageLoading());
    final weekStart = ScheduleWeek.currentWeekStart();
    final rows = await mapPooled<TodayCoverage>(
      3,
      [
        for (final branch in branches)
          () async {
            try {
              final values = await Future.wait<Object?>([
                _scheduleRepository.getScheduleCacheFirst(branch.id, weekStart),
                _getUsersByBranch(branch.id),
              ]);
              final schedule = values[0] as WeeklyScheduleEntity?;
              final members = values[1] as List<UserEntity>;
              return TodayCoverage(
                branch: branch,
                schedule: schedule,
                roster: todayRoster(schedule: schedule, members: members),
              );
            } catch (_) {
              return TodayCoverage(
                branch: branch,
                schedule: null,
                roster: todayRoster(schedule: null, members: const []),
                loadError: 'Could not load today\'s coverage.',
              );
            }
          },
      ],
    );
    emit(TodayCoverageLoaded(orderTodayCoverage(rows)));
  }
}
