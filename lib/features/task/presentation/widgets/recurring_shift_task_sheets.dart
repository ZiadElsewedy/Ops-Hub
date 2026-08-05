import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/enums/task_priority.dart';
import 'package:drop/core/enums/template_repeat_mode.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/widgets/app_snackbar.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/core/widgets/metric_pill.dart';
import 'package:drop/core/widgets/skeleton.dart';
import 'package:drop/features/auth/presentation/widgets/app_button.dart';
import 'package:drop/features/auth/presentation/widgets/app_text_field.dart';
import 'package:drop/features/schedule/domain/shift_hours.dart';
import 'package:drop/features/task/domain/entities/checklist_item.dart';
import 'package:drop/features/task/domain/entities/recurring_task_template_entity.dart';
import 'package:drop/features/task/domain/task_schedule.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/task/presentation/widgets/task_action_sheets.dart';

/// Branch-scoped Automation Center for recurring shift-task templates.
/// Supports create, pause/resume, delete, operational metadata, a per-routine
/// details sheet, and navigation to the last generated task — all reusing the
/// existing sheet entrypoint and recurring-task workflow.
Future<void> showManageRecurringShiftTasksSheet({
  required BuildContext context,
  required TaskCubit cubit,
  required String branchId,
}) async {
  // Never stack one modal sheet on top of another. On desktop/macOS the nested
  // modal barriers can leave the manage sheet dimmed and input-blocked after the
  // form pops, which looks like a frozen app. Close Manage first, then present
  // the next surface as the only modal route. Details loops back to Manage so a
  // routine's card reflects any change made in its details sheet.
  while (true) {
    final action = await showSheet<_RecurringManageAction>(
      context,
      _ManageRecurringShiftTasks(cubit: cubit, branchId: branchId),
    );
    if (action == null || !context.mounted) return;

    if (action.taskId != null) {
      await context.push<void>(RouteNames.taskDetail(action.taskId!));
      return;
    }
    if (action.shouldAdd) {
      await showSheet<bool>(
        context,
        _RecurringShiftTaskForm(cubit: cubit, branchId: branchId),
      );
      return;
    }
    if (action.detailsTemplate != null) {
      final result = await showSheet<_RecurringDetailsResult>(
        context,
        _AutomationDetailsSheet(
          cubit: cubit,
          template: action.detailsTemplate!,
        ),
        useSafeArea: true,
      );
      if (!context.mounted) return;
      if (result?.openTaskId != null) {
        await context.push<void>(RouteNames.taskDetail(result!.openTaskId!));
        return;
      }
      // Fall through: reopen the Automation Center with a fresh list.
      continue;
    }
    return;
  }
}

class _RecurringManageAction {
  const _RecurringManageAction._({
    this.shouldAdd = false,
    this.taskId,
    this.detailsTemplate,
  });

  static const add = _RecurringManageAction._(shouldAdd: true);

  factory _RecurringManageAction.openTask(String taskId) =>
      _RecurringManageAction._(taskId: taskId);

  factory _RecurringManageAction.details(RecurringTaskTemplateEntity t) =>
      _RecurringManageAction._(detailsTemplate: t);

  final bool shouldAdd;
  final String? taskId;
  final RecurringTaskTemplateEntity? detailsTemplate;
}

class _RecurringDetailsResult {
  const _RecurringDetailsResult({this.openTaskId});
  final String? openTaskId;
}

class _ManageRecurringShiftTasks extends StatefulWidget {
  const _ManageRecurringShiftTasks({
    required this.cubit,
    required this.branchId,
  });
  final TaskCubit cubit;
  final String branchId;

  @override
  State<_ManageRecurringShiftTasks> createState() =>
      _ManageRecurringShiftTasksState();
}

