import 'package:opshub/core/enums/task_status.dart';

/// A Flutter-free, **entity-decoupled snapshot** of a live task that a
/// [WorkTypeDefinition] reasons over. Validation, progress, review disposition
/// and summary all read *this* — never the full 40-field `TaskEntity` — so:
///
///  * definitions stay pure and are unit-testable with a hand-built context, and
///  * the work-type kernel never imports the task entity graph (no cycle, no
///    coupling to fields it doesn't care about).
///
/// A `TaskEntity` is mapped into a [WorkContext] at the one seam that needs it
/// (see `TaskWorkX.workContext`), keeping the adapter thin and one-directional.
class WorkContext {
  /// The task's dynamic, schema-driven field values (keyed by
  /// [WorkFieldSpec.key]).
  final Map<String, dynamic> data;

  final TaskStatus status;

  /// Generic checklist facts.
  final int checklistTotal;
  final int checklistDone;
  final int checklistRequired;
  final int checklistRequiredDone;

  /// Ids of the generic checklist items, in order. Types that repurpose the
  /// checklist as structured points (e.g. an inspection keying per-point results
  /// off these ids) read them here.
  final List<String> checklistItemIds;

  /// Ids of the per-type [WorkEvent] milestones already recorded on the task
  /// (derived from the activity log). Drives milestone progress + "what's next".
  final Set<String> loggedEvents;

  /// Count of employee **proof** media on the submission (distinct from the
  /// manager's reference attachments).
  final int proofCount;

  final int assigneeCount;
  final bool hasDeadline;

  const WorkContext({
    this.data = const {},
    this.status = TaskStatus.pending,
    this.checklistTotal = 0,
    this.checklistDone = 0,
    this.checklistRequired = 0,
    this.checklistRequiredDone = 0,
    this.checklistItemIds = const [],
    this.loggedEvents = const {},
    this.proofCount = 0,
    this.assigneeCount = 0,
    this.hasDeadline = false,
  });

  /// A copy of this context with [extra] more proof media counted. Used at the
  /// submission gate, where the proof being uploaded *right now* must count
  /// toward a type's [WorkTypeDefinition.requiresProof] requirement (it isn't on
  /// the task yet).
  WorkContext withPendingProof(int extra) => WorkContext(
        data: data,
        status: status,
        checklistTotal: checklistTotal,
        checklistDone: checklistDone,
        checklistRequired: checklistRequired,
        checklistRequiredDone: checklistRequiredDone,
        checklistItemIds: checklistItemIds,
        loggedEvents: loggedEvents,
        proofCount: proofCount + extra,
        assigneeCount: assigneeCount,
        hasDeadline: hasDeadline,
      );

  /// Reads [key] from [data] as [T], or `null` when absent / wrong-typed. Keeps
  /// definitions free of repetitive `is`/`as` noise.
  T? value<T>(String key) {
    final v = data[key];
    return v is T ? v : null;
  }

  num? number(String key) => value<num>(key);

  String? text(String key) {
    final v = value<String>(key)?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  /// Whether the milestone [eventId] has been recorded.
  bool hasEvent(String eventId) => loggedEvents.contains(eventId);

  /// Whether every *required* checklist item is ticked (true when there are
  /// none) — the generic completion gate a definition can build on.
  bool get requiredChecklistComplete =>
      checklistRequired == 0 || checklistRequiredDone >= checklistRequired;

  /// 0..1 checklist completion (1.0 when there is no checklist) — the default
  /// progress a work type inherits unless it computes its own.
  double get checklistProgress =>
      checklistTotal == 0 ? 1 : checklistDone / checklistTotal;
}
