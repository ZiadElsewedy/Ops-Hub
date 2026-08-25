import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/features/auth/presentation/widgets/app_button.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/domain/work_types/definitions/inspection_work_type.dart';
import 'package:opshub/features/task/domain/work_types/definitions/inventory_count_work_type.dart';
import 'package:opshub/features/task/domain/work_types/definitions/purchase_errand_work_type.dart';
import 'package:opshub/features/task/domain/work_types/definitions/transfer_work_type.dart';
import 'package:opshub/features/task/domain/work_types/task_work_x.dart';
import 'package:opshub/features/task/domain/work_types/work_context.dart';
import 'package:opshub/features/task/domain/work_types/work_field_spec.dart';
import 'package:opshub/features/task/domain/work_types/work_review.dart';
import 'package:opshub/features/task/domain/work_types/work_type_definition.dart';
import 'package:opshub/features/task/presentation/cubit/task_cubit.dart';
import 'package:opshub/features/task/presentation/widgets/dynamic_work_form.dart';
import 'package:opshub/features/task/presentation/widgets/work_detail_sections.dart';

/// The **adaptive** section of the task-details screen — everything specific to
/// the task's work type, expressed entirely in the shared
/// [work_detail_sections] design language. The screen injects one of these and
/// never branches on the type; this panel *composes* the same premium sections
/// (hero summary, metric cards, progress, captured data, points, timeline,
/// completion) differently per type.
///
/// Composition is the only per-type knowledge, and it lives here in
/// presentation (mirroring `WorkTypePresenter`): an unrecognised type falls
/// through to the **generic** composition built from its own declared fields /
/// timeline / points — so a brand-new work type gets a coherent premium detail
/// view with no screen edit (the framework's Open/Closed promise, preserved).
class WorkTypePanel extends StatelessWidget {
  const WorkTypePanel({
    super.key,
    required this.task,
    required this.cubit,
    required this.interactive,
    this.showReviewHint = false,
  });

  final TaskEntity task;
  final TaskCubit cubit;

  /// The executing employee, with the task still open for work (`started`).
  final bool interactive;

  /// A manager/admin is viewing — surface the review disposition.
  final bool showReviewHint;

  /// Whether this task's type has anything type-specific to show at all (a
  /// general task does not — the panel then renders nothing, so it looks exactly
  /// as tasks do today).
  static bool hasContentFor(TaskEntity task) {
    final def = task.workDefinition;
    return def.fields.isNotEmpty ||
        def.timeline.isNotEmpty ||
        def.usesChecklistAsPoints;
  }

