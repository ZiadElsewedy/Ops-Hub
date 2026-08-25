import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opshub/core/errors/failures.dart';
import 'package:opshub/core/utils/app_logger.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/statistics/domain/repositories/statistics_repository.dart';
import 'statistics_state.dart';

/// Loads the role-scoped operational statistics for the dashboards (Phase 6).
/// Admin = global · manager = own branch · employee = own data.
class StatisticsCubit extends Cubit<StatisticsState> {
  final StatisticsRepository _repository;

  StatisticsCubit(this._repository) : super(const StatisticsState.initial());

  /// Dashboard stats are an expensive aggregate (admin scans several
  /// collections). They're re-requested on every dashboard open, so we treat a
  /// recent result as still valid: a revisit within [_freshFor] for the same
  /// user is a no-op. Pull-to-refresh passes [forceRefresh] to override it.
  static const _freshFor = Duration(seconds: 90);

  /// Identifies the scope a loaded result belongs to (role + user + branch);
  /// set with [_loadedAt] only on a successful load.
  String? _loadedKey;
  DateTime? _loadedAt;

  static String _keyFor(UserEntity u) =>
      '${u.role.value}:${u.uid}:${u.branchId ?? ''}';

  Future<void> load(UserEntity user, {bool forceRefresh = false}) async {
    final key = _keyFor(user);
    final hasData = state.maybeWhen(loaded: (_) => true, orElse: () => false);
    final isFresh = _loadedKey == key &&
        _loadedAt != null &&
        DateTime.now().difference(_loadedAt!) < _freshFor;
    // Valid, recent data already in memory — skip the expensive refetch.
    if (!forceRefresh && hasData && isFresh) return;

    // Only show the skeleton when we have nothing for this user yet; otherwise
    // keep the current numbers visible and refresh them in place.
    if (!hasData || _loadedKey != key) {
      emit(const StatisticsState.loading());
    }
    try {
      final stats = await AppLog.time(
          'statistics',
          '${user.role.value}Stats',
          () => user.role.isAdmin
              ? _repository.adminStats()
              : user.role.isManager
                  ? _repository.managerStats(user.branchId ?? '')
                  : _repository.employeeStats(user.uid, user.branchId));
      _loadedKey = key;
      _loadedAt = DateTime.now();
      emit(StatisticsState.loaded(stats));
    } on Failure catch (e) {
      emit(StatisticsState.error(e.message));
    } catch (_) {
      emit(const StatisticsState.error('Failed to load statistics.'));
    }
  }
}
