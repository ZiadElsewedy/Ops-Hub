import 'package:opshub/features/task/domain/work_types/work_context.dart';
import 'package:opshub/features/task/domain/work_types/work_type_definition.dart';
import 'package:opshub/features/task/domain/work_types/work_draft.dart';
import 'package:opshub/features/task/domain/work_types/work_review.dart';
import 'package:opshub/features/task/domain/work_types/work_validation.dart';

/// The outcome of one inspection point.
enum InspectionResult {
  pass,
  warning,
  fail;

  String get value => name;

  static InspectionResult? fromString(String? raw) {
    for (final r in InspectionResult.values) {
      if (r.name == raw) return r;
    }
    return null;
  }
}

/// **Inspection** — walk a structured checklist, marking each point pass,
/// warning or fail.
///
/// This is the richest exercise of the framework because it shows **composition
/// with existing infrastructure**: an inspection reuses the task's *generic
/// checklist* for its points (the creator adds them with the existing inline
/// checklist editor — no new "repeatable field" primitive needed), and stores a
/// per-point [InspectionResult] in `data['results']` keyed by the checklist
/// item id.
///
/// It has a **different completion gate** (every point must have a result, not
/// merely be ticked), a **conditional review** (any `fail` demands a manager;
/// all-clear fast-tracks), and **result-count analytics**.
class InspectionWorkType extends BaseWorkType {
  const InspectionWorkType();

  /// `data` key holding `{ checklistItemId: 'pass' | 'warning' | 'fail' }`.
  static const String kResults = 'results';

  @override
  String get id => 'inspection';

  @override
  String get label => 'Inspection';

  @override
  String get blurb => 'Walk a checklist, marking each point pass, warning or fail.';

  @override
  bool get usesChecklistAsPoints => true;

  // Points come from the generic checklist, so this type declares no dynamic
  // fields of its own.

  Map<String, dynamic> _results(WorkContext ctx) {
    final raw = ctx.data[kResults];
    return raw is Map ? raw.cast<String, dynamic>() : const {};
  }

  /// The recorded result for a checklist point, or `null` if not yet marked.
  InspectionResult? resultFor(WorkContext ctx, String itemId) =>
      InspectionResult.fromString(_results(ctx)[itemId] as String?);

  int _count(WorkContext ctx, InspectionResult result) =>
      ctx.checklistItemIds.where((id) => resultFor(ctx, id) == result).length;

  int passes(WorkContext ctx) => _count(ctx, InspectionResult.pass);
  int warnings(WorkContext ctx) => _count(ctx, InspectionResult.warning);
  int failures(WorkContext ctx) => _count(ctx, InspectionResult.fail);

  /// An inspection needs at least one point (added as a checklist item).
  @override
  WorkValidation validateSetup(WorkDraft draft) {
    if (draft.checklistCount == 0) {
      return const WorkValidation.form(['Add at least one inspection point.']);
    }
    return super.validateSetup(draft);
  }

  @override
  double progress(WorkContext ctx) {
    if (ctx.checklistItemIds.isEmpty) return 0;
    final resulted =
        ctx.checklistItemIds.where((id) => resultFor(ctx, id) != null).length;
    return resulted / ctx.checklistItemIds.length;
  }

  @override
  WorkValidation validateSubmission(WorkContext ctx) {
    if (ctx.checklistItemIds.isEmpty) {
      return const WorkValidation.form(['This inspection has no points to mark.']);
    }
    final unmarked =
        ctx.checklistItemIds.where((id) => resultFor(ctx, id) == null).length;
    if (unmarked > 0) {
      return WorkValidation.form(
          ['Mark a result for every point ($unmarked left).']);
    }
    return const WorkValidation.valid();
  }

  /// Any failure demands a manager; a clean sheet (only passes/warnings)
  /// fast-tracks.
  @override
  ReviewDisposition reviewDisposition(WorkContext ctx) => failures(ctx) > 0
      ? ReviewDisposition.standard
      : ReviewDisposition.fastTrack;

  @override
  String summarize(WorkContext ctx, {String? title}) {
    if (ctx.checklistItemIds.isEmpty) return title ?? label;
    return '${passes(ctx)} pass · ${warnings(ctx)} warning · ${failures(ctx)} fail';
  }

  @override
  Map<String, String> analytics(WorkContext ctx) => {
        'pass': '${passes(ctx)}',
        'warning': '${warnings(ctx)}',
        'fail': '${failures(ctx)}',
      };
}