  @override
  Widget build(BuildContext context) {
    if (!hasContentFor(task)) return const SizedBox.shrink();
    final def = task.workDefinition;
    final ctx = task.workContext;

    final sections = <Widget>[
      _summary(ctx, def),
      ..._compose(def, ctx),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.lg),
          sections[i],
        ],
      ],
    );
  }

  /// The one-line headline (summary-before-detail) + a manager fast-path hint.
  Widget _summary(WorkContext ctx, WorkTypeDefinition def) {
    final fastTrack = showReviewHint &&
        task.status.index >= 1 &&
        def.reviewDisposition(ctx) == ReviewDisposition.fastTrack;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            def.summarize(ctx, title: task.title),
            style: AppTypography.body
                .copyWith(color: AppColors.textSecondary, height: 1.4),
          ),
        ),
        if (fastTrack) ...[
          const SizedBox(width: AppSpacing.sm),
          const WorkStatePill(label: 'Auto-approvable', icon: Icons.bolt_rounded),
        ],
      ],
    );
  }

  /// The per-type section list. Unknown types → the generic composition.
  List<Widget> _compose(WorkTypeDefinition def, WorkContext ctx) {
    switch (task.workType) {
      case 'purchaseErrand':
        return _purchase(ctx);
      case 'inventoryCount':
        return _inventory(ctx);
      case 'inspection':
        return _inspection(ctx);
      case 'transfer':
        return _transfer(ctx);
      default:
        return _generic(def, ctx);
    }
  }

  // ── Purchase / Errand ─────────────────────────────────────────────
  List<Widget> _purchase(WorkContext ctx) {
    const def = PurchaseErrandWorkType();
    final budget = def.budget(ctx);
    final spent = def.spent(ctx);
    final over = def.overBudget(ctx);
    final reimburse = def.reimbursementRequested(ctx);
    final remaining =
        (budget != null && spent != null) ? budget - spent : null;
    final item = ctx.text(PurchaseErrandWorkType.kItem);

    final (String, WorkTone, IconData) state = spent == null
        ? ('Awaiting spend', WorkTone.neutral, Icons.schedule_rounded)
        : over
            ? ('Over budget', WorkTone.attention, Icons.warning_amber_rounded)
            : ('Within budget', WorkTone.neutral, Icons.check_rounded);

    return [
      WorkCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WorkEyebrow(
              'Purchase',
              icon: Icons.account_balance_wallet_outlined,
              trailing:
                  WorkStatePill(label: state.$1, icon: state.$3, tone: state.$2),
            ),
            const SizedBox(height: AppSpacing.lg),
            WorkStatStrip(stats: [
              WorkStat(
                  value: budget == null ? '—' : WorkFmt.money(budget),
                  label: 'Budget'),
              WorkStat(
                value: spent == null ? '—' : WorkFmt.money(spent),
                label: 'Spent',
                tone: over ? WorkTone.attention : WorkTone.neutral,
              ),
              WorkStat(
                value: remaining == null
                    ? '—'
                    : (remaining < 0
                        ? WorkFmt.signed(remaining)
                        : WorkFmt.money(remaining)),
                label: 'Remaining',
                tone: (remaining != null && remaining < 0)
                    ? WorkTone.attention
                    : WorkTone.neutral,
              ),
            ]),
            if (budget != null && budget > 0 && spent != null) ...[
              const SizedBox(height: AppSpacing.lg),
              WorkProgressBar(
                value: spent / budget,
                leading: 'Spent of budget',
                trailing: '${(spent / budget * 100).round()}%',
                tone: over ? WorkTone.attention : WorkTone.neutral,
              ),
            ],
            if (reimburse) ...[
              const SizedBox(height: AppSpacing.lg),
              const _NoteRow(
                icon: Icons.account_balance_wallet_outlined,
                text: 'Employee paid out of pocket — reimbursement requested.',
              ),
            ],
          ],
        ),
      ),
      if (item != null)
        WorkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const WorkEyebrow('What to buy', icon: Icons.shopping_bag_outlined),
              const SizedBox(height: AppSpacing.sm),
              Text(item,
                  style: AppTypography.body
                      .copyWith(color: AppColors.textSecondary, height: 1.5)),
            ],
          ),
        ),
      if (interactive) _CompletionCapture(task: task, cubit: cubit),
    ];
  }

  // ── Inventory Count ───────────────────────────────────────────────
  List<Widget> _inventory(WorkContext ctx) {
    const def = InventoryCountWorkType();
    final expected = ctx.number(InventoryCountWorkType.kExpectedQty)?.toInt();
    final counted = ctx.number(InventoryCountWorkType.kCountedQty)?.toInt();
    final variance = def.variance(ctx);
    final area = ctx.text(InventoryCountWorkType.kArea);
    final reason = ctx.text(InventoryCountWorkType.kDiscrepancyReason);

    final (String, WorkTone, IconData) state = counted == null
        ? ('Awaiting count', WorkTone.neutral, Icons.schedule_rounded)
        : variance == 0
            ? ('Reconciled', WorkTone.neutral, Icons.check_rounded)
            : (variance! > 0
                ? ('Surplus +$variance', WorkTone.attention,
                    Icons.trending_up_rounded)
                : ('Shrinkage $variance', WorkTone.attention,
                    Icons.trending_down_rounded));

    return [
      WorkCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WorkEyebrow(
              'Stock count',
              icon: Icons.inventory_2_outlined,
              trailing:
                  WorkStatePill(label: state.$1, icon: state.$3, tone: state.$2),
            ),
            if (area != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(area,
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
            ],
            const SizedBox(height: AppSpacing.lg),
            WorkStatStrip(stats: [
              WorkStat(
                  value: expected?.toString() ?? '—', label: 'Expected'),
              WorkStat(value: counted?.toString() ?? '—', label: 'Counted'),
              WorkStat(
                value: variance == null ? '—' : WorkFmt.signed(variance),
                label: 'Difference',
                tone: variance == null
                    ? WorkTone.neutral
                    : (variance == 0 ? WorkTone.neutral : WorkTone.attention),
              ),
            ]),
          ],
        ),
      ),
      if (interactive)
        _CompletionCapture(task: task, cubit: cubit)
      else if (reason != null)
        WorkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const WorkEyebrow('Discrepancy note',
                  icon: Icons.edit_note_rounded),
              const SizedBox(height: AppSpacing.sm),
              Text(reason,
                  style: AppTypography.body
                      .copyWith(color: AppColors.textSecondary, height: 1.5)),
            ],
          ),
        ),
    ];
  }

  // ── Inspection ────────────────────────────────────────────────────
  List<Widget> _inspection(WorkContext ctx) {
    const def = InspectionWorkType();
    final pass = def.passes(ctx);
    final warn = def.warnings(ctx);
    final fail = def.failures(ctx);
    final total = task.checklist.length;
    final marked = pass + warn + fail;

    final (String, WorkTone, IconData) state = fail > 0
        ? ('$fail failed', WorkTone.attention, Icons.report_gmailerrorred_rounded)
        : marked < total
            ? ('In progress', WorkTone.neutral, Icons.timelapse_rounded)
            : ('All clear', WorkTone.neutral, Icons.verified_outlined);

    return [
      WorkCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WorkEyebrow(
              'Inspection score',
              icon: Icons.fact_check_outlined,
              trailing:
                  WorkStatePill(label: state.$1, icon: state.$3, tone: state.$2),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('$pass',
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      letterSpacing: -1,
                      color: AppColors.textPrimary,
                    )),
                const SizedBox(width: AppSpacing.sm),
                Text('of $total points passed',
                    style: AppTypography.body
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            WorkSegmentBar(pass: pass, warning: warn, fail: fail),
          ],
        ),
      ),
      WorkCard(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
        child: _InspectionPoints(
          task: task,
          cubit: cubit,
          interactive: interactive,
        ),
      ),
    ];
  }

  // ── Transfer / Handover ───────────────────────────────────────────
  List<Widget> _transfer(WorkContext ctx) {
    final goods = ctx.text(TransferWorkType.kGoods);
    final qty = ctx.number(TransferWorkType.kQuantity);
    final dest = ctx.text(TransferWorkType.kDestination);
    final dispatched = ctx.hasEvent(TransferWorkType.eventDispatched);
    final received = ctx.hasEvent(TransferWorkType.eventReceived);

    final (String, WorkTone, IconData) state = received
        ? ('Received', WorkTone.positive, Icons.task_alt_rounded)
        : dispatched
            ? ('In transit', WorkTone.neutral, Icons.local_shipping_outlined)
            : ('Preparing', WorkTone.neutral, Icons.inventory_2_outlined);

    return [
      WorkCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WorkEyebrow(
              'Transfer',
              icon: Icons.swap_horiz_rounded,
              trailing:
                  WorkStatePill(label: state.$1, icon: state.$3, tone: state.$2),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(goods ?? 'Goods',
                style: AppTypography.h3.copyWith(color: AppColors.textPrimary)),
            if (qty != null) ...[
              const SizedBox(height: 2),
              Text('Quantity ${WorkFmt.money(qty)}',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textTertiary)),
            ],
            const SizedBox(height: AppSpacing.lg),
            _RouteBar(
              fromDone: dispatched,
              toDone: received,
              destination: dest ?? 'Destination',
            ),
          ],
        ),
      ),
      WorkCard(
        child: _Timeline(task: task, cubit: cubit, interactive: interactive),
      ),
    ];
  }

  // ── Generic (default for any unrecognised type) ───────────────────
  List<Widget> _generic(WorkTypeDefinition def, WorkContext ctx) {
    final setup = def.setupFields
        .where((f) => task.data[f.key] != null)
        .toList(growable: false);
    return [
      if (setup.isNotEmpty)
        WorkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const WorkEyebrow('Details', icon: Icons.description_outlined),
              const SizedBox(height: AppSpacing.md),
              WorkFacts(facts: [
                for (final f in setup)
                  WorkFact(
                    f.label,
                    formatWorkValue(task.data[f.key]),
                    multiline: f.kind == WorkFieldKind.multiline,
                  ),
              ]),
            ],
          ),
        ),
      if (def.usesChecklistAsPoints)
        WorkCard(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
          child: _InspectionPoints(
              task: task, cubit: cubit, interactive: interactive),
        ),
      if (def.completionFields.isNotEmpty)
        if (interactive)
          _CompletionCapture(task: task, cubit: cubit)
        else
          _RecordedCard(task: task),
      if (def.timeline.isNotEmpty)
        WorkCard(
          child: _Timeline(task: task, cubit: cubit, interactive: interactive),
        ),
    ];
  }
}

