import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';

/// One employee's at-a-glance workload on the Branch Operations cockpit — the
/// data behind a single employee card. Derived purely from the branch task
/// stream joined with today's roster (see [computeBranchWorkload]); no new
/// backend query or schema.
class EmployeeWorkload {
  const EmployeeWorkload({
    required this.user,
    this.shiftsToday = const [],
    this.active = 0,
    this.overdue = 0,
    this.submitted = 0,
    this.completedToday = 0,
    this.currentTask,
  });

  final UserEntity user;

  /// The shift(s) this employee is rostered for *today* (from the weekly
  /// schedule). May be empty (off / unscheduled), one, or both.
  final List<ScheduleShift> shiftsToday;

  /// Open work the employee must act on now — pending / started / rework.
  final int active;

  /// Active work already past its deadline (the attention signal).
  final int overdue;

  /// Work the employee has finished and handed off — completed / waiting review.
  final int submitted;

  /// Tasks of theirs approved today (truly done).
  final int completedToday;

  /// What they're working on now — the started task (else next up), or null.
  final TaskEntity? currentTask;

  /// The one signal a manager scans for: this employee is behind.
  bool get needsAttention => overdue > 0;

  /// No open work and nothing in review — caught up.
  bool get isIdle => active == 0 && submitted == 0;

  /// True when at least one figure on this card is non-zero — i.e. there is
  /// something worth drawing a metric strip for. A card with four zeros says
  /// nothing four times, so the strip collapses and the employee reads as one
  /// slim identity row instead.
  bool get hasFigures =>
      active > 0 || overdue > 0 || submitted > 0 || completedToday > 0;

  /// Whether they're rostered at all today.
  bool get isScheduledToday => shiftsToday.isNotEmpty;
}
