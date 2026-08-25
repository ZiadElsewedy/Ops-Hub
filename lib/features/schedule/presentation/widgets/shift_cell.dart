import 'package:flutter/material.dart';
import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/schedule/presentation/widgets/assignment_chip.dart';

/// One shift slot in the weekly grid. Every assigned person renders as an
/// [AssignmentChip] — an individual click / drag / right-click target — so the
/// cell is a workspace, not a summary. The cell itself is a [DragTarget]: on
/// desktop a chip dragged from another slot can be dropped here to move the
/// person. An empty slot is a muted dashed "Open" placeholder; today's column
/// gets a white ring + a whisper of tint; a broken reference is flagged; a
/// cell outside the active insight highlight dims. A staffed cell carries a
/// quiet corner count (staffing at a glance). Strictly monochrome — red only
/// on a real double-booking, amber only on a soft caution (short rest /
/// on-leave clash). [presentation] renders the print-clean read-only version.
class ShiftCell extends StatefulWidget {
  const ShiftCell({
    super.key,
    required this.users,
    required this.day,
    required this.shift,
    required this.isToday,
    required this.hasOrphan,
    required this.width,
    required this.height,
    required this.onTap,
    this.canEdit = false,
    this.presentation = false,
    this.dimmed = false,
    this.conflictedUids = const {},
    this.shortRestUids = const {},
    this.leaveClashUids = const {},
    this.oppositeUids = const {},
    this.onDropChip,
    this.onRemoveUid,
    this.onMoveUidToOpposite,
    this.onSwapChip,
    this.onChipActions,
    this.onChipSwapWith,
    this.onChipKeyboardMove,
  });

  final List<UserEntity> users;
  final ScheduleDay day;
  final ScheduleShift shift;
  final bool isToday;
  final bool hasOrphan;
  final double width;
  final double height;
  final VoidCallback onTap;

  final bool canEdit;

  /// Read-only print/export rendering (Final View): no dashed placeholders,
  /// hover states, drop affordances or overflow collapsing — a clean sheet.
  final bool presentation;

  /// True when an insight chip is active and this slot is NOT part of it —
  /// the cell fades back so the highlighted slots pop.
  final bool dimmed;

  /// People double-booked on this day (chip shows the red conflict cue).
  final Set<String> conflictedUids;

  /// People opening this morning after working last night (amber cue).
  final Set<String> shortRestUids;

  /// People assigned here while marked on leave today (amber cue).
  final Set<String> leaveClashUids;

  /// Who's already on this day's opposite shift — gates the chip's
  /// "move to …" action so it can't create a double-booking.
  final Set<String> oppositeUids;

  /// A chip from another slot was dropped here (desktop drag-to-move).
  final void Function(ChipDragData data)? onDropChip;
  final void Function(String uid)? onRemoveUid;
  final void Function(String uid)? onMoveUidToOpposite;

  /// A chip was dropped ON a person in this cell (desktop drag-to-switch):
  /// [data] is the dragged person, `withUid` the person they land on.
  final void Function(ChipDragData data, String withUid)? onSwapChip;

  /// Touch long-press on a chip → the move/switch/remove action sheet.
  final void Function(String uid)? onChipActions;

  /// Desktop context-menu "Switch shifts with…" on a chip.
  final void Function(String uid)? onChipSwapWith;

  /// A chip here received an arrow key on desktop — move that person into
  /// [toDay]/[toShift] (the grid routes it through the validated move path).
  final void Function(String uid, ScheduleDay toDay, ScheduleShift toShift)?
      onChipKeyboardMove;

  static const double radius = 14;

  /// Crowded-cell rule (Schedule 4.0): up to [maxChips] + 1 people render in
  /// full; a busier cell shows the first [maxChips] chips and collapses the
  /// rest into a tappable "+N more" pill (→ the full shift panel). So a cell
  /// never shows a "+1 more" that hides exactly one person.
  static const int maxChips = 3;

  @override
  State<ShiftCell> createState() => _ShiftCellState();
}

class _ShiftCellState extends State<ShiftCell> {
  bool _hovered = false;

