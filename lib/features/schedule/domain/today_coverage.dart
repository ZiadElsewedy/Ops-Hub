/// Pure branch-level coverage rules for the admin's Today schedule landing.
library;

import 'package:opshub/features/branch/domain/entities/branch_entity.dart';
import 'package:opshub/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:opshub/features/schedule/domain/today_roster.dart';

/// One branch's answer to "is today covered?".
class TodayCoverage {
  const TodayCoverage({
    required this.branch,
    required this.schedule,
    required this.roster,
    this.loadError,
  });

  final BranchEntity branch;
  final WeeklyScheduleEntity? schedule;
  final TodayRoster roster;
  final String? loadError;

  bool get hasSchedule => schedule != null;
  bool get hasUncoveredShift => hasSchedule && roster.shifts.any((s) => s.isEmpty);
  bool get isFullyCovered => hasSchedule && !hasUncoveredShift;
}

/// Orders actual uncovered shifts first, then the remaining branches by name.
/// A week that has not been created is deliberately distinct from an uncovered
/// published schedule, so it remains in alphabetical order with its own state.
List<TodayCoverage> orderTodayCoverage(Iterable<TodayCoverage> coverage) {
  final ordered = coverage.toList()
    ..sort((a, b) {
      final byProblem = (b.hasUncoveredShift ? 1 : 0)
          .compareTo(a.hasUncoveredShift ? 1 : 0);
      if (byProblem != 0) return byProblem;
      return a.branch.name.toLowerCase().compareTo(b.branch.name.toLowerCase());
    });
  return ordered;
}

int fullyCoveredBranches(Iterable<TodayCoverage> coverage) =>
    coverage.where((row) => row.isFullyCovered).length;
