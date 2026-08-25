import 'package:opshub/features/task/domain/work_types/work_context.dart';
import 'package:opshub/features/task/domain/work_types/work_draft.dart';
import 'package:opshub/features/task/domain/work_types/work_event.dart';
import 'package:opshub/features/task/domain/work_types/work_field_spec.dart';
import 'package:opshub/features/task/domain/work_types/work_review.dart';
import 'package:opshub/features/task/domain/work_types/work_validation.dart';

/// The behaviour contract for **one kind of operational work** (the Strategy).
///
/// Every work type owns its own fields, milestones *and* rules here, so screens
/// never branch on the type — they ask the definition. Adding a completely new
/// kind of work is a new subclass + one line in [WorkTypeRegistry]: there is
/// **no `switch` anywhere** a new type has to force-edit, which is how
/// Open/Closed emerges from the architecture rather than being bolted on.
///
/// Flutter-free by design (mirrors the `RequestType` convention): icons and
/// widgets live in presentation (`work_type_presenter.dart`), keyed by [id], so
/// this contract and every definition stay trivially unit-testable.
///
/// **Concerns this contract owns** (the ones that genuinely differ per type):
/// dynamic [fields], [timeline] milestones, [validateSetup] / [validateSubmission]
/// gates, [progress], [reviewDisposition], proof requirement, [summarize] and
/// [analytics].
///
/// **Concerns it deliberately does *not* own:** *permissions* stay with
/// `task_access.dart` + the deployed `firestore.rules` (a per-type override
/// would risk diverging from the server-side security gate), and the *coarse
/// status machine* stays generic. Both have a clean seam to extend; we don't add
/// hooks with no consumer.
abstract class WorkTypeDefinition {
  const WorkTypeDefinition();

  /// Stable machine id persisted to `tasks/{id}.workType`. Never rename a
  /// shipped id (old docs resolve by it); unknown ids fall back to `general`.
  String get id;

  /// Human name shown in the type picker and as the task's kind label.
  String get label;

  /// One-line helper shown under the type in the picker.
  String get blurb;

  /// Extra fields (beyond the always-present title/description) this type
  /// captures; their values persist in `tasks/{id}.data`.
  List<WorkFieldSpec> get fields;

  /// Fields the creator fills on the create form (everything not captured at
  /// completion).
  List<WorkFieldSpec> get setupFields =>
      [for (final f in fields) if (!f.capturedAtCompletion) f];

  /// Fields the executing employee fills on the details screen while working.
  List<WorkFieldSpec> get completionFields =>
      [for (final f in fields) if (f.capturedAtCompletion) f];

  /// Ordered, type-specific milestones layered on the coarse status machine.
  /// Empty for types that only use the generic lifecycle.
  List<WorkEvent> get timeline;

  /// Whether this type repurposes the generic checklist as its structured points
  /// (an inspection marks each point pass/warning/fail). When true the details
  /// screen renders the type's own point UI instead of the plain tap-to-complete
  /// checklist — so the screen asks the definition rather than switching on type.
  bool get usesChecklistAsPoints;

  /// Create-time gate: is the manager/admin's [draft] well-formed for this type?
  WorkValidation validateSetup(WorkDraft draft);

  /// Completion gate: may the executing employee submit this work?
  WorkValidation validateSubmission(WorkContext ctx);

  /// 0..1 progress for cards / rings.
  double progress(WorkContext ctx);

  /// How a *completed* piece of this work should be routed for review, given its
  /// state (the manager fast-path lives here).
  ReviewDisposition reviewDisposition(WorkContext ctx);

  /// Whether the employee must attach proof media to submit.
  bool requiresProof(WorkContext ctx);

  /// One-line summary for cards / feed / notification bodies. [title] is the
  /// task's own title, offered as a fallback.
  String summarize(WorkContext ctx, {String? title});

  /// Lightweight analytics facets for this task (e.g. `{'variance': '3'}`).
  /// Empty by default — a type opts in only when it has something to measure.
  Map<String, String> analytics(WorkContext ctx);
}

/// Parity defaults for a work type — the behaviour of today's generic task.
/// Concrete types extend this and **override only what differs**, which is the
/// ergonomic that keeps the system clean as types multiply.
///
/// (Chosen over composing separate strategy objects per concern: each type is a
/// single small cohesive object, and Dart's default-method overrides give the
/// "pay only for what you change" property without the indirection of wiring N
/// collaborator objects. If one concern ever grows its own axis of variation,
/// it can be extracted then — not speculatively now.)
abstract class BaseWorkType extends WorkTypeDefinition {
  const BaseWorkType();

  @override
  List<WorkFieldSpec> get fields => const [];

  @override
  List<WorkEvent> get timeline => const [];

  @override
  bool get usesChecklistAsPoints => false;

  /// Default: every **setup** field must pass its own [WorkFieldSpec.validate]
  /// (completion fields are gated later, at submission).
  @override
  WorkValidation validateSetup(WorkDraft draft) {
    final errors = <String, String>{};
    for (final f in setupFields) {
      final err = f.validate(draft.data[f.key]);
      if (err != null) errors[f.key] = err;
    }
    return errors.isEmpty
        ? const WorkValidation.valid()
        : WorkValidation.fields(errors);
  }

  /// Default completion gate: required checklist items done, and proof attached
  /// when [requiresProof]. Types layer extra checks on top via `super`.
  @override
  WorkValidation validateSubmission(WorkContext ctx) {
    if (!ctx.requiredChecklistComplete) {
      return const WorkValidation.form(
          ['Complete all required checklist items first.']);
    }
    if (requiresProof(ctx) && ctx.proofCount == 0) {
      return const WorkValidation.form(['Attach a proof photo to submit.']);
    }
    return const WorkValidation.valid();
  }

  @override
  double progress(WorkContext ctx) => ctx.checklistProgress;

  @override
  ReviewDisposition reviewDisposition(WorkContext ctx) =>
      ReviewDisposition.standard;

  @override
  bool requiresProof(WorkContext ctx) => false;

  @override
  String summarize(WorkContext ctx, {String? title}) => title ?? label;

  @override
  Map<String, String> analytics(WorkContext ctx) => const {};

  /// Helper for milestone-driven types: fraction of [timeline] events logged
  /// (1.0 when a type declares no milestones).
  double timelineProgress(WorkContext ctx) => timeline.isEmpty
      ? 1
      : timeline.where((e) => ctx.hasEvent(e.id)).length / timeline.length;
}
