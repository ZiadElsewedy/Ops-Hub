/// Lifecycle of a task, stored as a string in `tasks/{taskId}.status`:
///
/// `pending → started → completed → waitingReview → approved | rejected`
///
/// A task closes in exactly one of three ways
/// (`docs/design/AUTOMATED_TASKS_PRODUCT_SPEC.md` §2):
///  - [approved] — the work was accepted on review;
///  - [missed] — the shift window closed on unfinished work. **System-set and
///    exclusive to automated shift tasks**; a manual task never auto-misses;
///  - [cancelled] — a manager/admin decided the work will not be done. Manual,
///    universal (any task type), and **neither success nor failure** for
///    reporting (it is excluded from the completion rate entirely, §8).
///
/// Employees drive a task up to [waitingReview] (start / complete their own
/// work); only a manager/admin sets the terminal [approved] / [rejected] on
/// review (enforced by `firestore.rules`). [missed] is server-set only, and
/// [cancelled] is manager/admin-only — an employee may never cancel (§5.1).
///
/// **"Late" is deliberately absent.** It is a derived visual overlay on any
/// active, past-deadline task (see `isTaskOverdue`), never a stored state (§3.1).
enum TaskStatus {
  pending,
  started,
  completed,
  waitingReview,
  approved,
  rejected,
  missed,
  cancelled;

  String get value => name;

  bool get isPending => this == TaskStatus.pending;
  bool get isStarted => this == TaskStatus.started;
  bool get isCompleted => this == TaskStatus.completed;
  bool get isWaitingReview => this == TaskStatus.waitingReview;
  bool get isApproved => this == TaskStatus.approved;
  bool get isRejected => this == TaskStatus.rejected;
  bool get isMissed => this == TaskStatus.missed;
  bool get isCancelled => this == TaskStatus.cancelled;

  /// Whether this is a terminal review outcome (approved / rejected) that only
  /// a manager/admin may set.
  bool get isReviewed => isApproved || isRejected;

  /// A closed lifecycle outcome. A missed or cancelled task is no longer
  /// actionable, even though it was never reviewed or approved.
  bool get isTerminal => isApproved || isMissed || isCancelled;

  /// Whether the lifecycle can still progress. Individual screens may use a
  /// narrower operational definition (for example, review work is not an
  /// employee's active task), but a missed or cancelled task is never active.
  bool get isActive => !isTerminal;

  /// Whether a manager/admin may cancel a task in this state. Cancellation is an
  /// **early exit** taken from `pending` or `started` only — a submitted task
  /// must be reviewed, never voided, and a terminal is terminal (§5.4).
  bool get isCancellable => isPending || isStarted;

  /// Parses the stored string; unknown/missing → [pending].
  static TaskStatus fromString(String? raw) {
    switch (raw) {
      case 'started':
        return TaskStatus.started;
      case 'completed':
        return TaskStatus.completed;
      case 'waitingReview':
        return TaskStatus.waitingReview;
      case 'approved':
        return TaskStatus.approved;
      case 'rejected':
        return TaskStatus.rejected;
      case 'missed':
        return TaskStatus.missed;
      case 'cancelled':
        return TaskStatus.cancelled;
      case 'pending':
      default:
        return TaskStatus.pending;
    }
  }
}
