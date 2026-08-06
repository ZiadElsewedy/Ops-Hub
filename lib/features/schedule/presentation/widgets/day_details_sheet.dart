import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/enums/leave_type.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:drop/features/schedule/domain/shift_hours.dart';
import 'package:drop/features/schedule/presentation/cubit/schedule_cubit.dart';
import 'package:drop/features/schedule/presentation/cubit/schedule_state.dart';
import 'package:drop/features/schedule/presentation/widgets/employee_picker_sheet.dart';
import 'package:drop/features/schedule/presentation/widgets/employee_row.dart';
import 'package:drop/features/schedule/presentation/widgets/schedule_helpers.dart';
import 'package:drop/features/schedule/presentation/widgets/sheet_chrome.dart';
import 'package:drop/features/schedule/presentation/widgets/shift_hours_scope_dialog.dart';
import 'package:drop/features/schedule/presentation/widgets/shift_templates_sheet.dart';

/// Opens the day sheet for a schedule day — the home of the day's **note**
/// (Inventory · Big delivery · …) and its **leave entries** (annual / sick /
/// day off / pending request). Reads the live [ScheduleCubit] (global
/// provider) so the sheet updates in place as entries are saved (Schedule 5.0).
Future<void> showDayDetailsSheet({
  required BuildContext context,
  required ScheduleDay day,
  required bool canEdit,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.darkSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => DayDetailsSheet(day: day, canEdit: canEdit),
  );
}

/// Tapping a day header (or its leave/notes strip) opens this: the date and
/// weekend hours, staffing at a glance, the manager's day note, and everyone
/// marked away that day — with add/remove leave for managers/admins.
class DayDetailsSheet extends StatefulWidget {
  const DayDetailsSheet({super.key, required this.day, required this.canEdit});

  final ScheduleDay day;
  final bool canEdit;

  @override
  State<DayDetailsSheet> createState() => _DayDetailsSheetState();
}

class _DayDetailsSheetState extends State<DayDetailsSheet> {
  final _noteController = TextEditingController();
  bool _noteSeeded = false;
  String _savedNote = '';

  ScheduleDay get day => widget.day;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

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
    // Seed the note editor once from the loaded schedule — later cubit emits
    // (our own saves) must never clobber what's being typed.
    if (!_noteSeeded) {
      _noteSeeded = true;
      _savedNote = schedule.noteFor(day) ?? '';
      _noteController.text = _savedNote;
    }

    final date = weekStart.add(Duration(days: day.index));
    final morning = validAssignments(
        schedule.employeesFor(day, ScheduleShift.morning), members);
    final night = validAssignments(
        schedule.employeesFor(day, ScheduleShift.night), members);
    final leave = <(UserEntity, LeaveType)>[
      for (final entry in schedule.leaveOn(day).entries)
        if (userForUid(entry.key, members) != null)
          (userForUid(entry.key, members)!, entry.value),
    ];