class _ManageRecurringShiftTasksState
    extends State<_ManageRecurringShiftTasks> {
  late Future<List<RecurringTaskTemplateEntity>> _future = _load();
  bool _busy = false;

  Future<List<RecurringTaskTemplateEntity>> _load() =>
      widget.cubit.recurringTemplates(widget.branchId);

  void _reload() => setState(() => _future = _load());

  Future<void> _toggleActive(RecurringTaskTemplateEntity t) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.cubit.setRecurringTemplateActive(t, !t.active);
      if (mounted) _reload();
    } catch (_) {
      if (mounted) {
        AppSnackbar.error(context, 'Could not update the recurring task.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(RecurringTaskTemplateEntity t) async {
    if (_busy) return;
    final confirmed = await _confirmDeleteAutomation(context, t.title);
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.cubit.deleteRecurringTemplate(t.id);
      if (mounted) _reload();
    } catch (_) {
      if (mounted) {
        AppSnackbar.error(context, 'Could not delete the recurring task.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _add() => Navigator.of(context).pop(_RecurringManageAction.add);

  void _openDetails(RecurringTaskTemplateEntity t) =>
      Navigator.of(context).pop(_RecurringManageAction.details(t));

  void _openTask(String taskId) =>
      Navigator.of(context).pop(_RecurringManageAction.openTask(taskId));

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _AutomationCenterHeader(),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        FutureBuilder<List<RecurringTaskTemplateEntity>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const _AutomationSkeleton();
            }
            if (snap.hasError) {
              return _AutomationLoadFailure(onRetry: _busy ? null : _reload);
            }
            return _AutomationCenterBody(
              templates: snap.data ?? const [],
              busy: _busy,
              onAdd: _add,
              onToggle: _toggleActive,
              onDelete: _delete,
              onOpenDetails: _openDetails,
              onOpenTask: _openTask,
            );
          },
        ),
      ],
    );
  }
}

