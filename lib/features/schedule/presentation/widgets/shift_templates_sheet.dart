import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opshub/core/di/injection.dart';
import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/enums/shift_hours_scope.dart';
import 'package:opshub/core/enums/shift_template_role.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/app_snackbar.dart';
import 'package:opshub/features/schedule/domain/shift_hours.dart';
import 'package:opshub/features/schedule/domain/shift_plan.dart';
import 'package:opshub/features/schedule/domain/shift_template.dart';
import 'package:opshub/features/schedule/presentation/cubit/schedule_cubit.dart';
import 'package:opshub/features/schedule/presentation/cubit/shift_template_cubit.dart';
import 'package:opshub/features/schedule/presentation/cubit/shift_template_state.dart';
import 'package:opshub/features/schedule/presentation/widgets/shift_hours_scope_dialog.dart';

/// The **shift-template manager** (Schedule V2 · Pillar 5) — a simple sheet to
/// view a branch's reusable shift templates and edit their hours, with the
/// *"future / global"* scope choice. No enterprise configuration screens: the
/// three standing templates (Morning · Weekday night · Weekend night) with the
/// overnight-aware hours, and the calm read of which slots each drives.
///
/// Hours edits flow through [ScheduleCubit.applyShiftHours] (which owns the
/// snapshot / restamp side); this sheet owns only the presentation.
Future<void> showShiftTemplatesSheet(
  BuildContext context, {
  required String branchId,
  required bool canEdit,
}) {
  final scheduleCubit = context.read<ScheduleCubit>();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.darkSurface,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: scheduleCubit),
        BlocProvider(
          create: (_) => AppDependencies.createShiftTemplateCubit()
            ..load(branchId),
        ),
      ],
      child: _ShiftTemplatesSheet(canEdit: canEdit),
    ),
  );
}

/// Representative (day, shift) slot for a standing role — the seam the shared
/// [ScheduleCubit.applyShiftHours] edits (it maps the slot back to this role).
({ScheduleDay day, ScheduleShift shift})? _repSlot(ShiftTemplateRole role) =>
    switch (role) {
      ShiftTemplateRole.morning =>
        (day: ScheduleDay.sunday, shift: ScheduleShift.morning),
      ShiftTemplateRole.weekdayNight =>
        (day: ScheduleDay.sunday, shift: ScheduleShift.night),
      ShiftTemplateRole.weekendNight =>
        (day: ScheduleDay.thursday, shift: ScheduleShift.night),
      ShiftTemplateRole.custom => null,
    };

class _ShiftTemplatesSheet extends StatelessWidget {
  const _ShiftTemplatesSheet({required this.canEdit});

  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.schedule_rounded,
                    size: 18, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.sm),
                Text('Shift templates', style: AppTypography.h3),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Reusable shift hours for this branch — edit once, and new '
              'schedules follow.',
              style:
                  AppTypography.caption.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            BlocBuilder<ShiftTemplateCubit, ShiftTemplateState>(
              builder: (context, state) => state.maybeWhen(
                loaded: (set, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final t in set.templates)
                      _TemplateRow(template: t, canEdit: canEdit),
                    if (set.isEmpty) _empty(),
                  ],
                ),
                error: (message) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Text(message,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textSecondary)),
                ),
                orElse: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty() => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Text('No templates yet — using standard hours.',
            style: AppTypography.caption
                .copyWith(color: AppColors.textSecondary)),
      );
}

class _TemplateRow extends StatelessWidget {
  const _TemplateRow({required this.template, required this.canEdit});

  final ShiftTemplate template;
  final bool canEdit;

  bool get _edited =>
      template.role != ShiftTemplateRole.custom &&
      template.hours != ShiftPlan.standard().forRole(template.role);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(template.name,
                        style: AppTypography.label
                            .copyWith(fontWeight: FontWeight.w600)),
                    if (_edited) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: const BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: AppRadius.fullAll,
                        ),
                        child: Text('Edited',
                            style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${template.hours.format(separator: '→')}  ·  ${_appliesTo(template.role)}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          if (canEdit && _repSlot(template.role) != null)
            _RowAction(
              icon: Icons.edit_outlined,
              tooltip: 'Edit hours',
              onTap: () => _editHours(context),
            ),
        ],
      ),
    );
  }

  static String _appliesTo(ShiftTemplateRole role) => switch (role) {
        ShiftTemplateRole.morning => 'Every morning',
        ShiftTemplateRole.weekdayNight => 'Weekday nights',
        ShiftTemplateRole.weekendNight => 'Weekend nights (Thu–Sat)',
        ShiftTemplateRole.custom => 'Not assigned',
      };

  Future<void> _editHours(BuildContext context) async {
    final scheduleCubit = context.read<ScheduleCubit>();
    final slot = _repSlot(template.role);
    if (slot == null) return;

    final start = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: template.hours.startMinutes ~/ 60,
          minute: template.hours.startMinutes % 60),
      helpText: 'Start of ${template.name}',
    );
    if (start == null || !context.mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: (template.hours.endMinutes % 1440) ~/ 60,
          minute: (template.hours.endMinutes % 1440) % 60),
      helpText: 'End of ${template.name} (past midnight = overnight)',
    );
    if (end == null || !context.mounted) return;

    final startMin = start.hour * 60 + start.minute;
    var endMin = end.hour * 60 + end.minute;
    if (endMin <= startMin) endMin += 1440; // overnight close
    final hours = ShiftHours(startMin, endMin);

    final scope = await showShiftHoursScopeDialog(
      context,
      title: 'Update ${template.name}',
      // A template edit isn't week-specific — only the template-level scopes.
      scopes: const [ShiftHoursScope.future, ShiftHoursScope.global],
    );
    if (scope == null) return;

    final ok = await scheduleCubit.applyShiftHours(
        slot.day, slot.shift, hours, scope);
    if (ok && context.mounted) {
      AppSnackbar.success(context, '${template.name} updated · ${scope.label}');
    }
  }
}

class _RowAction extends StatelessWidget {
  const _RowAction(
      {required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.smAll,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
