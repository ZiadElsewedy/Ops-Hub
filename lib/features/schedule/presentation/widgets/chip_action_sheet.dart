import 'package:flutter/material.dart';
import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/user_avatar.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:opshub/features/schedule/domain/move_validation.dart';
import 'package:opshub/features/schedule/domain/swap_policy.dart';
import 'package:opshub/features/schedule/presentation/widgets/employee_row.dart';
import 'package:opshub/features/schedule/presentation/widgets/schedule_helpers.dart';
import 'package:opshub/features/schedule/presentation/widgets/sheet_chrome.dart';

/// Premium mobile actions for one person on one shift (Schedule 4.0): long-
/// pressing an [AssignmentChip] on touch opens this sheet — Move (pick a new
/// slot on a mini week map) · Switch (pick a coworker's slot → preview the
/// trade → confirm) · Remove. Every invalid choice is disabled **with its
/// reason shown**, never silently rejected. The sheet only *selects*; the
/// mutations run through the callbacks so the host view owns validation-at-
/// commit, empty-shift confirms, and the undo snackbar.
///
/// Desktop uses the same sheet for its context-menu "Switch shifts with…"
/// entry ([startAtSwap]) — one flow, no drift between platforms.
Future<void> showChipActionSheet({
  required BuildContext context,
  required WeeklyScheduleEntity schedule,
  required List<UserEntity> members,
  required UserEntity user,
  required ScheduleDay day,
  required ScheduleShift shift,
  SwapPolicy policy = SwapPolicy.permissive,
  bool startAtSwap = false,
  required void Function(ScheduleDay toDay, ScheduleShift toShift) onMove,
  required void Function(
          String withUid, ScheduleDay withDay, ScheduleShift withShift)
      onExchange,
  required VoidCallback onRemove,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.darkSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ChipActionSheet(
      schedule: schedule,
      members: members,
      user: user,
      day: day,
      shift: shift,
      policy: policy,
      startAtSwap: startAtSwap,
      onMove: onMove,
      onExchange: onExchange,
      onRemove: onRemove,
    ),
  );
}

enum _Step { actions, movePick, swapPick, swapPreview }

class _ChipActionSheet extends StatefulWidget {
  const _ChipActionSheet({
    required this.schedule,
    required this.members,
    required this.user,
    required this.day,
    required this.shift,
    required this.policy,
    required this.startAtSwap,
    required this.onMove,
    required this.onExchange,
    required this.onRemove,
  });

  final WeeklyScheduleEntity schedule;
  final List<UserEntity> members;
  final UserEntity user;
  final ScheduleDay day;
  final ScheduleShift shift;
  final SwapPolicy policy;
  final bool startAtSwap;
  final void Function(ScheduleDay, ScheduleShift) onMove;
  final void Function(String, ScheduleDay, ScheduleShift) onExchange;
  final VoidCallback onRemove;

  @override
  State<_ChipActionSheet> createState() => _ChipActionSheetState();
}

class _ChipActionSheetState extends State<_ChipActionSheet> {
  late _Step _step = widget.startAtSwap ? _Step.swapPick : _Step.actions;

  /// Reason shown inline when the user taps a disabled/invalid choice.
  String? _blockedReason;

  /// The chosen counterpart for the swap preview step.
  UserEntity? _target;
  ScheduleDay? _targetDay;
  ScheduleShift? _targetShift;

