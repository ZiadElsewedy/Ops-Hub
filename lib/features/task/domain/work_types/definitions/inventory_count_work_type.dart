import 'package:opshub/features/task/domain/work_types/work_context.dart';
import 'package:opshub/features/task/domain/work_types/work_field_spec.dart';
import 'package:opshub/features/task/domain/work_types/work_type_definition.dart';
import 'package:opshub/features/task/domain/work_types/work_review.dart';
import 'package:opshub/features/task/domain/work_types/work_validation.dart';

/// **Inventory Count** — count stock on hand against the system figure and
/// report any discrepancy.
///
/// Exercises a **computed metric** ([variance]) that drives both a *custom
/// completion gate* (a mismatch must be explained before it can be submitted)
/// and the *review disposition* (a reconciled count fast-tracks; a discrepancy
/// stays standard). Declares no [timeline] — proof that a type can rely purely
/// on the coarse lifecycle.
class InventoryCountWorkType extends BaseWorkType {
  const InventoryCountWorkType();

  static const String kArea = 'area';
  static const String kExpectedQty = 'expectedQty';
  static const String kCountedQty = 'countedQty';
  static const String kDiscrepancyReason = 'discrepancyReason';

  @override
  String get id => 'inventoryCount';

  @override
  String get label => 'Inventory Count';

  @override
  String get blurb => 'Count stock on hand and flag any variance.';

  @override
  List<WorkFieldSpec> get fields => const [
        WorkFieldSpec(
          key: kArea,
          label: 'Area / section',
          hint: 'e.g. Back stockroom',
        ),
        WorkFieldSpec(
          key: kExpectedQty,
          label: 'System quantity',
          kind: WorkFieldKind.integer,
          min: 0,
        ),
        // Captured by the executing employee at completion.
        WorkFieldSpec(
          key: kCountedQty,
          label: 'Counted quantity',
          kind: WorkFieldKind.integer,
          min: 0,
          required: false,
          capturedAtCompletion: true,
        ),
        WorkFieldSpec(
          key: kDiscrepancyReason,
          label: 'Discrepancy note',
          kind: WorkFieldKind.multiline,
          required: false,
          capturedAtCompletion: true,
          hint: 'Explain any mismatch',
        ),
      ];

  int? _expected(WorkContext ctx) => ctx.number(kExpectedQty)?.toInt();
  int? _counted(WorkContext ctx) => ctx.number(kCountedQty)?.toInt();

  /// Counted − expected, or `null` until both are known. Positive = surplus,
  /// negative = shrinkage.
  int? variance(WorkContext ctx) {
    final e = _expected(ctx);
    final c = _counted(ctx);
    return (e == null || c == null) ? null : c - e;
  }

  bool _reconciled(WorkContext ctx) => variance(ctx) == 0;

  @override
  double progress(WorkContext ctx) => _counted(ctx) == null ? 0.0 : 1.0;

  @override
  WorkValidation validateSubmission(WorkContext ctx) {
    if (_counted(ctx) == null) {
      return const WorkValidation.fields(
          {kCountedQty: 'Enter the counted quantity.'});
    }
    final v = variance(ctx);
    if (v != null && v != 0 && ctx.text(kDiscrepancyReason) == null) {
      return const WorkValidation.fields(
          {kDiscrepancyReason: 'Explain the discrepancy before submitting.'});
    }
    return super.validateSubmission(ctx);
  }

  /// A reconciled count fast-tracks; any variance stays standard for review.
  @override
  ReviewDisposition reviewDisposition(WorkContext ctx) => _reconciled(ctx)
      ? ReviewDisposition.fastTrack
      : ReviewDisposition.standard;

  @override
  String summarize(WorkContext ctx, {String? title}) {
    final area = ctx.text(kArea);
    final v = variance(ctx);
    if (v == null) return area != null ? 'Count · $area' : (title ?? label);
    final signed = v > 0 ? '+$v' : '$v';
    final state = v == 0 ? 'reconciled' : 'variance $signed';
    return area != null ? '$area · $state' : state;
  }

  @override
  Map<String, String> analytics(WorkContext ctx) {
    final v = variance(ctx);
    if (v == null) return const {};
    return {'variance': '$v', 'reconciled': '${v == 0}'};
  }
}
