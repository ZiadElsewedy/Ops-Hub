import 'package:opshub/features/statistics/domain/entities/statistics_entity.dart';

/// Data-layer holder for computed statistics. Built by the datasource from
/// Firestore aggregation; mapped to [StatisticsEntity] by the repository.
class StatisticsModel {
  final int totalBranches;
  final int totalManagers;
  final int totalEmployees;
  final int pendingApprovals;
  final int branchesWithoutManagers;
  final int branchesWithSchedule;
  final int employeesInBranch;
  final int scheduledToday;
  final int morningShiftEmployees;
  final int nightShiftEmployees;
  final int dailyTasks;
  final int specialTasks;
  final int activeTasks;
  final int completedTasks;
  final int completedTasksToday;
  final int waitingReviews;
  final int rejectedTasks;
  final int rejectedTasksToday;
  final int assignedTasks;
  final int pendingTasks;
  final String? currentShiftName;
  final String? upcomingShiftName;

  const StatisticsModel({
    this.totalBranches = 0,
    this.totalManagers = 0,
    this.totalEmployees = 0,
    this.pendingApprovals = 0,
    this.branchesWithoutManagers = 0,
    this.branchesWithSchedule = 0,
    this.employeesInBranch = 0,
    this.scheduledToday = 0,
    this.morningShiftEmployees = 0,
    this.nightShiftEmployees = 0,
    this.dailyTasks = 0,
    this.specialTasks = 0,
    this.activeTasks = 0,
    this.completedTasks = 0,
    this.completedTasksToday = 0,
    this.waitingReviews = 0,
    this.rejectedTasks = 0,
    this.rejectedTasksToday = 0,
    this.assignedTasks = 0,
    this.pendingTasks = 0,
    this.currentShiftName,
    this.upcomingShiftName,
  });

  StatisticsEntity toEntity() => StatisticsEntity(
        totalBranches: totalBranches,
        totalManagers: totalManagers,
        totalEmployees: totalEmployees,
        pendingApprovals: pendingApprovals,
        branchesWithoutManagers: branchesWithoutManagers,
        branchesWithSchedule: branchesWithSchedule,
        employeesInBranch: employeesInBranch,
        scheduledToday: scheduledToday,
        morningShiftEmployees: morningShiftEmployees,
        nightShiftEmployees: nightShiftEmployees,
        dailyTasks: dailyTasks,
        specialTasks: specialTasks,
        activeTasks: activeTasks,
        completedTasks: completedTasks,
        completedTasksToday: completedTasksToday,
        waitingReviews: waitingReviews,
        rejectedTasks: rejectedTasks,
        rejectedTasksToday: rejectedTasksToday,
        assignedTasks: assignedTasks,
        pendingTasks: pendingTasks,
        currentShiftName: currentShiftName,
        upcomingShiftName: upcomingShiftName,
      );
}
