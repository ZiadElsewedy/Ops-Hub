import 'package:freezed_annotation/freezed_annotation.dart';

part 'statistics_entity.freezed.dart';

/// Operational statistics for a OpsHub dashboard (Phase 6). A single bag
/// of counts populated per role — admin (global), manager (own branch) and
/// employee (own data) each read the fields relevant to their dashboard. Counts
/// are computed from branch-scoped Firestore queries (no analytics engine).
@freezed
class StatisticsEntity with _$StatisticsEntity {
  const factory StatisticsEntity({
    // ── Admin (global) ──
    @Default(0) int totalBranches,
    @Default(0) int totalManagers,
    @Default(0) int totalEmployees,
    /// Deprecated — OpsHub is admin-provisioned (no approval queue). Always 0; kept
    /// only to avoid a codegen churn, slated for removal on the next build_runner.
    @Default(0) int pendingApprovals,
    @Default(0) int branchesWithoutManagers,
    /// Branches with a weekly schedule published for the current week (Phase 7
    /// schedule coverage — read against [totalBranches]).
    @Default(0) int branchesWithSchedule,
    // ── Manager (own branch) ──
    @Default(0) int employeesInBranch,
    /// Employees scheduled today (Phase 7 — from this week's weekly schedule).
    @Default(0) int scheduledToday,
    /// Employees on today's morning / night shift (Phase 7 — weekly schedule).
    @Default(0) int morningShiftEmployees,
    @Default(0) int nightShiftEmployees,
    @Default(0) int dailyTasks,
    @Default(0) int specialTasks,
    // ── Tasks (shared, scope-dependent) ──
    @Default(0) int activeTasks,
    @Default(0) int completedTasks,
    @Default(0) int completedTasksToday,
    @Default(0) int waitingReviews,
    @Default(0) int rejectedTasks,
    @Default(0) int rejectedTasksToday,
    // ── Employee (own data) ──
    @Default(0) int assignedTasks,
    @Default(0) int pendingTasks,
    /// The employee's shift today, from this week's weekly schedule (e.g.
    /// `morning` / `night`), or null when they're off / unscheduled (Phase 7).
    String? currentShiftName,
    /// The employee's next scheduled slot later this week, formatted for display
    /// (e.g. `Tue · Morning`), or null if none (Phase 7).
    String? upcomingShiftName,
  }) = _StatisticsEntity;
}
