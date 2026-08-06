import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:drop/features/schedule/presentation/cubit/schedule_cubit.dart';
import 'package:drop/features/schedule/presentation/cubit/schedule_state.dart';
import 'package:drop/features/schedule/presentation/widgets/employee_picker_sheet.dart';
import 'package:drop/features/schedule/presentation/widgets/employee_row.dart';
import 'package:drop/features/schedule/presentation/widgets/schedule_helpers.dart';
import 'package:drop/features/schedule/presentation/widgets/sheet_chrome.dart';

/// Opens the rich shift-details sheet for a (day, shift) cell — the operational
/// control center. Reads the live [ScheduleCubit] (global provider) so the sheet
/// updates in place as the admin assigns / removes employees.
Future<void> showShiftDetailsSheet({
  required BuildContext context,
  required ScheduleDay day,
  required ScheduleShift shift,
  required bool canEdit,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.darkSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => ShiftDetailsSheet(day: day, shift: shift, canEdit: canEdit),
  );
}

/// Tapping a grid cell opens this: shift type · coverage · staffing status, the
/// assigned employees as rich rows (with double-booking conflicts surfaced),
/// broken references with a resolve flow, and — for managers/admins — assign /
/// remove actions that update the schedule instantly.
class ShiftDetailsSheet extends StatelessWidget {
  const ShiftDetailsSheet({
    super.key,
    required this.day,
    required this.shift,
    required this.canEdit,
  });

  final ScheduleDay day;
  final ScheduleShift shift;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ScheduleCubit, ScheduleState>(
      builder: (context, state) => state.maybeWhen(
        loaded: (branchId, weekStart, schedule, members, busy) =>
            schedule == null
                ? const SizedBox.shrink()
                : _content(context, weekStart, schedule, members, busy),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    DateTime weekStart,
    WeeklyScheduleEntity schedule,
    List<UserEntity> members,
    bool busy,
  ) {
    final uids = schedule.employeesFor(day, shift);
    final valid = validAssignments(uids, members);
    final orphans = orphanAssignments(uids, members);
    final assigned = valid
        .map((u) => userForUid(u, members))
        .whereType<UserEntity>()
        .toList();
    final date = weekStart.add(Duration(days: day.index));

    final maxHeight = MediaQuery.of(context).size.height * 0.82;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.pagePadding, AppSpacing.md, AppSpacing.pagePadding, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            if (busy) ...[
              const SizedBox(height: AppSpacing.sm),
              const LinearProgressIndicator(minHeight: 2),
            ],
            const SizedBox(height: AppSpacing.md),
            _header(date, schedule),
            const SizedBox(height: AppSpacing.lg),
            _assignedSummary(assigned.length),
            const SizedBox(height: AppSpacing.lg),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (orphans.isNotEmpty) ...[
                      _sectionLabel(
                          orphans.length == 1
                              ? '1 broken assignment'
                              : '${orphans.length} broken assignments',
                          color: AppColors.warning),
                      const SizedBox(height: AppSpacing.xs),
                      for (final uid in orphans)
                        _orphanRow(context, uid, members),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    _sectionLabel('Assigned · ${assigned.length}'),
                    const SizedBox(height: AppSpacing.xs),
                    if (assigned.isEmpty)
                      _emptyAssigned()
                    else
                      for (final u in assigned)
                        EmployeeRow(
                          user: u,
                          subtitle: _conflictLabel(schedule, u.uid),
                          trailing: canEdit
                              ? _RowAction(
                                  icon: Icons.close_rounded,
                                  onTap: () => context
                                      .read<ScheduleCubit>()
                                      .remove(day, shift, u.uid),
                                )
                              : null,
                        ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
            if (canEdit) _assignButton(context, schedule, members),
            SizedBox(height: MediaQuery.of(context).padding.bottom + AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────
  Widget _header(DateTime date, WeeklyScheduleEntity schedule) {
    final isMorning = shift == ScheduleShift.morning;
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.darkSurfaceElevated,
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Icon(
            isMorning ? Icons.wb_sunny_rounded : Icons.nightlight_round,
            size: 22,
            color: isMorning ? AppColors.warning : AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${day.label} · ${shift.label} Shift',
                  style: AppTypography.h3),
              const SizedBox(height: 2),
              // The real configured hours for this (day, shift) — overnight
              // closes come from the schedule, not a hardcoded weekend rule.
              Text(
                  '${_dateLabel(date)} · '
                  '${schedule.hoursFor(day, shift).format(separator: '→')}',
                  style: AppTypography.caption),
            ],
          ),
        ),
      ],
    );
  }

