import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/responsive/breakpoints.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/app_context_menu.dart';
import 'package:opshub/core/widgets/user_avatar.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/schedule/presentation/widgets/schedule_helpers.dart';

/// Payload carried while dragging an [AssignmentChip] between grid cells:
/// who is being moved and which slot they came from.
class ChipDragData {
  const ChipDragData({
    required this.uid,
    required this.day,
    required this.shift,
  });

  final String uid;
  final ScheduleDay day;
  final ScheduleShift shift;
}

/// One person on a shift — the atomic unit of the schedule grid. Each chip is
/// a click target (cell details), a drag handle (desktop: move between slots),
/// a context-menu anchor (right-click on desktop, long-press on touch), and —
/// when [onSwapDrop] is set — a **drop target**: dropping another person onto
/// this chip trades their slots (drag Ziad onto Richard → they switch shifts).
/// A double-booked person carries a red hairline + dot; strictly monochrome
/// otherwise.
class AssignmentChip extends StatefulWidget {
  const AssignmentChip({
    super.key,
    required this.user,
    required this.day,
    required this.shift,
    this.conflicted = false,
    this.cautionNote,
    this.presentation = false,
    this.canEdit = false,
    this.canMoveToOpposite = true,
    this.onRemove,
    this.onMoveToOpposite,
    this.onSwapDrop,
    this.onOpenActions,
    this.onSwapWith,
    this.onKeyboardMove,
  });

  final UserEntity user;
  final ScheduleDay day;
  final ScheduleShift shift;

  /// This person is on both shifts of this day (double-booked).
  final bool conflicted;

  /// A soft wellbeing/availability warning for this assignment (e.g. "Short
  /// rest — worked last night", "Marked on leave today"): amber dot +
  /// tooltip. A red [conflicted] cue outranks it.
  final String? cautionNote;

  /// Read-only print/export rendering: the bare chip visual with no hover,
  /// drag, menus or tooltips (Final View, Schedule 5.0).
  final bool presentation;

  final bool canEdit;

  /// False when the opposite shift already contains this person — the move
  /// action shows disabled instead of silently double-booking them.
  final bool canMoveToOpposite;

  final VoidCallback? onRemove;
  final VoidCallback? onMoveToOpposite;

  /// Another chip was dropped onto this one (desktop): trade the two slots.
  /// The payload is the dragged person; this chip's (user, day, shift) is the
  /// other side of the exchange.
  final void Function(ChipDragData data)? onSwapDrop;

  /// Touch long-press → the premium action sheet (move · switch · remove).
  /// When set, it replaces the bare context menu on mobile (Schedule 4.0).
  final VoidCallback? onOpenActions;

  /// Desktop context-menu "Switch shifts with…" — the guided switch flow for
  /// people who don't discover chip-onto-chip drag.
  final VoidCallback? onSwapWith;

  /// Desktop keyboard move: the focused chip received an arrow key and should
  /// move this person into the adjacent slot [toDay]/[toShift]. Routed through
  /// the exact same validated move path drag uses — no new write path.
  final void Function(ScheduleDay toDay, ScheduleShift toShift)? onKeyboardMove;

  @override
  State<AssignmentChip> createState() => _AssignmentChipState();
}

class _AssignmentChipState extends State<AssignmentChip> {
  bool _hovered = false;
  bool _focused = false;

