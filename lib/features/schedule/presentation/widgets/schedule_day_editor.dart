import 'package:flutter/material.dart';
import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/utils/app_date_formatter.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:opshub/features/schedule/domain/schedule_week.dart';
import 'package:opshub/features/schedule/presentation/widgets/employee_row.dart';
import 'package:opshub/features/schedule/presentation/widgets/schedule_helpers.dart';

/// The **phone-native weekly editor** — the roomy replacement for the
/// horizontally-scrolling coverage grid, which crams seven days into ~390px and
/// left every cell too tight to tap comfortably.
///
/// One day at a time: a day selector on top (coverage dot per day), then the
/// selected day's **Morning** and **Night** cards, each listing who's on the
/// shift with a move-to-the-other-shift and a remove control, plus an add
/// button. Every edit is delegated back to the host's **validated** handlers
/// (the same move/remove/assign paths the desktop grid uses), so this is purely
/// a new presentation — no new edit logic, no new rules.
///
/// Desktop is untouched; the grid + inspector stay the operations surface there.
class ScheduleDayEditor extends StatefulWidget {
  const ScheduleDayEditor({
    super.key,
    required this.schedule,
    required this.members,
    required this.canEdit,
    required this.onAdd,
    required this.onRemove,
    required this.onMove,
    required this.onPersonTap,
    required this.onDayDetails,
  });

  final WeeklyScheduleEntity schedule;
  final List<UserEntity> members;
  final bool canEdit;

  /// Open the employee picker to assign someone to (day, shift).
  final void Function(ScheduleDay day, ScheduleShift shift) onAdd;

  /// Remove [uid] from (day, shift) — routed through the host's confirm + undo.
  final void Function(ScheduleDay day, ScheduleShift shift, String uid) onRemove;

  /// Move [uid] from (day, shift) to the **other** shift the same day.
  final void Function(ScheduleDay day, ScheduleShift shift, String uid) onMove;

  /// Tap a person → the full action sheet (move / switch with a coworker / …).
  final void Function(ScheduleDay day, ScheduleShift shift, String uid)
      onPersonTap;

  /// Open the day's notes & leave editor.
  final void Function(ScheduleDay day) onDayDetails;

  @override
  State<ScheduleDayEditor> createState() => _ScheduleDayEditorState();
}

class _ScheduleDayEditorState extends State<ScheduleDayEditor> {
  late ScheduleDay _selected;

  @override
  void initState() {
    super.initState();
    // Land on today when editing the current week; otherwise start at Sunday.
    final currentWeek = ScheduleWeek.startOf(DateTime.now()) ==
        ScheduleWeek.startOf(widget.schedule.weekStart);
    _selected = currentWeek ? ScheduleDay.today() : ScheduleDay.sunday;
  }

  WeeklyScheduleEntity get _schedule => widget.schedule;

  /// Valid (non-orphan) assignees on a slot.
  List<UserEntity> _people(ScheduleDay day, ScheduleShift shift) => [
        for (final uid in _schedule.employeesFor(day, shift))
          if (userForUid(uid, widget.members) != null)
            userForUid(uid, widget.members)!,
      ];

  bool _covered(ScheduleDay day) =>
      _people(day, ScheduleShift.morning).isNotEmpty &&
      _people(day, ScheduleShift.night).isNotEmpty;