    final maxHeight = MediaQuery.of(context).size.height * 0.82;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          AppSpacing.md,
          AppSpacing.pagePadding,
          // Keep the note editor above the keyboard.
          MediaQuery.of(context).viewInsets.bottom,
        ),
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
            _staffingLine(morning.length, night.length),
            const SizedBox(height: AppSpacing.lg),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _shiftHoursSection(context, schedule),
                    const SizedBox(height: AppSpacing.lg),
                    _sectionLabel('Day notes'),
                    const SizedBox(height: 2),
                    const Text('One instruction per line — each becomes a bullet '
                        'for the team.',
                        style: AppTypography.caption),
                    const SizedBox(height: AppSpacing.sm),
                    _noteField(context),
                    const SizedBox(height: AppSpacing.lg),
                    _sectionLabel(
                        leave.isEmpty ? 'Leave' : 'Leave · ${leave.length}'),
                    const SizedBox(height: AppSpacing.xs),
                    if (leave.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.md),
                        child: Text('No one is away on ${day.label}.',
                            style: AppTypography.bodySmall),
                      )
                    else
                      for (final (user, type) in leave)
                        EmployeeRow(
                          user: user,
                          subtitle: _leaveSubtitle(schedule, user.uid, type),
                          trailing: widget.canEdit
                              ? _RowAction(
                                  icon: Icons.close_rounded,
                                  tooltip: 'Remove leave',
                                  onTap: () => context
                                      .read<ScheduleCubit>()
                                      .setLeave(day, user.uid, null),
                                )
                              : null,
                        ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
            if (widget.canEdit) _addLeaveButton(context, schedule, members),
            SizedBox(
                height:
                    MediaQuery.of(context).padding.bottom + AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────
  Widget _header(DateTime date, WeeklyScheduleEntity schedule) {
    // The subtitle names the configured night close (not a hardcoded 00:30) so
    // an overnight day reads its real hours right in the header.
    final night = schedule.hoursFor(day, ScheduleShift.night);
    final subtitle = night.crossesMidnight
        ? '${_dateLabel(date)} · night runs till ${night.endLabel}'
        : _dateLabel(date);
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
          child: const Icon(Icons.event_note_outlined,
              size: 22, color: AppColors.textSecondary),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(day.label, style: AppTypography.h3),
              const SizedBox(height: 2),
              Text(subtitle, style: AppTypography.caption),
            ],
          ),
        ),
      ],
    );
  }

  // ── Shift hours (configurable end times) ─────────────────────────
  /// The day's shift hours — read for everyone, **editable** by managers/admins.
  /// The end time is data, not a hardcoded weekend rule: a manager can push a
  /// Friday/Saturday (or a Ramadan/holiday) close later here, no code change.
  Widget _shiftHoursSection(BuildContext context, WeeklyScheduleEntity schedule) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Shift hours'),
        const SizedBox(height: AppSpacing.xs),
        for (final shift in ScheduleShift.values)
          _shiftHoursRow(context, schedule, shift),
        if (widget.canEdit)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => showShiftTemplatesSheet(
                context,
                branchId: schedule.branchId,
                canEdit: widget.canEdit,
              ),
              icon: const Icon(Icons.tune_rounded, size: 16),
              label: const Text('Manage shift templates'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 4),
              ),
            ),
          ),
      ],
    );
  }

  Widget _shiftHoursRow(
      BuildContext context, WeeklyScheduleEntity schedule, ScheduleShift shift) {
    final hours = schedule.hoursFor(day, shift);
    final custom = schedule.hasHoursOverride(day, shift);
    final isMorning = shift == ScheduleShift.morning;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          Icon(isMorning ? Icons.wb_sunny_rounded : Icons.nightlight_round,
              size: 16, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Text(shift.label, style: AppTypography.label),
          const SizedBox(width: AppSpacing.sm),
          // The real configured time, arrow form.
          Text(hours.format(separator: '→'),
              style: AppTypography.label.copyWith(
                color: AppColors.textSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              )),
          if (custom) ...[
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: const BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: AppRadius.fullAll,
              ),
              child: Text('Custom',
                  style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600)),
            ),
          ],
          const Spacer(),
          if (widget.canEdit) ...[
            if (custom)
              _RowAction(
                icon: Icons.settings_backup_restore_rounded,
                tooltip: 'Reset to default',
                onTap: () => context
                    .read<ScheduleCubit>()
                    .setShiftHours(day, shift, null),
              ),
            if (custom) const SizedBox(width: 6),
            _RowAction(
              icon: Icons.schedule_rounded,
              tooltip: 'Edit end time',
              onTap: () => _editShiftEnd(context, hours, shift),
            ),
          ],
        ],
      ),
    );
  }

  /// Pick a new **end** time for [shift] (start times are stable in this
  /// business). An end earlier than the start is read as the next day, so
  /// 01:00 becomes an overnight close (past-midnight = minutes over 1440).
  Future<void> _editShiftEnd(
      BuildContext context, ShiftHours hours, ScheduleShift shift) async {
    final cubit = context.read<ScheduleCubit>();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: (hours.endMinutes % 1440) ~/ 60,
          minute: (hours.endMinutes % 1440) % 60),
      helpText: 'Set the ${shift.label.toLowerCase()} shift end time',
    );
    if (picked == null) return;
    var end = picked.hour * 60 + picked.minute;
    // End at/before start → it closes the next day (overnight).
    if (end <= hours.startMinutes) end += 1440;
    final newHours = ShiftHours(hours.startMinutes, end);
    if (!context.mounted) return;
    // Schedule V2 · Pillar 5 — how far does the change reach? This week only
    // (a per-slot override), future schedules (the template), or globally.
    final scope = await showShiftHoursScopeDialog(
      context,
      title: '${shift.label} hours · ${day.label}',
    );
    if (scope == null) return;
    await cubit.applyShiftHours(day, shift, newHours, scope);
  }

  /// Neutral staffing facts for the day — counts, never targets.
  Widget _staffingLine(int morning, int night) {
    Widget fact(IconData icon, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: AppTypography.label),
          ],
        );
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          Expanded(
              child: fact(Icons.wb_sunny_rounded,
                  'Morning · ${morning == 0 ? 'open' : morning}')),
          Expanded(
              child: fact(Icons.nightlight_round,
                  'Night · ${night == 0 ? 'open' : night}')),
        ],
      ),
    );
  }

  // ── Day note ─────────────────────────────────────────────────────
  Widget _noteField(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _noteController,
      builder: (context, value, _) {
        final dirty = value.text.trim() != _savedNote.trim();
        return TextField(
          controller: _noteController,
          enabled: widget.canEdit,
          // Multi-line: Enter inserts a new line (each becomes a bullet); the
          // explicit save button commits. Roomy cap for a full day briefing.
          minLines: 3,
          maxLines: 8,
          maxLength: 600,
          keyboardType: TextInputType.multiline,
          style: AppTypography.body,
          decoration: InputDecoration(
            hintText: widget.canEdit
                ? 'Arrive 15 min early\nInventory count before opening\n'
                    'Ahmed covers the fitting room'
                : 'No note for this day',
            counterText: '',
            suffixIcon: !widget.canEdit || !dirty
                ? null
                : IconButton(
                    tooltip: 'Save note',
                    icon: const Icon(Icons.check_rounded,
                        size: 20, color: AppColors.primary),
                    onPressed: () => _saveNote(context),
                  ),
          ),
        );
      },
    );
  }

  Future<void> _saveNote(BuildContext context) async {
    final note = _noteController.text.trim();
    final ok = await context.read<ScheduleCubit>().setDayNote(day, note);
    if (ok) _savedNote = note;
  }

  // ── Leave ────────────────────────────────────────────────────────
  String _leaveSubtitle(
      WeeklyScheduleEntity schedule, String uid, LeaveType type) {
    final assigned = schedule.shiftsFor(uid, day);
    if (assigned.isEmpty) return type.label;
    // The one real problem worth naming here: away AND rostered.
    return '${type.label} · still assigned to '
        '${assigned.map((s) => s.label).join(' + ')}';
  }

  Widget _addLeaveButton(BuildContext context, WeeklyScheduleEntity schedule,
      List<UserEntity> members) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showLeavePicker(context, schedule, members),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.darkBorder),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.buttonAll),
        ),
        icon: const Icon(Icons.event_busy_outlined, size: 18),
        label: const Text('Add leave'),
      ),
    );
  }

  void _showLeavePicker(BuildContext context, WeeklyScheduleEntity schedule,
      List<UserEntity> members) {
    final cubit = context.read<ScheduleCubit>();
    showEmployeePicker(
      context: context,
      title: '${day.label} · Leave',
      subtitle: 'Pick who is away, then the reason',
      employees:
          members.where((u) => u.role.isEmployee && u.isActive).toList(),
      isAssigned: (u) => schedule.leaveOn(day).containsKey(u.uid),
      onPick: (u) {
        Navigator.of(context).pop();
        _showTypePicker(cubit, u);
      },
    );
  }

  void _showTypePicker(ScheduleCubit cubit, UserEntity user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          AppSpacing.md,
          AppSpacing.pagePadding,
          MediaQuery.of(sheetContext).padding.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const SizedBox(height: AppSpacing.md),
            Text(shortName(user), style: AppTypography.h3),
            const SizedBox(height: 2),
            Text('Away on ${day.label} — why?', style: AppTypography.caption),
            const SizedBox(height: AppSpacing.md),
            for (final type in LeaveType.values)
              _typeRow(sheetContext, cubit, user, type),
          ],
        ),
      ),
    );
  }

  Widget _typeRow(BuildContext sheetContext, ScheduleCubit cubit,
      UserEntity user, LeaveType type) {
    final icon = switch (type) {
      LeaveType.annual => Icons.beach_access_outlined,
      LeaveType.sick => Icons.medical_services_outlined,
      LeaveType.dayOff => Icons.event_busy_outlined,
      LeaveType.pending => Icons.hourglass_empty_rounded,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: InkWell(
        onTap: () {
          Navigator.of(sheetContext).pop();
          cubit.setLeave(day, user.uid, type);
        },
        borderRadius: AppRadius.mdAll,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.darkBg,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.md),
              Text(type.label, style: AppTypography.label),
            ],
          ),
        ),
      ),
    );
  }

  // ── Small helpers ────────────────────────────────────────────────
  Widget _sectionLabel(String text) => Text(
        text.toUpperCase(),
        style: AppTypography.caption.copyWith(
          color: AppColors.textTertiary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      );

  String _dateLabel(DateTime d) => AppDateFormatter.dayMonth(d);
}

/// Small circular icon action used inline in leave rows.
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
