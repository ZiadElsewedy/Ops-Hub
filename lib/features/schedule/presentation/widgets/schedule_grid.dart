import 'package:flutter/material.dart';
import 'package:opshub/core/enums/leave_type.dart';
import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:opshub/features/schedule/domain/schedule_week.dart';
import 'package:opshub/features/schedule/presentation/schedule_insights.dart';
import 'package:opshub/features/schedule/presentation/widgets/assignment_chip.dart';
import 'package:opshub/features/schedule/presentation/widgets/schedule_helpers.dart';
import 'package:opshub/features/schedule/presentation/widgets/shift_cell.dart';

/// The weekly assignment grid (Schedule 3.0) — days are columns (Sun→Sat),
/// shifts are two rows (Morning / Night). The shift rail and the day headers
/// are **pinned**; the day cells scroll horizontally together so all seven
/// days stay usable and tappable on a phone (per the mobile constraint).
///
/// Every assigned person renders as an individual chip (drag / right-click /
/// tap target); [insights] drive per-chip conflict/caution cues and, when
/// [activeInsight] is set, dim every slot outside that insight's highlight.
/// No staffing quota / target is implied. Orphaned (broken) references are
/// excluded and flagged instead, so cells reflect real, current people.
///
/// Schedule 5.0 adds a **day-info footer row** (leave entries + the manager's
/// day note — tap it or a day header to edit), a "till HH:MM" header tag on any
/// night that closes after midnight (read from the resolved hours, not a
/// hardcoded weekend rule) and a [presentation] mode that renders
/// the print-clean roster used by the Final View.
class ScheduleGrid extends StatelessWidget {
  const ScheduleGrid({
    super.key,
    required this.schedule,
    required this.members,
    required this.onCellTap,
    this.filter,
    this.insights,
    this.activeInsight,
    this.canEdit = false,
    this.presentation = false,
    this.onDayTap,
    this.onMoveChip,
    this.onRemoveChip,
    this.onSwapChip,
    this.onChipActions,
    this.onChipSwapWith,
    this.railWidth = 78,
    this.cellWidth = 136,
    this.cellHeight = 140,
    this.headerHeight = 64,
    this.dayInfoHeight = 46,
  });

  final WeeklyScheduleEntity schedule;
  final List<UserEntity> members;
  final void Function(ScheduleDay day, ScheduleShift shift) onCellTap;

  /// When set, only this shift's row is shown (the header "Shift filter"); null
  /// shows both Morning and Night.
  final ScheduleShift? filter;

  /// Week facts (open / one-person / double-booked / short-rest / leave),
  /// computed by the view.
  final ScheduleInsights? insights;

  /// The insight the user selected on the strip — its slots stay lit, the
  /// rest of the grid dims.
  final ScheduleInsightKind? activeInsight;

  final bool canEdit;

  /// Read-only print/export rendering (Final View): clean cells, no editing
  /// affordances anywhere.
  final bool presentation;

  /// A day header / day-info cell was tapped (editor: opens the day sheet
  /// for notes + leave).
  final void Function(ScheduleDay day)? onDayTap;

  /// Desktop drag-to-move: [data]'s person leaves their source slot for the
  /// drop cell's (day, shift).
  final void Function(
    ChipDragData data,
    ScheduleDay toDay,
    ScheduleShift toShift,
  )?
  onMoveChip;

  /// Chip context-menu remove.
  final void Function(ScheduleDay day, ScheduleShift shift, String uid)?
  onRemoveChip;

  /// Desktop drag-to-switch: [data]'s person was dropped onto `withUid`, who
  /// holds (toDay, toShift) — the two trade slots.
  final void Function(
    ChipDragData data,
    ScheduleDay toDay,
    ScheduleShift toShift,
    String withUid,
  )?
  onSwapChip;

  /// Touch long-press on a chip → the move/switch/remove action sheet
  /// (Schedule 4.0 mobile UX).
  final void Function(ScheduleDay day, ScheduleShift shift, String uid)?
  onChipActions;

  /// Desktop chip context-menu "Switch shifts with…" — the guided flow.
  final void Function(ScheduleDay day, ScheduleShift shift, String uid)?
  onChipSwapWith;

  /// Sizing hooks used by the read-only 1600×900 export canvas. Defaults keep
  /// the interactive editor pixel-identical.
  final double railWidth;
  final double cellWidth;
  final double cellHeight;
  final double headerHeight;
  final double dayInfoHeight;

  /// Whether [day]'s night shift, at its resolved hours, closes after midnight —
  /// drives the "till HH:MM" header tag (data, not a hardcoded weekend rule).
  bool _nightCrossesMidnight(ScheduleDay day) =>
      schedule.hoursFor(day, ScheduleShift.night).crossesMidnight;