  bool get _empty => widget.users.isEmpty;

  /// Whisper of white on today's column — enough to anchor the eye, never
  /// loud (item: today emphasis).
  Color _todayTint(Color base) => widget.isToday
      ? Color.alphaBlend(AppColors.primary.withAlpha(9), base)
      : base;

  @override
  Widget build(BuildContext context) {
    if (widget.presentation) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: _presentationBody(),
        ),
      );
    }
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: DragTarget<ChipDragData>(
          onWillAcceptWithDetails: (d) =>
              widget.canEdit &&
              widget.onDropChip != null &&
              !(d.data.day == widget.day && d.data.shift == widget.shift) &&
              !widget.users.any((u) => u.uid == d.data.uid),
          onAcceptWithDetails: (d) => widget.onDropChip?.call(d.data),
          builder: (context, candidates, _) {
            final targeted = candidates.isNotEmpty;
            return MouseRegion(
              onEnter: (_) => setState(() => _hovered = true),
              onExit: (_) => setState(() => _hovered = false),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: widget.dimmed && !targeted ? 0.35 : 1,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onTap,
                    borderRadius: BorderRadius.circular(ShiftCell.radius),
                    child: _empty && !targeted && !widget.isToday
                        ? CustomPaint(
                            painter: _DashedBorderPainter(
                              color: _hovered
                                  ? AppColors.textTertiary
                                  : AppColors.darkBorder,
                              radius: ShiftCell.radius,
                            ),
                            child: _emptyBody(targeted),
                          )
                        : AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            curve: Curves.easeOut,
                            decoration: BoxDecoration(
                              color: _todayTint(targeted
                                  ? AppColors.darkSurfaceElevated
                                  : _empty
                                      ? AppColors.darkBg
                                      : AppColors.darkSurface),
                              borderRadius:
                                  BorderRadius.circular(ShiftCell.radius),
                              border: Border.all(
                                color: targeted
                                    ? AppColors.primary
                                    : widget.isToday
                                        ? AppColors.primary.withAlpha(160)
                                        : _hovered
                                            ? AppColors.accentBorder
                                            : AppColors.darkBorder,
                                width: targeted || widget.isToday ? 1.4 : 1,
                              ),
                            ),
                            child: _empty
                                ? _emptyBody(targeted)
                                : _chips(targeted),
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// The print-clean cell: no dashes, hover, icons or collapsing — an empty
  /// slot is a bare em-dash, a staffed one lists everyone (Final View).
  Widget _presentationBody() {
    if (_empty) {
      return Container(
        decoration: BoxDecoration(
          color: _todayTint(Colors.transparent),
          borderRadius: BorderRadius.circular(ShiftCell.radius),
          border: Border.all(
            color: widget.isToday
                ? AppColors.primary.withAlpha(160)
                : AppColors.darkBorder.withAlpha(120),
            width: widget.isToday ? 1.4 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '—',
          style: AppTypography.caption.copyWith(
            color: AppColors.textTertiary.withAlpha(140),
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: _todayTint(AppColors.darkSurface),
        borderRadius: BorderRadius.circular(ShiftCell.radius),
        border: Border.all(
          color: widget.isToday
              ? AppColors.primary.withAlpha(160)
              : AppColors.darkBorder,
          width: widget.isToday ? 1.4 : 1,
        ),
      ),
      child: _chips(false),
    );
  }

  /// Composes the soft warning behind a chip's amber dot; red double-booking
  /// outranks it (handled by the chip itself).
  String? _cautionFor(String uid) {
    final onLeave = widget.leaveClashUids.contains(uid);
    final tired = widget.shortRestUids.contains(uid);
    if (onLeave && tired) {
      return 'Marked on leave today · short rest after last night';
    }
    if (onLeave) return 'Assigned while marked on leave today';
    if (tired) return 'Short rest — worked last night';
    return null;
  }

  Widget _chips(bool targeted) {
    // ≤ maxChips+1 people all fit — collapsing one person into "+1 more"
    // would cost the same space it saves. Beyond that, show the first
    // maxChips and roll the rest into the pill. Presentation shows everyone —
    // a printed roster must name every person.
    final collapse = !widget.presentation &&
        widget.users.length > ShiftCell.maxChips + 1;
    final visible = collapse
        ? widget.users.take(ShiftCell.maxChips).toList()
        : widget.users;
    final extra = widget.users.length - visible.length;
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(7),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final user in visible)
                AssignmentChip(
                  // Keyed by uid so a person who stays put keeps their element
                  // (no re-animation on rebuild); a newly-placed person mounts
                  // fresh and plays the entrance.
                  key: ValueKey('chip-${user.uid}'),
                  user: user,
                  day: widget.day,
                  shift: widget.shift,
                  canEdit: widget.canEdit,
                  presentation: widget.presentation,
                  conflicted: widget.conflictedUids.contains(user.uid),
                  cautionNote: _cautionFor(user.uid),
                  canMoveToOpposite: !widget.oppositeUids.contains(user.uid),
                  onRemove: () => widget.onRemoveUid?.call(user.uid),
                  onMoveToOpposite: () =>
                      widget.onMoveUidToOpposite?.call(user.uid),
                  onSwapDrop: widget.onSwapChip == null
                      ? null
                      : (data) => widget.onSwapChip!(data, user.uid),
                  onOpenActions: widget.onChipActions == null
                      ? null
                      : () => widget.onChipActions!(user.uid),
                  onSwapWith: widget.onChipSwapWith == null
                      ? null
                      : () => widget.onChipSwapWith!(user.uid),
                  onKeyboardMove: widget.onChipKeyboardMove == null
                      ? null
                      : (toDay, toShift) =>
                          widget.onChipKeyboardMove!(user.uid, toDay, toShift),
                ),
              if (extra > 0)
                // Tappable overflow pill → the full shift panel, where every
                // person is listed with their actions.
                GestureDetector(
                  onTap: widget.onTap,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _hovered
                          ? AppColors.darkSurfaceElevated
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                          color: _hovered
                              ? AppColors.accentBorder
                              : AppColors.darkBorder),
                    ),
                    child: Text(
                      '+$extra more',
                      style: AppTypography.caption.copyWith(
                        color: _hovered
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              // Quiet inline add affordance on hover (desktop) — one click
              // fewer than going through the cell sheet's Assign button.
              // Hidden once the cell is at chip capacity (4 rows max).
              if (widget.canEdit &&
                  !widget.presentation &&
                  _hovered &&
                  extra == 0 &&
                  widget.users.length <= ShiftCell.maxChips)
                GestureDetector(
                  onTap: widget.onTap,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: AppColors.darkBorder),
                    ),
                    child: Text(
                      '+',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (widget.hasOrphan && !widget.presentation)
          const Positioned(
            top: 6,
            right: 6,
            child: Icon(Icons.warning_amber_rounded,
                size: 13, color: AppColors.warning),
          ),
        // Staffing at a glance: a quiet corner count (the day's "Morning: 3"
        // without a single extra pixel of chrome). Soft backdrop so it stays
        // legible if a chip row runs underneath.
        Positioned(
          bottom: 4,
          right: 6,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.darkBg.withAlpha(170),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${widget.users.length}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyBody(bool targeted) {
    // An open slot is a fact, not a fault — a small "Open" beats the old
    // oversized icon + "No one" placeholder (items: open-shift visibility,
    // better empty states).
    return Center(
      child: targeted
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.download_rounded,
                    size: 18, color: AppColors.primary),
                const SizedBox(height: 4),
                Text(
                  'Drop here',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            )
          : Text(
              widget.canEdit && _hovered ? '+ Assign' : 'Open',
              style: AppTypography.caption.copyWith(
                color: widget.canEdit && _hovered
                    ? AppColors.textSecondary
                    : AppColors.textTertiary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
    );
  }
}

/// Draws a rounded-rect **dashed** outline — the premium "empty slot" cue, so an
/// unstaffed shift reads as an open placeholder rather than a filled card.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const double _dash = 5;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final next = dist + _dash;
        canvas.drawPath(
          metric.extractPath(dist, next.clamp(0, metric.length)),
          paint,
        );
        dist = next + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