  String get _name => shortName(widget.user);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.md,
        AppSpacing.pagePadding,
        MediaQuery.of(context).padding.bottom + AppSpacing.lg,
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const SizedBox(height: AppSpacing.md),
            _header(),
            const SizedBox(height: AppSpacing.lg),
            switch (_step) {
              _Step.actions => _actions(),
              _Step.movePick => _movePicker(),
              _Step.swapPick => _swapPicker(),
              _Step.swapPreview => _swapPreview(),
            },
            if (_blockedReason != null) ...[
              const SizedBox(height: AppSpacing.md),
              _reasonNote(_blockedReason!),
            ],
          ],
        ),
      ),
    );
  }

  // ── Header (person + slot, back affordance on sub-steps) ─────────
  Widget _header() {
    final subtitle = switch (_step) {
      _Step.actions => '${widget.day.label} · ${widget.shift.label} Shift',
      _Step.movePick => 'Pick the new shift',
      _Step.swapPick => 'Pick who to switch with',
      _Step.swapPreview => 'Review the switch',
    };
    final showBack = _step != _Step.actions && !widget.startAtSwap ||
        _step == _Step.swapPreview;
    return Row(
      children: [
        if (showBack) ...[
          InkWell(
            onTap: () => setState(() {
              _blockedReason = null;
              _step = _step == _Step.swapPreview ? _Step.swapPick : _Step.actions;
            }),
            borderRadius: BorderRadius.circular(99),
            child: Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: AppColors.darkSurfaceElevated,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  size: 18, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
        UserAvatar.fromUser(widget.user, size: 40),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(userDisplayName(widget.user), style: AppTypography.h3),
              const SizedBox(height: 1),
              Text(subtitle, style: AppTypography.caption),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step 1: actions ──────────────────────────────────────────────
  Widget _actions() {
    return Column(
      children: [
        _actionRow(
          icon: Icons.drive_file_move_outlined,
          label: 'Move to another shift',
          hint: 'Reassign $_name to a different day or shift',
          onTap: () => setState(() {
            _blockedReason = null;
            _step = _Step.movePick;
          }),
        ),
        _actionRow(
          icon: Icons.swap_horiz_rounded,
          label: 'Switch shifts with…',
          hint: 'Trade this shift with a coworker\'s',
          onTap: () => setState(() {
            _blockedReason = null;
            _step = _Step.swapPick;
          }),
        ),
        _actionRow(
          icon: Icons.person_remove_outlined,
          label: 'Remove from this shift',
          hint: '${widget.day.label} ${widget.shift.label.toLowerCase()} only',
          destructive: true,
          onTap: () {
            Navigator.of(context).pop();
            widget.onRemove();
          },
        ),
      ],
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String label,
    required String hint,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    final color = destructive ? AppColors.error : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgAll,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.darkBg,
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: AppColors.darkSurfaceElevated,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: AppTypography.label.copyWith(color: color)),
                    const SizedBox(height: 1),
                    Text(hint, style: AppTypography.caption),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  // ── Step 2a: move — mini week map ────────────────────────────────
  Widget _movePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final d in ScheduleDay.values)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    d.shortLabel,
                    style: AppTypography.labelSmall.copyWith(
                      color: d == widget.day
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                for (final s in ScheduleShift.values) ...[
                  Expanded(child: _slotButton(d, s)),
                  if (s != ScheduleShift.values.last)
                    const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _slotButton(ScheduleDay d, ScheduleShift s) {
    final isCurrent = d == widget.day && s == widget.shift;
    final reason = isCurrent
        ? null
        : MoveValidation.checkMove(
            schedule: widget.schedule,
            uid: widget.user.uid,
            name: _name,
            fromDay: widget.day,
            fromShift: widget.shift,
            toDay: d,
            toShift: s,
          );
    final enabled = !isCurrent && reason == null;
    return InkWell(
      onTap: () {
        if (isCurrent) return;
        if (reason != null) {
          setState(() => _blockedReason = reason);
          return;
        }
        Navigator.of(context).pop();
        widget.onMove(d, s);
      },
      borderRadius: AppRadius.mdAll,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isCurrent ? AppColors.darkSurfaceElevated : AppColors.darkBg,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: isCurrent ? AppColors.accentBorder : AppColors.darkBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              s == ScheduleShift.morning
                  ? Icons.wb_sunny_outlined
                  : Icons.nightlight_outlined,
              size: 13,
              color: enabled || isCurrent
                  ? AppColors.textSecondary
                  : AppColors.textTertiary.withAlpha(120),
            ),
            const SizedBox(width: 5),
            Text(
              isCurrent ? 'Current' : s.label,
              style: AppTypography.caption.copyWith(
                color: isCurrent
                    ? AppColors.textPrimary
                    : enabled
                        ? AppColors.textSecondary
                        : AppColors.textTertiary.withAlpha(120),
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 2b: switch — coworker slot list ─────────────────────────
  /// One row per (person, slot) assignment across the week — a person holding
  /// two shifts appears twice, so the trade is always unambiguous.
  List<(UserEntity, ScheduleDay, ScheduleShift)> _swapCandidates() {
    final rows = <(UserEntity, ScheduleDay, ScheduleShift)>[];
    for (final d in ScheduleDay.values) {
      for (final s in ScheduleShift.values) {
        if (d == widget.day && s == widget.shift) continue;
        for (final uid in widget.schedule.employeesFor(d, s)) {
          if (uid == widget.user.uid) continue;
          final u = userForUid(uid, widget.members);
          if (u != null) rows.add((u, d, s));
        }
      }
    }
    return rows;
  }

  Widget _swapPicker() {
    final candidates = _swapCandidates();
    if (candidates.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Text(
          'No other assigned shifts this week to switch with.',
          style: AppTypography.bodySmall,
        ),
      );
    }
    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: candidates.length,
        itemBuilder: (context, i) {
          final (u, d, s) = candidates[i];
          final reason = MoveValidation.checkExchange(
            schedule: widget.schedule,
            uidA: widget.user.uid,
            nameA: _name,
            dayA: widget.day,
            shiftA: widget.shift,
            uidB: u.uid,
            nameB: shortName(u),
            dayB: d,
            shiftB: s,
            positionA: widget.user.position,
            positionB: u.position,
            policy: widget.policy,
          );
          return Opacity(
            opacity: reason == null ? 1 : 0.5,
            child: EmployeeRow(
              user: u,
              subtitle: '${d.label} · ${s.label} Shift',
              onTap: () {
                if (reason != null) {
                  setState(() => _blockedReason = reason);
                  return;
                }
                setState(() {
                  _blockedReason = null;
                  _target = u;
                  _targetDay = d;
                  _targetShift = s;
                  _step = _Step.swapPreview;
                });
              },
              trailing: Icon(
                reason == null
                    ? Icons.swap_horiz_rounded
                    : Icons.block_rounded,
                size: 18,
                color: reason == null
                    ? AppColors.textSecondary
                    : AppColors.textTertiary,
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Step 3: switch preview + confirm ─────────────────────────────
  Widget _swapPreview() {
    final target = _target!;
    final tDay = _targetDay!;
    final tShift = _targetShift!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _previewRow(widget.user, widget.day, widget.shift, tDay, tShift),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Center(
            child: Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: AppColors.darkSurfaceElevated,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.swap_vert_rounded,
                  size: 16, color: AppColors.textPrimary),
            ),
          ),
        ),
        _previewRow(target, tDay, tShift, widget.day, widget.shift),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onExchange(target.uid, tDay, tShift);
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.buttonAll),
          ),
          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
          label: Text('Switch $_name ⇄ ${shortName(target)}'),
        ),
      ],
    );
  }

  Widget _previewRow(
    UserEntity u,
    ScheduleDay fromDay,
    ScheduleShift fromShift,
    ScheduleDay toDay,
    ScheduleShift toShift,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          UserAvatar.fromUser(u, size: 34),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(userDisplayName(u), style: AppTypography.label),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text('${fromDay.shortLabel} ${fromShift.label}',
                        style: AppTypography.caption.copyWith(
                          decoration: TextDecoration.lineThrough,
                          color: AppColors.textTertiary,
                        )),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.arrow_forward_rounded,
                          size: 11, color: AppColors.textTertiary),
                    ),
                    Text('${toDay.shortLabel} ${toShift.label}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        )),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Inline blocked-reason note ───────────────────────────────────
  Widget _reasonNote(String reason) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warning.withAlpha(18),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.warning.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 15, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              reason,
              style:
                  AppTypography.caption.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
