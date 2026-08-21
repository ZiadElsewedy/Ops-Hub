import 'package:opshub/features/task/domain/work_types/work_context.dart';
import 'package:opshub/features/task/domain/work_types/work_field_spec.dart';
import 'package:opshub/features/task/domain/work_types/work_type_definition.dart';
import 'package:opshub/features/task/domain/work_types/work_review.dart';
import 'package:opshub/features/task/domain/work_types/work_validation.dart';

/// **Purchase / Errand** — buy something against a budget and bring back a
/// receipt, with optional out-of-pocket reimbursement.
///
/// Exercises **money fields + a computed budget check** driving review: a clean,
/// within-budget errand fast-tracks, while going over budget *or* requesting a
/// reimbursement payout keeps a manager in the loop. The receipt is enforced as
/// proof at submission.
class PurchaseErrandWorkType extends BaseWorkType {
  const PurchaseErrandWorkType();

  static const String kItem = 'item';
  static const String kBudget = 'budget';
  static const String kSpent = 'spentAmount';
  static const String kReimbursement = 'reimbursement';

  @override
  String get id => 'purchaseErrand';

  @override
  String get label => 'Purchase / Errand';

  @override
  String get blurb => 'Buy something against a budget, with a receipt.';

  @override
  List<WorkFieldSpec> get fields => const [
        WorkFieldSpec(
          key: kItem,
          label: 'What to buy / do',
          kind: WorkFieldKind.multiline,
        ),
        WorkFieldSpec(
          key: kBudget,
          label: 'Budget',
          kind: WorkFieldKind.currency,
          min: 0,
        ),
        // Captured by the employee at completion.
        WorkFieldSpec(
          key: kSpent,
          label: 'Amount spent',
          kind: WorkFieldKind.currency,
          min: 0,
          required: false,
          capturedAtCompletion: true,
        ),
        WorkFieldSpec(
          key: kReimbursement,
          label: 'Employee paid (needs reimbursement)',
          kind: WorkFieldKind.toggle,
          required: false,
          capturedAtCompletion: true,
        ),
      ];

  // No timeline milestone: "purchased" is fully captured by the amount-spent
  // field + the receipt (proof) at submission, so a separate milestone would be
  // redundant and would leave progress (driven by `spentAmount`) out of step
  // with the spine. Transfer is where the timeline earns its keep.

  num? budget(WorkContext ctx) => ctx.number(kBudget);
  num? spent(WorkContext ctx) => ctx.number(kSpent);
  bool reimbursementRequested(WorkContext ctx) =>
      ctx.value<bool>(kReimbursement) ?? false;

  bool overBudget(WorkContext ctx) {
    final b = budget(ctx);
    final s = spent(ctx);
    return b != null && s != null && s > b;
  }

  @override
  bool requiresProof(WorkContext ctx) => true; // the receipt

  @override
  double progress(WorkContext ctx) => spent(ctx) == null ? 0.0 : 1.0;

  @override
  WorkValidation validateSubmission(WorkContext ctx) {
    if (spent(ctx) == null) {
      return const WorkValidation.fields({kSpent: 'Enter the amount spent.'});
    }
    if (ctx.proofCount == 0) {
      return const WorkValidation.form(['Attach the receipt to submit.']);
    }
    return const WorkValidation.valid();
  }

  /// Over budget or an out-of-pocket payout needs a manager's eyes; a clean,
  /// within-budget errand fast-tracks.
  @override
  ReviewDisposition reviewDisposition(WorkContext ctx) =>
      (overBudget(ctx) || reimbursementRequested(ctx))
          ? ReviewDisposition.standard
          : ReviewDisposition.fastTrack;

  @override
  String summarize(WorkContext ctx, {String? title}) {
    final item = ctx.text(kItem);
    final head = item ?? (title ?? label);
    final s = spent(ctx);
    final b = budget(ctx);
    if (s == null) return b == null ? head : '$head · budget ${_money(b)}';
    return '$head · ${_money(s)}${b == null ? '' : ' / ${_money(b)}'}';
  }

  @override
  Map<String, String> analytics(WorkContext ctx) {
    final s = spent(ctx);
    return {
      if (s != null) 'spent': '$s',
      'overBudget': '${overBudget(ctx)}',
      'reimbursement': '${reimbursementRequested(ctx)}',
    };
  }

  static String _money(num v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}