class _AutomationCenterHeader extends StatelessWidget {
  const _AutomationCenterHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.darkSurfaceElevated,
              borderRadius: AppRadius.mdAll,
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: const Icon(
              Icons.auto_awesome_motion_rounded,
              size: 22,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Automation Center', style: AppTypography.h3),
                SizedBox(height: 2),
                Text(
                  'Manage recurring shift routines for this branch.',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Card-shaped shimmer shown while the template list loads — mirrors the real
/// card rhythm so the sheet doesn't jump when data arrives (reuses [Skeleton]).
class _AutomationSkeleton extends StatelessWidget {
  const _AutomationSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: const [
            Skeleton(width: 96, height: 34, borderRadius: AppRadius.fullAll),
            SizedBox(width: AppSpacing.sm),
            Skeleton(width: 96, height: 34, borderRadius: AppRadius.fullAll),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        for (var i = 0; i < 2; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == 0 ? AppSpacing.md : 0),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                borderRadius: AppRadius.cardAll,
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Row(
                    children: [
                      Expanded(child: Skeleton(width: 160, height: 14)),
                      SizedBox(width: AppSpacing.md),
                      Skeleton(
                        width: 44,
                        height: 24,
                        borderRadius: AppRadius.fullAll,
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.md),
                  Skeleton(
                    width: 72,
                    height: 22,
                    borderRadius: AppRadius.fullAll,
                  ),
                  SizedBox(height: AppSpacing.md),
                  Skeleton(width: double.infinity, height: 11),
                  SizedBox(height: 8),
                  Skeleton(width: 180, height: 11),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _AutomationCenterBody extends StatelessWidget {
  const _AutomationCenterBody({
    required this.templates,
    required this.busy,
    required this.onAdd,
    required this.onToggle,
    required this.onDelete,
    required this.onOpenDetails,
    required this.onOpenTask,
  });

  final List<RecurringTaskTemplateEntity> templates;
  final bool busy;
  final VoidCallback onAdd;
  final ValueChanged<RecurringTaskTemplateEntity> onToggle;
  final ValueChanged<RecurringTaskTemplateEntity> onDelete;
  final ValueChanged<RecurringTaskTemplateEntity> onOpenDetails;
  final ValueChanged<String> onOpenTask;

  @override
  Widget build(BuildContext context) {
    final isEmpty = templates.isEmpty;
    final maxListHeight = (MediaQuery.sizeOf(context).height * 0.52).clamp(
      280.0,
      520.0,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isEmpty)
          const _AutomationEmptyState()
        else ...[
          _AutomationSummary(templates: templates),
          const SizedBox(height: AppSpacing.lg),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxListHeight),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: templates.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final template = templates[index];
                return _AutomationCard(
                  template: template,
                  busy: busy,
                  onToggle: () => onToggle(template),
                  onDelete: () => onDelete(template),
                  onOpenDetails: () => onOpenDetails(template),
                  onOpenTask: template.lastGeneratedTaskId == null
                      ? null
                      : () => onOpenTask(template.lastGeneratedTaskId!),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Create Automation',
          icon: const Icon(
            Icons.add_rounded,
            size: 20,
            color: AppColors.textDark,
          ),
          onPressed: busy ? null : onAdd,
        ),
      ],
    );
  }
}

class _AutomationSummary extends StatelessWidget {
  const _AutomationSummary({required this.templates});

  final List<RecurringTaskTemplateEntity> templates;

  @override
  Widget build(BuildContext context) {
    final active = templates.where((template) => template.active).length;
    final paused = templates.length - active;
    final failing = templates.where(_AutomationOutcome.isFailing).length;
    final nextRuns =
        templates
            .where((template) => template.active && template.nextRunAt != null)
            .map((template) => template.nextRunAt!)
            .toList()
          ..sort();
    final nextLabel = nextRuns.isEmpty
        ? 'Not scheduled'
        : _nextAutomationLabel(nextRuns.first);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            MetricPill(
              value: '$active',
              label: 'Active',
              icon: Icons.play_circle_outline_rounded,
            ),
            MetricPill(
              value: '$paused',
              label: 'Paused',
              icon: Icons.pause_circle_outline_rounded,
            ),
            if (failing > 0)
              MetricPill(
                value: '$failing',
                label: failing == 1 ? 'Needs attention' : 'Need attention',
                icon: Icons.error_outline_rounded,
                tone: AppColors.error,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _NextAutomationSummary(value: nextLabel),
      ],
    );
  }
}

class _NextAutomationSummary extends StatelessWidget {
  const _NextAutomationSummary({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 16,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Next automation check',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AutomationEmptyState extends StatelessWidget {
  const _AutomationEmptyState();

  @override
  Widget build(BuildContext context) {
    return const GlassContainer(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Column(
          children: [
            Icon(
              Icons.auto_awesome_motion_rounded,
              size: 28,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              'Automate repetitive branch tasks.',
              style: AppTypography.labelLarge,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              'Recurring routines automatically create shift tasks for your team.',
              style: AppTypography.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AutomationLoadFailure extends StatelessWidget {
  const _AutomationLoadFailure({required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.error_outline_rounded, color: AppColors.error),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Automation details could not be loaded.',
                  style: AppTypography.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          const Padding(
            padding: EdgeInsets.only(left: 40),
            child: Text(
              'Check your connection and try again.',
              style: AppTypography.caption,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Try again'),
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact automation card. Tapping the card (or "Details") opens the
/// per-routine details sheet; the switch pauses/resumes inline.
class _AutomationCard extends StatelessWidget {
  const _AutomationCard({
    required this.template,
    required this.busy,
    required this.onToggle,
    required this.onDelete,
    required this.onOpenDetails,
    this.onOpenTask,
  });

  final RecurringTaskTemplateEntity template;
  final bool busy;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onOpenDetails;
  final VoidCallback? onOpenTask;

  @override
  Widget build(BuildContext context) {
    final outcome = _AutomationOutcome.of(template);
    final nextCheck = template.active
        ? _nextAutomationLabel(template.nextRunAt)
        : 'Paused • no publish scheduled';
    return GlassContainer(
      key: ValueKey('automation-card-${template.id}'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: busy ? null : onOpenDetails,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.title,
                      style: AppTypography.labelLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _AutomationStatusPill(template: template),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Semantics(
                label: template.active
                    ? 'Pause ${template.title}'
                    : 'Activate ${template.title}',
                child: Switch(
                  key: ValueKey('automation-toggle-${template.id}'),
                  value: template.active,
                  onChanged: busy ? null : (_) => onToggle(),
                  activeTrackColor: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _CardMetaLine(
            icon: Icons.event_repeat_rounded,
            label: '${_repeatLabel(template)} · ${template.shift.label} shift',
          ),
          const SizedBox(height: AppSpacing.xs),
          _CardMetaLine(
            icon: outcome.icon,
            label: outcome.label,
            tone: outcome.color,
          ),
          if (template.active) ...[
            const SizedBox(height: AppSpacing.xs),
            _CardMetaLine(
              icon: Icons.schedule_send_rounded,
              label: 'Next check · $nextCheck',
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: AppColors.darkBorder),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              TextButton.icon(
                key: ValueKey('automation-details-${template.id}'),
                onPressed: busy ? null : onOpenDetails,
                icon: const Icon(Icons.tune_rounded, size: 17),
                label: const Text('Details'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  textStyle: AppTypography.caption,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                key: ValueKey('automation-delete-${template.id}'),
                onPressed: busy ? null : onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 17),
                label: const Text('Delete'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textTertiary,
                  textStyle: AppTypography.caption,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardMetaLine extends StatelessWidget {
  const _CardMetaLine({required this.icon, required this.label, this.tone});

  final IconData icon;
  final String label;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final color = tone ?? AppColors.textSecondary;
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: AppTypography.caption.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _AutomationStatusPill extends StatelessWidget {
  const _AutomationStatusPill({required this.template});

  final RecurringTaskTemplateEntity template;

  @override
  Widget build(BuildContext context) {
    final failed = _AutomationOutcome.isFailing(template);
    final (label, icon, color) = !template.active
        ? ('Paused', Icons.pause_rounded, AppColors.textSecondary)
        : failed
        ? ('Error', Icons.error_outline_rounded, AppColors.error)
        : ('Active', Icons.circle_rounded, AppColors.success);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: AppRadius.fullAll,
        border: Border.all(color: color.withAlpha(72)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Details sheet ──────────────────────────────────────────────────────────

/// Per-routine details sheet: overview, schedule, next execution, history,
/// failure information, generated task, and actions. Read-only over the
/// template's Cloud-Function-owned health fields; the only writes are
/// pause/resume and delete, reusing [TaskCubit].
class _AutomationDetailsSheet extends StatefulWidget {
  const _AutomationDetailsSheet({required this.cubit, required this.template});

  final TaskCubit cubit;
  final RecurringTaskTemplateEntity template;

  @override
  State<_AutomationDetailsSheet> createState() =>
      _AutomationDetailsSheetState();
}

class _AutomationDetailsSheetState extends State<_AutomationDetailsSheet> {
  late RecurringTaskTemplateEntity _template = widget.template;
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.cubit.setRecurringTemplateActive(
        _template,
        !_template.active,
      );
      if (mounted) {
        setState(
          () => _template = _template.copyWith(active: !_template.active),
        );
      }
    } catch (_) {
      if (mounted) {
        AppSnackbar.error(context, 'Could not update the recurring task.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (_busy) return;
    final confirmed = await _confirmDeleteAutomation(context, _template.title);
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.cubit.deleteRecurringTemplate(_template.id);
      if (mounted) Navigator.of(context).pop(const _RecurringDetailsResult());
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        AppSnackbar.error(context, 'Could not delete the recurring task.');
      }
    }
  }

  void _openTask() {
    final id = _template.lastGeneratedTaskId;
    if (id == null) return;
    Navigator.of(context).pop(_RecurringDetailsResult(openTaskId: id));
  }

  @override
  Widget build(BuildContext context) {
    final t = _template;
    final outcome = _AutomationOutcome.of(t);
    final failing = _AutomationOutcome.isFailing(t);
    final steps = t.checklistItems.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AutomationDetailsHeader(
          template: t,
          onClose: () =>
              Navigator.of(context).pop(const _RecurringDetailsResult()),
        ),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AutomationSnapshotCard(template: t),
                const SizedBox(height: AppSpacing.md),
                _AutomationOutcomeCard(
                  outcome: outcome,
                  lastRunAt: t.lastRunAt,
                  failing: failing,
                  failureCount: t.failureCount,
                ),
                if (t.lastGeneratedTaskId != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _LastGeneratedTaskLink(
                    key: ValueKey('automation-last-task-${t.id}'),
                    title: t.title,
                    meta: _lastGeneratedTaskMeta(t),
                    onTap: _busy ? null : _openTask,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                _AutomationMoreDetails(template: t, checklistSteps: steps),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: t.active ? 'Pause automation' : 'Resume automation',
                  variant: AppButtonVariant.secondary,
                  icon: Icon(
                    t.active ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 20,
                    color: AppColors.textPrimary,
                  ),
                  onPressed: _busy ? null : _toggle,
                ),
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: TextButton.icon(
                    key: ValueKey('automation-details-delete-${t.id}'),
                    onPressed: _busy ? null : _delete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Delete automation'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AutomationDetailsHeader extends StatelessWidget {
  const _AutomationDetailsHeader({
    required this.template,
    required this.onClose,
  });

  final RecurringTaskTemplateEntity template;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final description = template.description?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AUTOMATION',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    template.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.h2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            IconButton(
              key: ValueKey('automation-details-close-${template.id}'),
              onPressed: onClose,
              tooltip: 'Close automation details',
              icon: const Icon(Icons.close_rounded, size: 22),
              style: IconButton.styleFrom(
                fixedSize: const Size.square(44),
                backgroundColor: AppColors.darkSurfaceElevated,
                foregroundColor: AppColors.textSecondary,
                shape: const CircleBorder(),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _AutomationStatusPill(template: template),
        if (description.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _AutomationSnapshotCard extends StatelessWidget {
  const _AutomationSnapshotCard({required this.template});

  final RecurringTaskTemplateEntity template;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          _SnapshotRow(
            icon: Icons.event_repeat_rounded,
            label: 'Schedule',
            value: '${_repeatLabel(template)} · ${template.shift.label} shift',
            detail: _shiftWindowLabel(template),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Divider(height: 1, color: AppColors.darkBorder),
          ),
          _SnapshotRow(
            icon: Icons.schedule_send_rounded,
            label: 'Next check',
            value: template.active
                ? _nextAutomationLabel(template.nextRunAt)
                : 'Paused',
            detail: template.active
                ? 'The routine runs automatically.'
                : 'Resume it when this routine is needed again.',
          ),
        ],
      ),
    );
  }
}

class _SnapshotRow extends StatelessWidget {
  const _SnapshotRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Icon(icon, size: 18, color: AppColors.textSecondary),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTypography.caption),
              const SizedBox(height: 2),
              Text(value, style: AppTypography.label),
              const SizedBox(height: 2),
              Text(detail, style: AppTypography.caption),
            ],
          ),
        ),
      ],
    );
  }
}

class _AutomationOutcomeCard extends StatelessWidget {
  const _AutomationOutcomeCard({
    required this.outcome,
    required this.lastRunAt,
    required this.failing,
    required this.failureCount,
  });

  final _AutomationOutcome outcome;
  final DateTime? lastRunAt;
  final bool failing;
  final int failureCount;

  @override
  Widget build(BuildContext context) {
    final failureDetail = failureCount > 1
        ? '$failureCount consecutive failures · retries automatically'
        : 'The routine will retry automatically';
    final detail = failing && lastRunAt != null
        ? '$failureDetail · ${_lastRunLabel(lastRunAt)}'
        : failing
        ? failureDetail
        : outcome.detail;
    return GlassContainer(
      glow: failing ? AppColors.error : null,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            outcome.icon,
            size: 20,
            color: failing ? AppColors.error : AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Latest outcome', style: AppTypography.caption),
                const SizedBox(height: 3),
                Text(
                  outcome.label,
                  style: AppTypography.label.copyWith(color: outcome.color),
                ),
                const SizedBox(height: 3),
                Text(detail, style: AppTypography.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AutomationMoreDetails extends StatelessWidget {
  const _AutomationMoreDetails({
    required this.template,
    required this.checklistSteps,
  });

  final RecurringTaskTemplateEntity template;
  final int checklistSteps;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      elevated: false,
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ValueKey('automation-more-details-${template.id}'),
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xs,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          leading: const Icon(
            Icons.tune_rounded,
            size: 19,
            color: AppColors.textSecondary,
          ),
          title: const Text('More details', style: AppTypography.label),
          subtitle: const Text(
            'Priority, checklist and task policy',
            style: AppTypography.caption,
          ),
          children: [
            const Divider(height: 1, color: AppColors.darkBorder),
            const SizedBox(height: AppSpacing.sm),
            _DetailRow(
              icon: Icons.flag_outlined,
              label: 'Priority',
              value: template.priority.value,
            ),
            _DetailRow(
              icon: Icons.checklist_rounded,
              label: 'Checklist',
              value: checklistSteps == 0
                  ? 'No required steps'
                  : '$checklistSteps ${checklistSteps == 1 ? 'step' : 'steps'}',
            ),
            _DetailRow(
              icon: Icons.storefront_outlined,
              label: 'Assigned to',
              value: '${template.shift.label} shift roster',
            ),
            _DetailRow(
              icon: Icons.access_time_rounded,
              label: 'Shift timing',
              value: _shiftWindowLabel(template),
              detail: _shiftWindowNote(template),
            ),
            const SizedBox(height: AppSpacing.sm),
            const _MissedPolicyNote(),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textTertiary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.caption),
                const SizedBox(height: 2),
                Text(value, style: AppTypography.labelSmall),
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text(detail!, style: AppTypography.caption),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MissedPolicyNote extends StatelessWidget {
  const _MissedPolicyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Missed policy · Enabled',
                  style: AppTypography.labelSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  // States the grace explicitly. A manager judging a Missed
                  // record needs to know the record already allowed for
                  // finishing a little over (ADR-013).
                  //
                  // Rework is named because a manager who sends a task back is
                  // starting a clock they cannot see: from 2026-08-05 a rejected
                  // instance is closed by the same sweep, so "I rejected it" is
                  // no longer a way to leave work permanently open.
                  'Generated tasks are due at shift end. Unfinished tasks — '
                  'including any sent back for rework — end as Missed '
                  '${kTaskGracePeriod.inMinutes} minutes after that.',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LastGeneratedTaskLink extends StatelessWidget {
  const _LastGeneratedTaskLink({
    super.key,
    required this.title,
    required this.meta,
    required this.onTap,
  });

  final String title;
  final String meta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.darkSurfaceElevated,
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              const Icon(
                Icons.task_alt_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Last task', style: AppTypography.caption),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: AppTypography.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Tap to open',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 15,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shared derivations ─────────────────────────────────────────────────────

/// The single source of truth for how a routine's last generation outcome is
/// described — used by the card meta line, the status pill's failure check, and
/// the details sheet's History/Failure sections, so the three never drift.
class _AutomationOutcome {
  const _AutomationOutcome({
    required this.label,
    required this.detail,
    required this.icon,
    required this.color,
  });

  final String label;
  final String detail;
  final IconData icon;
  final Color color;

  static bool isFailing(RecurringTaskTemplateEntity t) =>
      t.failureCount > 0 || t.lastStatus?.toLowerCase() == 'failed';

  factory _AutomationOutcome.of(RecurringTaskTemplateEntity t) {
    final status = t.lastStatus?.toLowerCase();
    if (isFailing(t)) {
      return _AutomationOutcome(
        label: 'Last generation failed',
        detail: t.failureCount > 1
            ? '${t.failureCount} consecutive failures'
            : _lastRunLabel(t.lastRunAt),
        icon: Icons.error_outline_rounded,
        color: AppColors.error,
      );
    }
    if (t.lastRunAt == null && status == null) {
      return const _AutomationOutcome(
        label: 'Never run',
        detail: 'No generation outcome yet',
        icon: Icons.hourglass_empty_rounded,
        color: AppColors.textTertiary,
      );
    }
    if (status == 'skipped') {
      return _AutomationOutcome(
        label: 'Already generated',
        detail: 'No duplicate task was created • ${_lastRunLabel(t.lastRunAt)}',
        icon: Icons.task_alt_rounded,
        color: AppColors.textSecondary,
      );
    }
    if (status == 'completed') {
      return _AutomationOutcome(
        label: t.lastGeneratedTaskId == null
            ? 'Generation completed'
            : 'Generated successfully',
        detail: _lastRunLabel(t.lastRunAt),
        icon: Icons.check_circle_outline_rounded,
        color: AppColors.textSecondary,
      );
    }
    return _AutomationOutcome(
      label: 'Run recorded',
      detail: _lastRunLabel(t.lastRunAt),
      icon: Icons.history_rounded,
      color: AppColors.textSecondary,
    );
  }
}

const _weekdayLabels = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String _repeatLabel(RecurringTaskTemplateEntity template) =>
    switch (template.repeat) {
      TemplateRepeatMode.once => 'Once',
      TemplateRepeatMode.daily => 'Daily',
      TemplateRepeatMode.weekly =>
        'Every ${_weekdayLabels[(template.weekday - 1).clamp(0, 6)]}',
    };

/// The routine's concrete clock window, derived from the standing [ShiftHours]
/// baseline (no per-week override is known at this level). Weekly routines pin
/// to their target day; daily routines show the weekday baseline.
String _shiftWindowLabel(RecurringTaskTemplateEntity t) {
  final day = t.repeat == TemplateRepeatMode.weekly
      ? ScheduleDay.values[t.weekday % 7]
      : ScheduleDay.sunday; // a representative weekday
  return ShiftHours.standard(day, t.shift).format();
}

/// A qualifier when the concrete window can vary by day.
String? _shiftWindowNote(RecurringTaskTemplateEntity t) {
  if (t.repeat == TemplateRepeatMode.daily && t.shift == ScheduleShift.night) {
    return 'Runs later on weekends (Thu–Sat).';
  }
  return 'Standard hours. A week can override this per day.';
}

String _nextAutomationLabel(DateTime? raw, {DateTime? now}) {
  if (raw == null) return 'Not scheduled yet';
  return AppDateFormatter.relativeDayTime(raw, now: now);
}

String _lastRunLabel(DateTime? raw) => raw == null
    ? 'No run time available'
    : AppDateFormatter.relative(raw.toLocal());

String _lastTaskDateLabel(DateTime? raw, {DateTime? now}) {
  if (raw == null) return 'Generation time unavailable';
  final value = raw.toLocal();
  final current = (now ?? DateTime.now()).toLocal();
  final today = DateTime(current.year, current.month, current.day);
  final day = DateTime(value.year, value.month, value.day);
  if (day == today) return 'Today';
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return AppDateFormatter.dayMonth(value);
}

String _lastGeneratedTaskMeta(RecurringTaskTemplateEntity template) {
  final status = template.lastStatus?.toLowerCase();
  final failed = template.failureCount > 0 || status == 'failed';
  if (failed || status == 'skipped') return 'Previous generated task';
  return _lastTaskDateLabel(template.lastRunAt);
}

/// Confirms a destructive delete of a routine. Returns `true` only on an
/// explicit confirm; deleting stops future generation but leaves past instances.
Future<bool?> _confirmDeleteAutomation(BuildContext context, String title) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.darkSurfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
      title: const Text('Delete automation?', style: AppTypography.h3),
      content: Text(
        '"$title" will stop creating shift tasks. Tasks it already generated '
        'are kept.',
        style: AppTypography.bodySmall,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

/// Form to create a new recurring shift-task template. Pops `true` once saved
/// so the manage sheet refreshes its list.
class _RecurringShiftTaskForm extends StatefulWidget {
  const _RecurringShiftTaskForm({required this.cubit, required this.branchId});
  final TaskCubit cubit;
  final String branchId;

  @override
  State<_RecurringShiftTaskForm> createState() =>
      _RecurringShiftTaskFormState();
}

class _RecurringShiftTaskFormState extends State<_RecurringShiftTaskForm> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  TaskPriority _priority = TaskPriority.normal;
  ScheduleShift? _shift;
  TemplateRepeatMode _repeat = TemplateRepeatMode.daily;
  int _weekday = DateTime.now().weekday;
  final List<_ChecklistRow> _items = [];
  int _idSeq = 0;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _items
      ..add(_ChecklistRow('c${_idSeq++}'))
      ..add(_ChecklistRow('c${_idSeq++}'));
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    for (final i in _items) {
      i.controller.dispose();
    }
    super.dispose();
  }

  void _addItem() => setState(() => _items.add(_ChecklistRow('c${_idSeq++}')));

  void _removeItem(_ChecklistRow row) {
    setState(() {
      _items.remove(row);
      row.controller.dispose();
    });
  }

  Future<void> _save() async {
    if (_error != null) setState(() => _error = null);

    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }
    if (_shift == null) {
      setState(() => _error = 'Please select a shift.');
      return;
    }
    final checklist = <ChecklistItemTemplate>[
      for (final row in _items)
        if (row.controller.text.trim().isNotEmpty)
          ChecklistItemTemplate(
            id: row.id,
            title: row.controller.text.trim(),
            isRequired: row.isRequired,
          ),
    ];
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.cubit.createRecurringShiftTemplate(
        title: title,
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        priority: _priority,
        branchId: widget.branchId,
        shift: _shift!,
        checklistItems: checklist,
        repeat: _repeat,
        weekday: _weekday,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save. Please try again.');
    } finally {
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetTitle('New Automation'),
          AppTextField(
            controller: _title,
            label: 'Title',
            hint: 'e.g. Open Store',
            prefixIcon: Icons.title_rounded,
            autofocus: true,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _desc,
            label: 'Description (optional)',
            prefixIcon: Icons.notes_rounded,
          ),
          const SizedBox(height: AppSpacing.lg),
          ShiftChipPicker(
            value: _shift,
            onChanged: (s) => setState(() => _shift = s),
          ),
          const SizedBox(height: AppSpacing.lg),
          ShiftRepeatPicker(
            value: _repeat,
            onChanged: (v) => setState(() => _repeat = v),
            weekday: _weekday,
            onWeekdayChanged: (w) => setState(() => _weekday = w),
            modes: const [TemplateRepeatMode.daily, TemplateRepeatMode.weekly],
          ),
          const SizedBox(height: AppSpacing.lg),
          _PriorityDropdown(
            value: _priority,
            onChanged: (v) => setState(() => _priority = v),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Row(
            children: [
              Icon(
                Icons.checklist_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: AppSpacing.sm),
              Text('Checklist steps', style: AppTypography.labelSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final row in _items) _checklistRow(row),
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: _addItem,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add step'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              style: AppTypography.caption.copyWith(color: AppColors.error),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Create Automation',
            isLoading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }

  Widget _checklistRow(_ChecklistRow row) {
    return Padding(
      key: ValueKey(row.id),
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.darkSurfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: TextField(
                controller: row.controller,
                style: AppTypography.body.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Step description',
                  hintStyle: AppTypography.body.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: row.isRequired ? 'Required' : 'Optional',
            onPressed: () => setState(() => row.isRequired = !row.isRequired),
            icon: Icon(
              row.isRequired ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 20,
              color: row.isRequired
                  ? AppColors.primary
                  : AppColors.textTertiary,
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: () => _removeItem(row),
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Holds the live editing state of one checklist row (its text + required flag).
class _ChecklistRow {
  _ChecklistRow(this.id, {String text = ''})
    : controller = TextEditingController(text: text);
  final String id;
  final TextEditingController controller;
  bool isRequired = true;
}

/// Minimal priority dropdown, mirroring the small private dropdowns each
/// sheets file already keeps for its own form (see `task_action_sheets.dart`'s
/// `_Dropdown` / `task_template_sheets.dart`'s `_SimpleDropdown`).
class _PriorityDropdown extends StatelessWidget {
  const _PriorityDropdown({required this.value, required this.onChanged});
  final TaskPriority value;
  final void Function(TaskPriority) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<TaskPriority>(
          value: value,
          isExpanded: true,
          dropdownColor: AppColors.darkSurfaceElevated,
          borderRadius: AppRadius.cardAll,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textTertiary,
          ),
          style: AppTypography.body.copyWith(color: AppColors.textPrimary),
          items: [
            for (final p in TaskPriority.values)
              DropdownMenuItem(value: p, child: Text('Priority: ${p.value}')),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