/// A quiet inline note row inside a card (e.g. a reimbursement flag).
class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textTertiary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

/// The two-endpoint transfer route (origin → destination) with a connecting
/// track whose progress reflects the handshake.
class _RouteBar extends StatelessWidget {
  const _RouteBar({
    required this.fromDone,
    required this.toDone,
    required this.destination,
  });
  final bool fromDone;
  final bool toDone;
  final String destination;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _node(
          icon: Icons.outbox_rounded,
          label: 'Dispatch',
          done: fromDone,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _track(fromDone && toDone),
          ),
        ),
        _node(
          icon: Icons.place_outlined,
          label: destination,
          done: toDone,
          alignEnd: true,
        ),
      ],
    );
  }

  Widget _track(bool full) {
    return Container(
      height: 2,
      decoration: BoxDecoration(
        color: full ? AppColors.textPrimary : AppColors.darkBorder,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  Widget _node({
    required IconData icon,
    required String label,
    required bool done,
    bool alignEnd = false,
  }) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: done ? AppColors.primary : AppColors.darkBg,
            shape: BoxShape.circle,
            border: Border.all(
                color: done ? AppColors.primary : AppColors.darkBorder),
          ),
          child: Icon(icon,
              size: 19,
              color: done ? AppColors.onPrimary : AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 92,
          child: Text(label,
              textAlign: alignEnd ? TextAlign.end : TextAlign.start,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary)),
        ),
      ],
    );
  }
}