  /// Arrow keys move the focused person into the adjacent slot, reusing the
  /// exact validated move path drag uses (via [AssignmentChip.onKeyboardMove]).
  /// Left/Right hop days on the same shift; Up/Down flip Morning↔Night on the
  /// same day. An edge (no such slot) quietly consumes the key with no move.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (widget.onKeyboardMove == null || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final days = ScheduleDay.values;
    final idx = widget.day.index;
    ScheduleDay? toDay;
    ScheduleShift? toShift;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.arrowLeft) {
      if (idx > 0) {
        toDay = days[idx - 1];
        toShift = widget.shift;
      }
    } else if (k == LogicalKeyboardKey.arrowRight) {
      if (idx < days.length - 1) {
        toDay = days[idx + 1];
        toShift = widget.shift;
      }
    } else if (k == LogicalKeyboardKey.arrowUp) {
      if (widget.shift == ScheduleShift.night) {
        toDay = widget.day;
        toShift = ScheduleShift.morning;
      }
    } else if (k == LogicalKeyboardKey.arrowDown) {
      if (widget.shift == ScheduleShift.morning) {
        toDay = widget.day;
        toShift = ScheduleShift.night;
      }
    } else {
      return KeyEventResult.ignored;
    }
    if (toDay != null && toShift != null) {
      widget.onKeyboardMove!(toDay, toShift);
    }
    // Consume the arrow either way so it never doubles as scroll / focus-move.
    return KeyEventResult.handled;
  }

  /// A one-shot scale-in when this chip first mounts — i.e. when a person lands
  /// in a slot (chips are keyed by uid, so a person who merely stays put keeps
  /// their element and never re-animates). Scale only (no opacity) so the chip
  /// is always hit-testable mid-animation. Honours "reduce motion".
  Widget _entrance(Widget child) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      builder: (context, t, child) =>
          Transform.scale(scale: 0.9 + 0.1 * t, child: child),
      child: child,
    );
  }

  void _showMenu(Offset globalPosition) {
    final opposite = widget.shift.opposite;
    showAppContextMenu(
      context: context,
      position: globalPosition,
      items: [
        AppContextMenuItem(
          icon: opposite == ScheduleShift.morning
              ? Icons.wb_sunny_rounded
              : Icons.nightlight_round,
          label: 'Move to ${opposite.label.toLowerCase()}',
          enabled: widget.canMoveToOpposite,
          onSelected: widget.onMoveToOpposite,
        ),
        if (widget.onSwapWith != null)
          AppContextMenuItem(
            icon: Icons.swap_horiz_rounded,
            label: 'Switch shifts with…',
            onSelected: widget.onSwapWith,
          ),
        AppContextMenuItem(
          icon: Icons.person_remove_outlined,
          label: 'Remove from shift',
          destructive: true,
          onSelected: widget.onRemove,
        ),
      ],
    );
  }

  Widget _visual({
    required bool hovered,
    bool dragging = false,
    bool swapTarget = false,
    bool focused = false,
  }) {
    final position = widget.user.position?.trim();
    final hasPosition = position != null && position.isNotEmpty;
    final lifted = hovered || dragging || swapTarget || focused;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      // Roomier than before → a larger, easier-to-grab drag / tap target.
      padding: const EdgeInsets.fromLTRB(3, 4, 10, 4),
      decoration: BoxDecoration(
        color: lifted ? const Color(0xFF232327) : AppColors.darkSurfaceElevated,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: swapTarget
              ? AppColors.primary
              : widget.conflicted
                  ? AppColors.error.withAlpha(190)
                  : focused
                      ? AppColors.primary
                      : hovered
                          ? AppColors.accentBorder
                          : AppColors.darkBorder,
          width: swapTarget || focused ? 1.4 : 1,
        ),
        boxShadow: dragging
            ? [
                BoxShadow(
                  color: AppColors.black.withAlpha(120),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ]
            : (hovered || focused)
                // A whisper of lift on hover / keyboard focus — premium, quiet.
                ? [
                    BoxShadow(
                      color: AppColors.black.withAlpha(60),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          UserAvatar.fromUser(widget.user, size: 18),
          const SizedBox(width: 6),
          Flexible(
            // Name leads; the position (e.g. "Cashier") trails in a quieter
            // tone and is the first thing to ellipsize when space is tight, so
            // the chip stays ONE line and never outgrows the grid cell.
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: shortName(widget.user),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                  if (hasPosition)
                    TextSpan(
                      text: '  $position',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w500,
                        height: 1,
                      ),
                    ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Hovering a dragged person over this chip → "drop to switch" cue.
          if (swapTarget) ...[
            const SizedBox(width: 5),
            const Icon(Icons.swap_horiz_rounded,
                size: 12, color: AppColors.primary),
          ] else if (widget.conflicted) ...[
            const SizedBox(width: 5),
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
            ),
          ] else if (widget.cautionNote != null) ...[
            const SizedBox(width: 5),
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: AppColors.warning,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Print/export: the plain visual, nothing interactive layered on.
    if (widget.presentation) return _visual(hovered: false);

    final isDesktop = context.isDesktop;

    Widget content({bool swapTarget = false}) => MouseRegion(
          cursor: widget.canEdit && isDesktop
              ? SystemMouseCursors.grab
              : MouseCursor.defer,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onSecondaryTapDown:
                widget.canEdit ? (d) => _showMenu(d.globalPosition) : null,
            // Touch: long-press opens the premium action sheet (move · switch
            // · remove, Schedule 4.0); the bare context menu remains only as
            // a fallback when no sheet callback is wired.
            onLongPressStart: widget.canEdit && !isDesktop
                ? (d) => widget.onOpenActions != null
                    ? widget.onOpenActions!()
                    : _showMenu(d.globalPosition)
                : null,
            child: _visual(
              hovered: _hovered,
              swapTarget: swapTarget,
              focused: _focused,
            ),
          ),
        );

    Widget chip = content();

    // Person-onto-person drop = trade slots. The chip target sits INSIDE the
    // cell's DragTarget, so it wins the hit test when hovered directly; the
    // cell's empty space still means "move here".
    if (widget.canEdit && isDesktop && widget.onSwapDrop != null) {
      chip = DragTarget<ChipDragData>(
        onWillAcceptWithDetails: (d) =>
            d.data.uid != widget.user.uid &&
            // Trading places inside the SAME slot changes nothing — reject so
            // the drop doesn't pretend to do something.
            !(d.data.day == widget.day && d.data.shift == widget.shift),
        onAcceptWithDetails: (d) => widget.onSwapDrop!(d.data),
        builder: (context, candidates, _) =>
            content(swapTarget: candidates.isNotEmpty),
      );
    }

    // Desktop hover reveals the full name + position (the chip shows a short
    // name); a soft caution is appended. Touch is left EXACTLY as it was — a
    // caution-only tooltip — so long-press still belongs to the action sheet.
    if (isDesktop) {
      final position = widget.user.position?.trim();
      final tip = [
        (position != null && position.isNotEmpty)
            ? '${userDisplayName(widget.user)} · $position'
            : userDisplayName(widget.user),
        if (widget.cautionNote != null && !widget.conflicted)
          widget.cautionNote!,
      ].join('\n');
      chip = Tooltip(
        message: tip,
        waitDuration: const Duration(milliseconds: 400),
        child: chip,
      );
    } else if (widget.cautionNote != null && !widget.conflicted) {
      chip = Tooltip(
        message: widget.cautionNote!,
        waitDuration: const Duration(milliseconds: 400),
        child: chip,
      );
    }

    // Drag-to-move is a desktop affordance; on touch the cell sheet handles
    // assignment, so chips stay plain tappable content there.
    if (widget.canEdit && isDesktop) {
      chip = Draggable<ChipDragData>(
        data: ChipDragData(
            uid: widget.user.uid, day: widget.day, shift: widget.shift),
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: Material(
          color: Colors.transparent,
          child: Transform.scale(
            scale: 1.06,
            child: _visual(hovered: false, dragging: true),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: chip),
        child: chip,
      );
    }

    // Keyboard move: Tab focuses the chip, arrows move the person (desktop).
    if (widget.canEdit && isDesktop && widget.onKeyboardMove != null) {
      chip = Focus(
        onFocusChange: (f) => setState(() => _focused = f),
        onKeyEvent: _onKey,
        child: chip,
      );
    }

    return _entrance(chip);
  }
}
