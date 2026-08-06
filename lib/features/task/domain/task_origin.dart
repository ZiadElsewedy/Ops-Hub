/// **Who put this task here** — the pure origin classification behind the Task
/// Details attribution line. No Flutter, no Firestore, so it is unit-testable
/// and cannot drift from the data.
///
/// `tasks/{id}.createdBy` alone cannot answer "who created this task?". A
/// recurring shift instance inherits the **template's** `createdBy`
/// (`generateShiftTaskInstances` copies `t.createdBy`), so an auto-generated
/// task looks byline-identical to one a manager typed out by hand — while its
/// activity log says `actorId: "system"`. Reading `createdBy` on its own
/// therefore credited a person for work the server produced at 01:00. This file
/// is the one place that distinction is made.
library;

import 'package:drop/features/task/domain/entities/task_entity.dart';

/// How a task came into existence.
enum TaskOrigin {
  /// A person filled in the create form.
  manual,

  /// The nightly `generateShiftTaskInstances` sweep materialised it from a
  /// [RecurringTaskTemplateEntity] (stamps `sourceTemplateId` + `correlationId`).
  recurringShift,

  /// `TaskCubit._spawnNextRecurrence` spawned it as the successor of a
  /// per-task recurrence chain (stamps `recurrenceRootId` / `occurrenceKey`).
  recurrenceChain,
}

extension TaskOriginX on TaskOrigin {
  /// True when the actor was the system, not a person — the whole reason this
  /// enum exists.
  bool get isAutomated => this != TaskOrigin.manual;

  /// The attribution shown beside "System". Deliberately says *automated task*
  /// rather than naming the mechanism: an employee reading Task Details needs
  /// to know nobody hand-assigned this, not which sweep produced it.
  String? get label => switch (this) {
    TaskOrigin.manual => null,
    TaskOrigin.recurringShift => 'Automated task',
    TaskOrigin.recurrenceChain => 'Automated task',
  };
}

/// The name a system-generated task is attributed to, everywhere.
const String kSystemActorName = 'System';

/// The `activityLog[].actorId` the server writes for its own transitions
/// (generation, the auto-end sweep). Mirrors the literal in
/// `functions/index.js` / `functions/recurring_task_deadline.js`; it is **not**
/// a uid, so it never resolves in the user directory — which is how it used to
/// render as the anonymous "Someone".
const String kSystemActorId = 'system';

/// True when [actorId] is the server rather than a person.
bool isSystemActorId(String? actorId) =>
    (actorId ?? '').trim().toLowerCase() == kSystemActorId;

/// Classifies [task]'s origin from the fields the producers stamp.
///
/// Checked most-specific first: a recurring shift instance carries
/// `sourceTemplateId` (and, once deployed, `correlationId`); a recurrence-chain
/// successor carries `recurrenceRootId`. A task with neither was typed by a
/// person. Purely additive fields, so an older document simply reads [manual] —
/// the honest answer for a task written before automation existed.
TaskOrigin taskOrigin(TaskEntity task) {
  bool has(String? v) => (v ?? '').trim().isNotEmpty;
  if (has(task.sourceTemplateId) || has(task.correlationId)) {
    return TaskOrigin.recurringShift;
  }
  if (has(task.recurrenceRootId)) return TaskOrigin.recurrenceChain;
  return TaskOrigin.manual;
}

/// Shorthand for `taskOrigin(task).isAutomated`.
bool isAutomatedTask(TaskEntity task) => taskOrigin(task).isAutomated;