/// Read-only captured completion values, as a premium fact card (used by the
/// generic composition for a viewer).
class _RecordedCard extends StatelessWidget {
  const _RecordedCard({required this.task});
  final TaskEntity task;
  @override
  Widget build(BuildContext context) {
    final fields = task.workDefinition.completionFields
        .where((f) => task.data[f.key] != null)
        .toList(growable: false);
    if (fields.isEmpty) return const SizedBox.shrink();
    return WorkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkEyebrow('Recorded', icon: Icons.done_all_rounded),
          const SizedBox(height: AppSpacing.md),
          WorkFacts(facts: [
            for (final f in fields)
              WorkFact(
                f.label,
                formatWorkValue(task.data[f.key]),
                multiline: f.kind == WorkFieldKind.multiline,
              ),
          ]),
        ],
      ),
    );
  }
}

/// The employee's completion-field editor (buffered → Save), reusing the same
/// dynamic form as the create screen, presented in the shared card language.
class _CompletionCapture extends StatefulWidget {
  const _CompletionCapture({required this.task, required this.cubit});
  final TaskEntity task;
  final TaskCubit cubit;
  @override
  State<_CompletionCapture> createState() => _CompletionCaptureState();
}

class _CompletionCaptureState extends State<_CompletionCapture> {
  late Map<String, dynamic> _buffer = {...widget.task.data};