  /// Neutral assignment summary — how many people are on this shift, never a
  /// target or quota. An empty shift is stated plainly, not flagged as a fault.
  Widget _assignedSummary(int assigned) {
    final empty = assigned == 0;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.darkSurfaceElevated,
              shape: BoxShape.circle,
            ),
            child: Text(
              empty ? '—' : '$assigned',
              style: AppTypography.h3.copyWith(
                color: empty ? AppColors.textTertiary : AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Assigned', style: AppTypography.caption),
                const SizedBox(height: 1),
                Text(
                  empty
                      ? 'No one assigned yet'
                      : '$assigned ${assigned == 1 ? 'person' : 'people'} on this shift',
                  style: AppTypography.label,
                ),
              ],
            ),
          ),
          Icon(
            empty ? Icons.group_off_outlined : Icons.groups_rounded,
            size: 20,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  // ── Rows ─────────────────────────────────────────────────────────
  Widget _orphanRow(
      BuildContext context, String uid, List<UserEntity> members) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warning.withAlpha(20),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.warning.withAlpha(90)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.darkBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_off_outlined,
                size: 18, color: AppColors.warning),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Former employee',
                    style: AppTypography.label
                        .copyWith(color: AppColors.warning)),
                const SizedBox(height: 1),
                const Text('No longer in this branch',
                    style: AppTypography.caption),
              ],
            ),
          ),
          if (canEdit) ...[
            _RowAction(
              icon: Icons.swap_horiz_rounded,
              tooltip: 'Reassign',
              onTap: () =>
                  _reassignOrphan(context, uid, members),
            ),
            const SizedBox(width: 6),
            _RowAction(
              icon: Icons.delete_outline_rounded,
              tooltip: 'Remove',
              onTap: () =>
                  context.read<ScheduleCubit>().remove(day, shift, uid),
            ),
          ],
        ],
      ),
    );
  }

  Widget _emptyAssigned() {
    return const Padding(
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.md),
      child: Row(
        children: [
          Icon(Icons.group_off_outlined,
              size: 18, color: AppColors.textTertiary),
          SizedBox(width: AppSpacing.sm),
          Text('No one assigned to this shift yet.',
              style: AppTypography.bodySmall),
        ],
      ),
    );
  }

  Widget _assignButton(BuildContext context, WeeklyScheduleEntity schedule,
      List<UserEntity> members) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showAssignPicker(context, schedule, members),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.darkBorder),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.buttonAll),
        ),
        icon: const Icon(Icons.person_add_alt_rounded, size: 18),
        label: const Text('Assign employee'),
      ),
    );
  }

  // ── Assign / reassign pickers ────────────────────────────────────
  void _showAssignPicker(BuildContext context, WeeklyScheduleEntity schedule,
      List<UserEntity> members) {
    final cubit = context.read<ScheduleCubit>();
    showEmployeePicker(
      context: context,
      title: '${day.label} · ${shift.label}',
      subtitle: 'Tap an employee to assign',
      employees:
          members.where((u) => u.role.isEmployee && u.isActive).toList(),
      isAssigned: (u) => schedule.isAssigned(u.uid, day, shift),
      // Leave is a caution, not a wall — the row says it, the manager decides.
      subtitleFor: (u) {
        final type = schedule.leaveTypeOf(u.uid, day);
        return type == null ? null : 'On leave · ${type.label}';
      },
      onPick: (u) {
        if (!schedule.isAssigned(u.uid, day, shift)) {
          cubit.assign(day, shift, u.uid);
        }
        Navigator.of(context).pop();
      },
    );
  }

  void _reassignOrphan(
      BuildContext context, String orphanUid, List<UserEntity> members) {
    final cubit = context.read<ScheduleCubit>();
    showEmployeePicker(
      context: context,
      title: 'Reassign shift',
      subtitle: 'Pick an employee to replace the former one',
      employees:
          members.where((u) => u.role.isEmployee && u.isActive).toList(),
      isAssigned: (_) => false,
      onPick: (u) async {
        await cubit.assign(day, shift, u.uid);
        await cubit.remove(day, shift, orphanUid);
        if (context.mounted) Navigator.of(context).pop();
      },
    );
  }

  // ── Small helpers ────────────────────────────────────────────────
  Widget _sectionLabel(String text, {Color? color}) => Text(
        text.toUpperCase(),
        style: AppTypography.caption.copyWith(
          color: color ?? AppColors.textTertiary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      );

  /// A double-booking conflict: the employee also works the other shift today.
  String? _conflictLabel(WeeklyScheduleEntity schedule, String uid) {
    final others =
        schedule.shiftsFor(uid, day).where((s) => s != shift).toList();
    if (others.isEmpty) return null;
    return 'Also on ${others.first.label} — double shift';
  }

  String _dateLabel(DateTime d) => AppDateFormatter.dayMonth(d);
}

/// Small circular icon action used inline in employee / orphan rows.
class _RowAction extends StatelessWidget {
  const _RowAction({required this.icon, required this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: AppColors.darkSurfaceElevated,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: AppColors.textSecondary),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
