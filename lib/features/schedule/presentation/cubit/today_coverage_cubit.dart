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

  /// Scope + freshness of what is currently on screen. The key folds in the
  /// branch set **and** the day, so a branch appearing/disappearing or the date
  /// rolling over always refetches; `null` after an error, so a retry never
  /// reuses a failed load.
  String? _loadedKey;
  DateTime? _loadedAt;

  /// How long a computed Today board stays reusable without refetching.
  ///
  /// This board is the most expensive read in the app: one roster query **per
  /// branch**, none of them cached, fired every time the admin opened Schedule.
  /// Re-entering the screen inside this window now reuses what is already on
  /// screen. Every path that can actually change it still bypasses the window —
  /// the Refresh button, and returning to the Today tab after using the editor.
  static const Duration _freshFor = Duration(minutes: 5);

  /// Loads today's coverage for [branches].
  ///
  /// A re-entry with the same branch set on the same day, inside [_freshFor],
  /// is a **no-op** — no reads, no skeleton. Pass [force] for the Refresh button
  /// and for the return to the Today tab (where the admin has just edited the
  /// roster and must see the new one).
  Future<void> load(List<BranchEntity> branches, {bool force = false}) async {
    if (branches.isEmpty) {
      _loadedKey = null;
      _loadedAt = null;
      emit(const TodayCoverageLoaded([]));
      return;
    }
    final weekStart = ScheduleWeek.currentWeekStart();
    final key = _scopeKey(branches, weekStart);
    final fresh =
        _loadedAt != null && DateTime.now().difference(_loadedAt!) < _freshFor;
    if (!force && _loadedKey == key && fresh) return;

    // Only a genuinely new scope shows the skeleton. A forced refresh of the
    // board already on screen keeps it visible while it re-derives, so Refresh
    // never blanks the list it is refreshing.
    if (_loadedKey != key || state is! TodayCoverageLoaded) {
      emit(const TodayCoverageLoading());
    }
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
    _loadedKey = key;
    _loadedAt = DateTime.now();
    emit(TodayCoverageLoaded(orderTodayCoverage(rows)));
  }

  /// Identity of a computed board: which branches, for which day. Sorted so the
  /// same set in a different order is recognised as the same scope.
  String _scopeKey(List<BranchEntity> branches, DateTime weekStart) {
    final ids = [for (final b in branches) b.id]..sort();
    final now = DateTime.now();
    return '${ids.join(',')}|${weekStart.toIso8601String()}'
        '|${now.year}-${now.month}-${now.day}';
  }
}