  @override
  Widget build(BuildContext context) {
    final def = widget.task.workDefinition;
    return WorkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkEyebrow('Record your results', icon: Icons.edit_note_rounded),
          const SizedBox(height: AppSpacing.md),
          DynamicWorkForm(
            definition: def,
            fields: def.completionFields,
            initialData: widget.task.data,
            onChanged: (data) => _buffer = data,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              label: 'Save',
              variant: AppButtonVariant.secondary,
              onPressed: () {
                final patch = <String, dynamic>{
                  for (final f in def.completionFields) f.key: _buffer[f.key],
                };
                widget.cubit.updateWorkData(widget.task, patch);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Per-point pass/warning/fail marking for an inspection (points = the task's
/// checklist items; results live in `data['results']`).
class _InspectionPoints extends StatelessWidget {
  const _InspectionPoints({
    required this.task,
    required this.cubit,
    required this.interactive,
  });
  final TaskEntity task;
  final TaskCubit cubit;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    const def = InspectionWorkType();
    final ctx = task.workContext;
    if (task.checklist.isEmpty) {
      return Text('No inspection points yet.',
          style:
              AppTypography.caption.copyWith(color: AppColors.textTertiary));
    }
    final results = (task.data[InspectionWorkType.kResults] as Map?)
            ?.cast<String, dynamic>() ??
        const {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const WorkEyebrow('Inspection points', icon: Icons.checklist_rtl_rounded),
        const SizedBox(height: AppSpacing.md),
        for (final item in task.checklist)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: AppTypography.body
                        .copyWith(color: AppColors.textPrimary)),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final r in InspectionResult.values)
                      _ResultChip(
                        result: r,
                        selected: def.resultFor(ctx, item.id) == r,
                        onTap: interactive
                            ? () => _mark(results, item.id, r)
                            : null,
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _mark(Map<String, dynamic> current, String itemId, InspectionResult r) {
    final next = {...current};
    // Tapping the selected result again clears it.
    if (next[itemId] == r.value) {
      next.remove(itemId);
    } else {
      next[itemId] = r.value;
    }
    cubit.updateWorkData(task, {InspectionWorkType.kResults: next});
  }
}

class _ResultChip extends StatelessWidget {
  const _ResultChip({
    required this.result,
    required this.selected,
    required this.onTap,
  });
  final InspectionResult result;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Monochrome by default; only a failure carries the sanctioned attention
    // red (per the design system — colour for the destructive/attention case).
    final accent =
        result == InspectionResult.fail ? AppColors.error : AppColors.primary;
    final bg = selected ? accent : AppColors.darkBg;
    final fg = selected ? AppColors.onPrimary : AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null && !selected ? 0.5 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: AppRadius.smAll,
            border:
                Border.all(color: selected ? accent : AppColors.darkBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icon, size: 14, color: fg),
              const SizedBox(width: 5),
              Text(_label,
                  style: AppTypography.caption.copyWith(
                    color: fg,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  IconData get _icon => switch (result) {
        InspectionResult.pass => Icons.check_rounded,
        InspectionResult.warning => Icons.warning_amber_rounded,
        InspectionResult.fail => Icons.close_rounded,
      };

  String get _label => switch (result) {
        InspectionResult.pass => 'Pass',
        InspectionResult.warning => 'Warn',
        InspectionResult.fail => 'Fail',
      };
}

/// The ordered milestone timeline (e.g. Dispatched → Received) drawn as a
/// connected spine. The employee logs the next pending milestone; everyone sees
/// what's done.
class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.task,
    required this.cubit,
    required this.interactive,
  });
  final TaskEntity task;
  final TaskCubit cubit;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final def = task.workDefinition;
    final ctx = task.workContext;
    final timeline = def.timeline;
    final nextIndex = timeline.indexWhere((e) => !ctx.hasEvent(e.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const WorkEyebrow('Timeline', icon: Icons.timeline_rounded),
        const SizedBox(height: AppSpacing.md),
        for (var i = 0; i < timeline.length; i++)
          Builder(builder: (_) {
            final e = timeline[i];
            final done = ctx.hasEvent(e.id);
            final isNext = i == nextIndex;
            final isLast = i == timeline.length - 1;
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Spine: node + connector.
                  Column(
                    children: [
                      Icon(
                        done
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 20,
                        color: done
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            color: done
                                ? AppColors.textPrimary
                                : AppColors.darkBorder,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Padding(
                      padding:
                          EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.lg),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.label,
                                    style: AppTypography.body.copyWith(
                                      color: done
                                          ? AppColors.textPrimary
                                          : AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    )),
                                if (e.actorHint != null) ...[
                                  const SizedBox(height: 1),
                                  Text(e.actorHint!,
                                      style: AppTypography.caption.copyWith(
                                          color: AppColors.textTertiary)),
                                ],
                              ],
                            ),
                          ),
                          if (interactive && isNext)
                            _LogButton(
                                onTap: () =>
                                    cubit.logWorkEvent(task, eventId: e.id)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _LogButton extends StatelessWidget {
  const _LogButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
        decoration: const BoxDecoration(
          color: AppColors.primary,
          borderRadius: AppRadius.smAll,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_task_rounded,
                size: 15, color: AppColors.onPrimary),
            const SizedBox(width: 5),
            Text('Log',
                style: AppTypography.caption.copyWith(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w700,
                )),
          ],
        ),
      ),
    );
  }
}

/// Presentation formatting for a captured `data` value (dates, money, bools).
String formatWorkValue(dynamic v) {
  if (v == null) return '—';
  if (v is bool) return v ? 'Yes' : 'No';
  if (v is DateTime) {
    return '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';
  }
  return '$v';
}