  /// Whether the week carries any resolvable leave entry or day note.
  bool get _hasDayInfo {
    for (final day in ScheduleDay.values) {
      if (schedule.noteFor(day) != null) return true;
      for (final uid in schedule.leaveOn(day).keys) {
        if (userForUid(uid, members) != null) return true;
      }
    }
    return false;
  }

  /// The day-info footer renders always in the editor (it's the entry point
  /// for adding leave/notes) but only when it has content on a read-only /
  /// printed roster — an empty row would be print noise.
  bool get showsDayInfo => canEdit || _hasDayInfo;

  /// Total intrinsic height for [filter] — lets callers embed the grid in a
  /// scroll view without unbounded-height surprises.
  double get height =>
      headerHeight +
      (filter == null ? cellHeight * 2 : cellHeight) +
      (showsDayInfo ? dayInfoHeight : 0);

  @override
  Widget build(BuildContext context) {
    // "Today" is an exact calendar-date match against the displayed week — never
    // a weekday-only one, so another week highlights nothing (bug fix).
    bool isToday(ScheduleDay d) => ScheduleWeek.isToday(schedule.weekStart, d);
    final shifts = filter == null ? ScheduleShift.values : [filter!];
    final withDayInfo = showsDayInfo;
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Desktop: when the seven days fit, stretch the cells to fill the
          // width so the week reads as one wide, scan-friendly grid (no
          // horizontal scroll). Mobile: keep fixed cells that scroll sideways.
          final avail = constraints.maxWidth;
          final natural = railWidth + cellWidth * 7;
          final fits = avail.isFinite && avail >= natural;
          final cellW = fits
              ? ((avail - railWidth) / 7).floorToDouble()
              : cellWidth;

          final body = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (final d in ScheduleDay.values)
                    _dayHeader(d, isToday(d), cellW),
                ],
              ),
              for (final s in shifts)
                Row(
                  children: [
                    for (final d in ScheduleDay.values)
                      _cell(d, s, isToday(d), cellW),
                  ],
                ),
              if (withDayInfo)
                Row(
                  children: [
                    for (final d in ScheduleDay.values)
                      _dayInfoCell(d, isToday(d), cellW),
                  ],
                ),
            ],
          );

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pinned left rail: corner spacer + shift labels.
              Column(
                children: [
                  SizedBox(width: railWidth, height: headerHeight),
                  for (final s in shifts) _rail(s),
                  if (withDayInfo) _dayInfoRail(),
                ],
              ),
              Expanded(
                child: fits
                    ? body
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(right: 4),
                        child: body,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _rail(ScheduleShift shift) {
    final isMorning = shift == ScheduleShift.morning;
    return SizedBox(
      width: railWidth,
      height: cellHeight,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Brightness, not colour, distinguishes the shifts (morning brighter)
            // — keeps the rail strictly monochrome.
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isMorning
                    ? AppColors.primarySurface
                    : AppColors.darkSurfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Icon(
                isMorning ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                size: 17,
                color: isMorning
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              shift.label,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              shift.timeRange,
              style: AppTypography.caption.copyWith(height: 1.1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayInfoRail() {
    return SizedBox(
      width: railWidth,
      height: dayInfoHeight,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Leave &\nnotes',
            style: AppTypography.caption.copyWith(
              height: 1.15,
              fontSize: 10,
            ),
          ),
        ),
      ),
    );
  }

  Widget _dayHeader(ScheduleDay day, bool isToday, double cellWidth) {
    final date = schedule.weekStart.add(Duration(days: day.index));
    final header = SizedBox(
      width: cellWidth,
      height: headerHeight,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            day.shortLabel.toUpperCase(),
            style: AppTypography.caption.copyWith(
              color: isToday ? AppColors.primary : AppColors.textTertiary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: isToday
                ? const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  )
                : null,
            child: Text(
              '${date.day}',
              style: AppTypography.labelSmall.copyWith(
                color: isToday ? AppColors.onPrimary : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
          // Nights that run past midnight — say so where the day is named,
          // reading the resolved hours so it tracks the schedule (and any
          // override), never a hardcoded weekend close. Days whose night ends
          // by 23:59 keep an empty spacer so the date circles stay on one line.
          SizedBox(
            height: 13,
            child: _nightCrossesMidnight(day)
                ? Text(
                    'till ${schedule.hoursFor(day, ScheduleShift.night).endLabel}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 9.5,
                      height: 1.3,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
    if (presentation || onDayTap == null) return header;
    return InkWell(
      onTap: () => onDayTap!(day),
      borderRadius: BorderRadius.circular(10),
      child: header,
    );
  }

  Widget _cell(
    ScheduleDay day,
    ScheduleShift shift,
    bool isToday,
    double cellWidth,
  ) {
    final uids = schedule.employeesFor(day, shift);
    final valid = validAssignments(uids, members);
    final orphans = orphanAssignments(uids, members);
    final users = [for (final uid in valid) userForUid(uid, members)!];
    final dimmed =
        activeInsight != null &&
        !(insights?.slotsFor(activeInsight!).contains((day, shift)) ?? false);
    final oppositeUids = validAssignments(
      schedule.employeesFor(day, shift.opposite),
      members,
    ).toSet();
    return ShiftCell(
      key: ValueKey('cell-${day.name}-${shift.name}'),
      users: users,
      day: day,
      shift: shift,
      isToday: isToday,
      hasOrphan: orphans.isNotEmpty,
      width: cellWidth,
      height: cellHeight,
      onTap: () => onCellTap(day, shift),
      canEdit: canEdit,
      presentation: presentation,
      dimmed: dimmed,
      conflictedUids: insights?.doubleBookedByDay[day] ?? const {},
      // Short rest is a morning-side cue (they worked last night); a leave
      // clash marks the person on whichever shift they were given.
      shortRestUids: shift == ScheduleShift.morning
          ? (insights?.shortRestByDay[day] ?? const {})
          : const {},
      leaveClashUids: insights?.leaveClashByDay[day] ?? const {},
      oppositeUids: oppositeUids,
      onDropChip: onMoveChip == null
          ? null
          : (data) => onMoveChip!(data, day, shift),
      onRemoveUid: onRemoveChip == null
          ? null
          : (uid) => onRemoveChip!(day, shift, uid),
      onMoveUidToOpposite: onMoveChip == null
          ? null
          : (uid) => onMoveChip!(
              ChipDragData(uid: uid, day: day, shift: shift),
              day,
              shift.opposite,
            ),
      onSwapChip: onSwapChip == null
          ? null
          : (data, withUid) => onSwapChip!(data, day, shift, withUid),
      onChipActions: onChipActions == null
          ? null
          : (uid) => onChipActions!(day, shift, uid),
      onChipSwapWith: onChipSwapWith == null
          ? null
          : (uid) => onChipSwapWith!(day, shift, uid),
      // Keyboard move reuses the exact drag path: the chip resolves the target
      // slot from its arrow key, we hand it to onMoveChip → the same
      // validation + Firestore write drag-to-move uses.
      onChipKeyboardMove: onMoveChip == null
          ? null
          : (uid, toDay, toShift) => onMoveChip!(
                ChipDragData(uid: uid, day: day, shift: shift),
                toDay,
                toShift,
              ),
    );
  }

  // ── Day-info footer (Schedule 5.0: leave + day notes) ────────────
  Widget _dayInfoCell(ScheduleDay day, bool isToday, double cellWidth) {
    final leave = <(UserEntity, LeaveType)>[
      for (final entry in schedule.leaveOn(day).entries)
        if (userForUid(entry.key, members) != null)
          (userForUid(entry.key, members)!, entry.value),
    ];
    final note = schedule.noteFor(day);

    final content = Container(
      width: cellWidth,
      height: dayInfoHeight,
      padding: const EdgeInsets.all(4),
      child: (leave.isEmpty && note == null)
          ? null
          : ClipRect(
              child: Align(
                alignment: Alignment.topLeft,
                child: Wrap(
                  spacing: 3,
                  runSpacing: 3,
                  children: [
                    for (final (user, type) in leave) _leavePill(user, type),
                    if (note != null) _notePill(note),
                  ],
                ),
              ),
            ),
    );
    if (presentation || onDayTap == null) return content;
    return InkWell(
      onTap: () => onDayTap!(day),
      borderRadius: BorderRadius.circular(10),
      child: content,
    );
  }

  /// `Ahmed · Sick` — leave at a glance, no details needed. A pending
  /// request renders hollow (question, not settled absence).
  Widget _leavePill(UserEntity user, LeaveType type) {
    final firstName = shortName(user).split(' ').first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: type.isPending ? Colors.transparent : AppColors.darkSurfaceElevated,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Text(
        '$firstName · ${type.shortLabel}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.caption.copyWith(
          color: type.isPending
              ? AppColors.textTertiary
              : AppColors.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          fontStyle: type.isPending ? FontStyle.italic : null,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _notePill(String note) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.sticky_note_2_outlined,
            size: 10,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontSize: 10,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
