import 'package:opshub/features/task/domain/work_types/work_context.dart';
import 'package:opshub/features/task/domain/work_types/work_event.dart';
import 'package:opshub/features/task/domain/work_types/work_field_spec.dart';
import 'package:opshub/features/task/domain/work_types/work_type_definition.dart';
import 'package:opshub/features/task/domain/work_types/work_review.dart';
import 'package:opshub/features/task/domain/work_types/work_validation.dart';

/// **Transfer / Handover** — moving goods between people or branches, dispatched
/// with proof and confirmed on receipt.
///
/// Exercises the framework's **custom timeline** (a two-milestone handshake) and
/// **peer-confirmation review**: the sender dispatches with a handover photo,
/// and the disposition fast-tracks once the receiver confirms — a mismatch (no
/// confirmation) stays standard for a manager to chase.
class TransferWorkType extends BaseWorkType {
  const TransferWorkType();

  static const String kGoods = 'goods';
  static const String kQuantity = 'quantity';
  static const String kDestination = 'destination';

  static const String eventDispatched = 'dispatched';
  static const String eventReceived = 'received';

  @override
  String get id => 'transfer';

  @override
  String get label => 'Transfer / Handover';

  @override
  String get blurb => 'Move goods between people or branches, confirmed on receipt.';

  @override
  List<WorkFieldSpec> get fields => const [
        WorkFieldSpec(
          key: kGoods,
          label: 'Goods',
          hint: 'What is being handed over',
        ),
        WorkFieldSpec(
          key: kQuantity,
          label: 'Quantity',
          kind: WorkFieldKind.integer,
          min: 1,
          required: false,
        ),
        WorkFieldSpec(
          key: kDestination,
          label: 'To (person / branch)',
          hint: 'Who receives it',
        ),
      ];

  @override
  List<WorkEvent> get timeline => const [
        WorkEvent(
          id: eventDispatched,
          label: 'Dispatched',
          actorHint: 'Sender hands over the goods',
          requiresProof: true,
        ),
        WorkEvent(
          id: eventReceived,
          label: 'Received',
          actorHint: 'Receiver confirms receipt',
        ),
      ];

  @override
  bool requiresProof(WorkContext ctx) => true;

  @override
  double progress(WorkContext ctx) => timelineProgress(ctx);

  @override
  WorkValidation validateSubmission(WorkContext ctx) {
    // The sender's part is to dispatch with a handover photo.
    if (ctx.proofCount == 0) {
      return const WorkValidation.form(
          ['Attach a photo of the handover to dispatch.']);
    }
    return const WorkValidation.valid();
  }

  /// Fast-track once the receiver has confirmed; otherwise a manager verifies.
  @override
  ReviewDisposition reviewDisposition(WorkContext ctx) =>
      ctx.hasEvent(eventReceived)
          ? ReviewDisposition.fastTrack
          : ReviewDisposition.standard;

  @override
  String summarize(WorkContext ctx, {String? title}) {
    final goods = ctx.text(kGoods);
    final to = ctx.text(kDestination);
    final head = goods ?? (title ?? label);
    return to == null ? head : '$head → $to';
  }

  @override
  Map<String, String> analytics(WorkContext ctx) =>
      {'confirmed': '${ctx.hasEvent(eventReceived)}'};
}