  bool _isToday(ScheduleDay day) =>
      ScheduleWeek.startOf(DateTime.now()) ==
          ScheduleWeek.startOf(_schedule.weekStart) &&
      ScheduleDay.today() == day;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _daySelector(),
        const SizedBox(height: AppSpacing.lg),
        _dayHeader(),
        const SizedBox(height: AppSpacing.md),
        _shiftCard(ScheduleShift.morning),
        const SizedBox(height: AppSpacing.md),
        _shiftCard(ScheduleShift.night),
        const SizedBox(height: AppSpacing.md),
        _leaveAndNotes(),
        const SizedBox(height: AppSpacing.md),
        _summary(),
      ],
    );
  }

  // ── Day selector ───────────────────────────────────────────────
  Widget _daySelector() {
    return SizedBox(
      height: 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: ScheduleDay.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final day = ScheduleDay.values[i];
          final selected = day == _selected;
          final date = _schedule.weekStart.add(Duration(days: day.index));
          return GestureDetector(
            onTap: () => setState(() => _selected = day),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 48,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.darkSurface,
                borderRadius: AppRadius.lgAll,
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.darkBorder,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    day.shortLabel.toUpperCase(),
                    style: AppTypography.labelSmall.copyWith(
                      fontSize: 10,
                      letterSpacing: 0.4,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? AppColors.onPrimary.withAlpha(160)
                          : AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${date.day}',
                    style: AppTypography.label.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: selected
                          ? AppColors.onPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _covered(day)
                          ? (selected
                              ? AppColors.onPrimary.withAlpha(120)
                              : AppColors.success)
                          : AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Day header ─────────────────────────────────────────────────
  Widget _dayHeader() {
    final date = _schedule.weekStart.add(Duration(days: _selected.index));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  _selected.label,
                  style: AppTypography.h3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                AppDateFormatter.dayMonth(date),
                style: AppTypography.caption
                    .copyWith(color: AppColors.textTertiary),
              ),
              if (_isToday(_selected)) ...[
                const SizedBox(width: AppSpacing.sm),
                _pill('Today'),
              ],
            ],
          ),
        ),
        if (widget.canEdit)
          TextButton.icon(
            onPressed: () => widget.onDayDetails(_selected),
            icon: const Icon(Icons.edit_note_rounded, size: 18),
            label: const Text('Notes & leave'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            ),
          ),
      ],
    );
  }

  // ── Shift card ─────────────────────────────────────────────────
  Widget _shiftCard(ScheduleShift shift) {
    final isMorning = shift == ScheduleShift.morning;
    final people = _people(_selected, shift);
    final empty = people.isEmpty;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(
          color: empty
              ? AppColors.warning.withAlpha(70)
              : AppColors.darkBorder,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.darkSurfaceElevated,
                    borderRadius: AppRadius.mdAll,
                    border: Border.all(color: AppColors.darkBorder),
                  ),
                  child: Icon(
                    isMorning
                        ? Icons.wb_sunny_outlined
                        : Icons.nightlight_round,
                    size: 18,
                    color: isMorning
                        ? AppColors.warning
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(shift.label, style: AppTypography.label),
                      Text(
                        _schedule.hoursFor(_selected, shift).format(),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textTertiary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                if (empty)
                  _tag('Open', AppColors.warning,
                      AppColors.warning.withAlpha(36))
                else
                  _tag(
                    '${people.length} ${people.length == 1 ? 'person' : 'people'}',
                    AppColors.textSecondary,
                    AppColors.darkSurfaceElevated,
                  ),
              ],
            ),
          ),
          if (empty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 2, AppSpacing.md, AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.warning,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'No one assigned — this shift is uncovered.',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textTertiary),
                    ),
                  ),
                ],
              ),
            )
          else
            for (final user in people)
              Container(
                decoration: const BoxDecoration(
                  border:
                      Border(top: BorderSide(color: AppColors.darkBorder)),
                ),
                child: EmployeeRow(
                  user: user,
                  subtitle: _conflictLabel(user.uid, shift),
                  onTap: widget.canEdit
                      ? () => widget.onPersonTap(_selected, shift, user.uid)
                      : null,
                  trailing: widget.canEdit
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _rowIcon(
                              icon: Icons.swap_vert_rounded,
                              tooltip: 'Move to '
                                  '${shift.opposite.label.toLowerCase()}',
                              onTap: () =>
                                  widget.onMove(_selected, shift, user.uid),
                            ),
                            const SizedBox(width: 6),
                            _rowIcon(
                              icon: Icons.close_rounded,
                              tooltip: 'Remove',
                              danger: true,
                              onTap: () =>
                                  widget.onRemove(_selected, shift, user.uid),
                            ),
                          ],
                        )
                      : null,
                ),
              ),
          if (widget.canEdit)
            InkWell(
              onTap: () => widget.onAdd(_selected, shift),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.darkBorder)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_rounded,
                        size: 18, color: AppColors.textPrimary),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Add to ${shift.label.toLowerCase()}',
                      style: AppTypography.label
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Leave & notes summary ──────────────────────────────────────
  Widget _leaveAndNotes() {
    final onLeave = _schedule.leaveOn(_selected);
    final notes = _schedule.noteLinesFor(_selected);
    final leaveParts = <String>[
      for (final e in onLeave.entries)
        if (userForUid(e.key, widget.members) != null)
          '${nameForUid(e.key, widget.members)} (${e.value.shortLabel})',
    ];
    if (leaveParts.isEmpty && notes.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leaveParts.isNotEmpty)
            _metaLine(Icons.beach_access_outlined,
                'On leave · ${leaveParts.join(', ')}'),
          if (leaveParts.isNotEmpty && notes.isNotEmpty)
            const SizedBox(height: AppSpacing.sm),
          if (notes.isNotEmpty)
            _metaLine(Icons.sticky_note_2_outlined, notes.join(' · ')),
        ],
      ),
    );
  }

  Widget _summary() {
    final m = _people(_selected, ScheduleShift.morning).length;
    final n = _people(_selected, ScheduleShift.night).length;
    final total = {
      ..._schedule.employeesFor(_selected, ScheduleShift.morning),
      ..._schedule.employeesFor(_selected, ScheduleShift.night),
    }.where((uid) => userForUid(uid, widget.members) != null).length;
    return Row(
      children: [
        const Icon(Icons.functions_rounded,
            size: 14, color: AppColors.textTertiary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '${_selected.label}: $m morning · $n night · $total scheduled',
            style:
                AppTypography.caption.copyWith(color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ── Small pieces ───────────────────────────────────────────────
  /// The employee also works the other shift today — flag it, same wording the
  /// shift sheet uses.
  String? _conflictLabel(String uid, ScheduleShift shift) {
    final others =
        _schedule.shiftsFor(uid, _selected).where((s) => s != shift).toList();
    if (others.isEmpty) return null;
    return 'Also on ${others.first.label} — double shift';
  }

  Widget _metaLine(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.textTertiary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style:
                AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _tag(String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.fullAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.labelSmall.copyWith(
          color: fg,
          fontSize: 10,
          letterSpacing: 0.4,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _pill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accentSurface,
        borderRadius: AppRadius.fullAll,
        border: Border.all(color: AppColors.accentBorder),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _rowIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.darkSurfaceElevated,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Icon(
            icon,
            size: 17,
            color: danger ? AppColors.error : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
