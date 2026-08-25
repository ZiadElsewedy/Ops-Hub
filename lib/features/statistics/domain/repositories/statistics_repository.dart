import 'package:opshub/features/statistics/domain/entities/statistics_entity.dart';

/// Contract for operational statistics (Phase 6). Each method is scoped to a
/// role: admin = global, manager = own branch, employee = own data.
abstract class StatisticsRepository {
  Future<StatisticsEntity> adminStats();
  Future<StatisticsEntity> managerStats(String branchId);

  /// Employee stats. [branchId] (the employee's branch) is needed to read their
  /// current/upcoming shift from the weekly schedule (Phase 7).
  Future<StatisticsEntity> employeeStats(String uid, String? branchId);
}
