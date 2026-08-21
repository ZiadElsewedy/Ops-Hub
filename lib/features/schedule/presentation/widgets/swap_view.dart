import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/enums/swap_status.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/app_error_state.dart';
import 'package:opshub/core/widgets/app_glass_card.dart';
import 'package:opshub/core/widgets/app_snackbar.dart';
import 'package:opshub/core/widgets/branch_avatar.dart';
import 'package:opshub/core/widgets/opshub_empty_state.dart';
import 'package:opshub/core/widgets/premium_button.dart';
import 'package:opshub/core/widgets/user_avatar.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/auth/presentation/widgets/app_button.dart';
import 'package:opshub/features/auth/presentation/widgets/app_text_field.dart';
import 'package:opshub/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:opshub/features/branch/presentation/cubit/branch_state.dart';
import 'package:opshub/features/schedule/domain/entities/shift_swap_entity.dart';
import 'package:opshub/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:opshub/features/schedule/domain/swap_eligibility.dart';
import 'package:opshub/features/schedule/domain/swap_policy.dart';
import 'package:opshub/features/schedule/domain/swap_validation.dart';
import 'package:opshub/features/schedule/presentation/cubit/shift_swap_cubit.dart';
import 'package:opshub/features/schedule/presentation/cubit/shift_swap_state.dart';
import 'package:opshub/features/schedule/presentation/widgets/schedule_helpers.dart';
import 'package:opshub/core/widgets/list_skeleton.dart';

/// The semantic accent for a swap status (subtle status glow + chip colour).
/// Strictly monochrome elsewhere — only the status signal is tinted.
Color _swapAccent(SwapStatus status) => switch (status) {
  SwapStatus.pending => AppColors.warning,
  SwapStatus.employeeApproved => AppColors.warning,
  SwapStatus.managerApproved => AppColors.success,
  SwapStatus.rejected => AppColors.error,
  SwapStatus.cancelled => AppColors.textTertiary,
};

/// The card glow for a swap status — null (monochrome) for a settled/cancelled
/// request, a soft accent halo while in-flight or freshly approved/rejected.
Color? _swapGlow(SwapStatus status) =>
    status == SwapStatus.cancelled ? null : _swapAccent(status);

/// List of shift-swap requests with role-appropriate actions (Phase 7). Used on
/// the employee "Swaps" tab ([isManager] = false) and the manager "Swap
/// Requests" tab ([isManager] = true). Reads [ShiftSwapCubit] from context.
///
/// ⚠️ **A failed decision is reported INSIDE this list, never only as a
/// snackbar.** The manager/admin queue is opened as a modal bottom sheet
/// ([showSwapQueueSheet]), and a `ScaffoldMessenger` snackbar renders in the
/// page `Scaffold` *underneath* that sheet — so a refused approval (the server
/// re-validates the roster and rejects a swap whose slot has since moved) was
/// completely invisible: the button appeared to do nothing, which is exactly
/// the "sometimes it approves, sometimes it doesn't" report.
class SwapListView extends StatefulWidget {
  const SwapListView({
    super.key,
    required this.isManager,
    required this.currentUid,
    this.showBranch = false,
  });

  final bool isManager;
  final String currentUid;

  /// Show each swap's branch (admin views span multiple branches). Resolved via
  /// [BranchCubit]; the manager view leaves this off (single, known branch).
  final bool showBranch;

  @override
  State<SwapListView> createState() => _SwapListViewState();
}

class _SwapListViewState extends State<SwapListView> {
  /// The last refused decision, held until the user dismisses it or starts
  /// another action. [ShiftSwapState.error] is transient (the cubit re-emits the
  /// list immediately after), so the message has to be kept here to stay
  /// readable.
  String? _actionError;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ShiftSwapCubit, ShiftSwapState>(
      listener: (context, state) {
        state.whenOrNull(error: (m) => setState(() => _actionError = m));
        // A new attempt (or a re-subscribe) clears the previous verdict — but
        // the settled `loaded` that FOLLOWS a refusal must not, or the message
        // would be wiped in the same frame it arrived.
        final retrying = state.maybeWhen(
          loading: () => true,
          loaded: (_, busy) => busy,
          orElse: () => false,
        );
        if (retrying && _actionError != null) {
          setState(() => _actionError = null);
        }
      },
      builder: (context, state) => state.maybeWhen(
        loading: () => const ListSkeleton(count: 3, cardHeight: 120),
        loaded: (swaps, busy) => _list(context, swaps, busy),
        // A stream failure used to render nothing at all here — a blank sheet
        // with its only explanation hidden behind it.
        error: (message) => AppErrorState(
          message: message,
          title: 'Swap requests unavailable',
          onRetry: () => context.read<ShiftSwapCubit>().refresh(),
        ),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }

  Widget _list(BuildContext context, List<ShiftSwapEntity> swaps, bool busy) {
    final error = _actionError;
    return Column(
      children: [
        if (busy) const LinearProgressIndicator(minHeight: 2),
        if (error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pagePadding,
              AppSpacing.md,
              AppSpacing.pagePadding,
              0,
            ),
            child: _SwapActionError(
              message: error,
              onDismiss: () => setState(() => _actionError = null),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => context.read<ShiftSwapCubit>().refresh(),
            child: swaps.isEmpty
                ? OpsHubEmptyState(
                    title: 'No swap requests',
                    message: widget.isManager
                        ? 'When a coworker accepts a teammate’s swap, it’ll '
                              'arrive here for your approval.'
                        : 'Tap a shift on your week to request a swap with a '
                              'coworker on the opposite shift.',
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pagePadding,
                      AppSpacing.lg,
                      AppSpacing.pagePadding,
                      AppSpacing.xxxl,
                    ),
                    children: [
                      if (swaps.any((s) => !s.status.isResolved)) ...[
                        const _SwapSectionTitle('Needs attention'),
                        for (final s in swaps.where(
                          (s) => !s.status.isResolved,
                        ))
                          _SwapCard(
                            swap: s,
                            isManager: widget.isManager,
                            currentUid: widget.currentUid,
                            showBranch: widget.showBranch,
                          ),
                      ],
                      if (swaps.any((s) => s.status.isResolved)) ...[
                        const _SwapSectionTitle('History'),
                        for (final s in swaps.where((s) => s.status.isResolved))
                          _SwapCard(
                            swap: s,
                            isManager: widget.isManager,
                            currentUid: widget.currentUid,
                            showBranch: widget.showBranch,
                          ),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _SwapCard extends StatelessWidget {
  const _SwapCard({
    required this.swap,
    required this.isManager,
    required this.currentUid,
    this.showBranch = false,
  });

  final ShiftSwapEntity swap;
  final bool isManager;
  final String currentUid;
  final bool showBranch;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ShiftSwapCubit>();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AppGlassCard(
        glow: _swapGlow(swap.status),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header — day context + status chip.
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${swap.day.label} swap',
                    style: AppTypography.label,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _SwapStatusChip(status: swap.status),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // The exchange — who trades which shift (requester ⇄ target).
            _ExchangeRow(
              requesterName: swap.requesterName ?? 'Employee',
              requesterShift: swap.shift,
              targetName: swap.targetName ?? 'Coworker',
              targetShift: swap.shift.opposite,
            ),

            if (showBranch) ...[
              const SizedBox(height: AppSpacing.md),
              _BranchLine(branchId: swap.branchId),
            ],
            if ((swap.note ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _NoteLine(note: swap.note!),
            ],
            if (swap.status == SwapStatus.managerApproved) ...[
              const SizedBox(height: AppSpacing.sm),
              _ApprovalLine(
                name: swap.managerApprovedByName,
                approvedAt: swap.managerApprovedAt,
              ),
            ],

            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1, color: AppColors.darkBorder),
            const SizedBox(height: AppSpacing.sm),

            // The timestamp lives above the rail so all three steps retain
            // equal width and the progress line stays visually centred.
            _SwapProgressPanel(status: swap.status, createdAt: swap.createdAt),

            ..._actions(context, cubit),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(BuildContext context, ShiftSwapCubit cubit) {
    final buttons = <Widget>[];
    if (isManager) {
      // Manager acts once the coworker has approved.
      if (swap.status.isEmployeeApproved) {
        buttons.add(
          _SwapButton(
            label: 'Approve swap',
            icon: Icons.check_circle_outline_rounded,
            style: PremiumButtonStyle.filled,
            onPressed: () => cubit.managerApprove(swap),
          ),
        );
        buttons.add(
          _SwapButton(
            label: 'Reject',
            icon: Icons.cancel_outlined,
            color: AppColors.error,
            onPressed: () => cubit.reject(swap, actorId: currentUid),
          ),
        );
      }
    } else {
      final isTarget = swap.targetId == currentUid;
      final isRequester = swap.requesterId == currentUid;
      if (isTarget && swap.status.isPending) {
        buttons.add(
          _SwapButton(
            label: 'Accept',
            icon: Icons.check_rounded,
            style: PremiumButtonStyle.filled,
            onPressed: () => cubit.coworkerApprove(swap),
          ),
        );
        buttons.add(
          _SwapButton(
            label: 'Decline',
            icon: Icons.close_rounded,
            color: AppColors.error,
            onPressed: () => cubit.reject(swap, actorId: currentUid),
          ),
        );
      } else if (isRequester && !swap.status.isResolved) {
        buttons.add(
          _SwapButton(
            label: 'Cancel request',
            icon: Icons.undo_rounded,
            color: AppColors.warning,
            onPressed: () => cubit.cancelSwap(swap),
          ),
        );
      }
    }
    if (buttons.isEmpty) return const [];
    return [
      const SizedBox(height: AppSpacing.md),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: buttons,
      ),
    ];
  }
}

class _SwapSectionTitle extends StatelessWidget {
  const _SwapSectionTitle(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(label, style: AppTypography.labelSmall),
  );
}

/// Why a decision was refused, stated where the decision was taken. The queue
/// is usually a modal sheet, and a snackbar renders behind it — see the note on
/// [SwapListView].
class _SwapActionError extends StatelessWidget {
  const _SwapActionError({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.error.withAlpha(28),
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.error.withAlpha(110)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppColors.error,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Not applied',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.textTertiary,
            ),
            visualDensity: VisualDensity.compact,
            tooltip: 'Dismiss',
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

/// Names the manager/admin who approved the exchange, with when they decided.
///
/// The attribution is written **only** by the server-authoritative `approveSwap`
/// Cloud Function, which stamps `managerApprovedById/Name/At` inside the same
/// transaction as the roster exchange — the client never forges it. Records
/// approved before that write existed carry no name, and this never invents one
/// for them; it says the approver was not recorded, so a blank line reads as the
/// data gap it is instead of a broken card.
class _ApprovalLine extends StatelessWidget {
  const _ApprovalLine({this.name, this.approvedAt});
  final String? name;
  final DateTime? approvedAt;

  @override
  Widget build(BuildContext context) {
    final approver = (name ?? '').trim();
    final recorded = approver.isNotEmpty;
    final time = approvedAt == null ? null : _relativeTime(approvedAt!);
    return Row(
      children: [
        Icon(
          recorded ? Icons.verified_rounded : Icons.help_outline_rounded,
          size: 15,
          color: recorded ? AppColors.success : AppColors.textTertiary,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            recorded ? 'Approved by $approver' : 'Approver not recorded',
            style: AppTypography.caption.copyWith(
              color: recorded
                  ? AppColors.textSecondary
                  : AppColors.textTertiary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (time != null) Text(time, style: AppTypography.caption),
      ],
    );
  }
}

/// The heart of a swap card: two parties trading shifts on the same day, with a
/// `⇄` between them. Reads "Ziad (Night) ⇄ Ahmed (Morning)" — an exchange, not a
/// one-way handover.
class _ExchangeRow extends StatelessWidget {
  const _ExchangeRow({
    required this.requesterName,
    required this.requesterShift,
    required this.targetName,
    required this.targetShift,
  });

  final String requesterName;
  final ScheduleShift requesterShift;
  final String targetName;
  final ScheduleShift targetShift;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _ExchangeParty(name: requesterName, shift: requesterShift),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: AppColors.darkSurfaceElevated,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.swap_horiz_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: _ExchangeParty(
            name: targetName,
            shift: targetShift,
            alignEnd: true,
          ),
        ),
      ],
    );
  }
}

class _ExchangeParty extends StatelessWidget {
  const _ExchangeParty({
    required this.name,
    required this.shift,
    this.alignEnd = false,
  });

  final String name;
  final ScheduleShift shift;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        UserAvatar(name: name, size: 38),
        const SizedBox(height: AppSpacing.xs),
        Text(
          name,
          style: AppTypography.labelSmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
        ),
        const SizedBox(height: 2),
        _ShiftPill(shift: shift),
      ],
    );
  }
}

/// A small monochrome pill naming a shift + its hours (brightness, not colour,
/// separates morning/night — matches the schedule grid language).
class _ShiftPill extends StatelessWidget {
  const _ShiftPill({required this.shift});
  final ScheduleShift shift;

  @override
  Widget build(BuildContext context) {
    final morning = shift == ScheduleShift.morning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            morning ? Icons.wb_sunny_rounded : Icons.nightlight_round,
            size: 11,
            color: morning ? AppColors.textPrimary : AppColors.textSecondary,
          ),
          const SizedBox(width: 5),
          Text(
            shift.label,
            style: AppTypography.caption.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// A restrained inset surface for the request's status and its centred progress
/// rail. Keeping its timestamp outside the rail prevents it from shifting the
/// three stages to the left on wide cards.
class _SwapProgressPanel extends StatelessWidget {
  const _SwapProgressPanel({required this.status, this.createdAt});

  final SwapStatus status;
  final DateTime? createdAt;

  @override
  Widget build(BuildContext context) {
    final accent = _swapAccent(status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.darkSurfaceElevated.withAlpha(190),
            AppColors.darkSurface.withAlpha(150),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: accent.withAlpha(52)),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withAlpha(28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'SWAP PROGRESS',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              if (createdAt != null)
                Text(
                  _relativeTime(createdAt!),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _SwapStatusTimeline(status: status),
        ],
      ),
    );
  }
}

/// Compact 3-step progress for an in-flight swap (Requested → Accepted →
/// Approved); a terminal banner for rejected / cancelled.
class _SwapStatusTimeline extends StatelessWidget {
  const _SwapStatusTimeline({required this.status});
  final SwapStatus status;

  static const _labels = ['Requested', 'Accepted', 'Approved'];
  static const _nodeSize = 28.0;
  static const _trackHeight = 3.0;

  @override
  Widget build(BuildContext context) {
    if (status == SwapStatus.rejected || status == SwapStatus.cancelled) {
      final rejected = status == SwapStatus.rejected;
      final color = rejected ? AppColors.error : AppColors.textTertiary;
      return Row(
        children: [
          Icon(
            rejected ? Icons.cancel_rounded : Icons.do_not_disturb_on_rounded,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            rejected ? 'Swap rejected' : 'Swap cancelled',
            style: AppTypography.caption.copyWith(color: color),
          ),
        ],
      );
    }
    final reached = switch (status) {
      SwapStatus.pending => 1,
      SwapStatus.employeeApproved => 2,
      SwapStatus.managerApproved => 3,
      _ => 0,
    };
    final done = status == SwapStatus.managerApproved
        ? AppColors.success
        : AppColors.textPrimary;
    return LayoutBuilder(
      builder: (context, constraints) {
        final stepWidth = constraints.maxWidth / _labels.length;
        return Stack(
          children: [
            // Draw the two rails behind the nodes. Each starts and ends at a
            // node centre, rather than at its top edge, so the line is truly
            // centred regardless of the label height below it.
            for (var i = 0; i < _labels.length - 1; i++)
              Positioned(
                left: stepWidth * (i + .5),
                top: (_nodeSize - _trackHeight) / 2,
                width: stepWidth,
                height: _trackHeight,
                child: DecoratedBox(
                  key: ValueKey('swap-timeline-track-$i'),
                  decoration: BoxDecoration(
                    color: reached > i + 1 ? done : AppColors.darkBorder,
                    borderRadius: BorderRadius.circular(_trackHeight),
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < _labels.length; i++)
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: _TimelineNode(
                        label: _labels[i],
                        nodeKey: ValueKey('swap-timeline-node-${_labels[i]}'),
                        state: i < reached
                            ? _NodeState.done
                            : (i == reached
                                  ? _NodeState.active
                                  : _NodeState.upcoming),
                        doneColor: done,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

enum _NodeState { done, active, upcoming }

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({
    required this.label,
    required this.state,
    required this.doneColor,
    this.nodeKey,
  });

  final String label;
  final _NodeState state;
  final Color doneColor;
  final Key? nodeKey;

  @override
  Widget build(BuildContext context) {
    final Widget dot;
    Color labelColor;
    switch (state) {
      case _NodeState.done:
        dot = Container(
          key: nodeKey,
          width: _SwapStatusTimeline._nodeSize,
          height: _SwapStatusTimeline._nodeSize,
          decoration: BoxDecoration(
            color: doneColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: doneColor.withAlpha(58),
                blurRadius: 12,
                spreadRadius: -2,
              ),
            ],
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 16,
            color: AppColors.onPrimary,
          ),
        );
        labelColor = AppColors.textSecondary;
      case _NodeState.active:
        dot = Container(
          key: nodeKey,
          width: _SwapStatusTimeline._nodeSize,
          height: _SwapStatusTimeline._nodeSize,
          decoration: BoxDecoration(
            color: AppColors.darkSurfaceElevated,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.warning, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.warning.withAlpha(44),
                blurRadius: 12,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.warning,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
        labelColor = AppColors.warning;
      case _NodeState.upcoming:
        dot = Container(
          key: nodeKey,
          width: _SwapStatusTimeline._nodeSize,
          height: _SwapStatusTimeline._nodeSize,
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.darkBorder, width: 2),
          ),
        );
        labelColor = AppColors.textTertiary;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        const SizedBox(height: 7),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: labelColor,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _NoteLine extends StatelessWidget {
  const _NoteLine({required this.note});
  final String note;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.format_quote_rounded,
          size: 15,
          color: AppColors.textTertiary,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            note,
            style: AppTypography.bodySmall.copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}

/// Compact "submitted N ago" label for a swap's createdAt timestamp.
String _relativeTime(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return '${(d.inDays / 7).floor()}w ago';
}

/// Resolves a swap's `branchId` to a branch name via [BranchCubit] (admin queue
/// spans branches). Falls back to a short id if the branch list isn't loaded.
class _BranchLine extends StatelessWidget {
  const _BranchLine({required this.branchId});
  final String branchId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BranchCubit, BranchState>(
      builder: (context, state) {
        final branch = context.read<BranchCubit>().branchById(branchId);
        final name =
            branch?.name ?? (branchId.isEmpty ? 'Unassigned branch' : branchId);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BranchAvatar(
              logoUrl: branch?.logoUrl,
              name: name,
              size: 18,
              radius: 6,
            ),
            const SizedBox(width: 6),
            Text(name, style: AppTypography.caption),
          ],
        );
      },
    );
  }
}

class _SwapButton extends StatelessWidget {
  const _SwapButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color,
    this.style = PremiumButtonStyle.tonal,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;
  final PremiumButtonStyle style;

  @override
  Widget build(BuildContext context) {
    return PremiumButton(
      label: label,
      icon: icon,
      onPressed: onPressed,
      tone: color,
      style: style,
    );
  }
}

class _SwapStatusChip extends StatelessWidget {
  const _SwapStatusChip({required this.status});
  final SwapStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _swapAccent(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Text(
        status.label,
        style: AppTypography.caption.copyWith(color: color),
      ),
    );
  }
}

/// Bottom sheet for an employee to request a shift swap: a clear exchange
/// preview (what you give ⇄ what you get), a coworker picker (avatars +
/// eligibility), an optional note, then send. Re-validates the full exchange
/// (slot integrity · role compatibility · double-booking · rest hours) against
/// the live [schedule] before sending; the `approveSwap` Cloud Function is the
/// authoritative backstop at approval time.
Future<void> showSwapRequestSheet({
  required BuildContext context,
  required ShiftSwapCubit cubit,
  required WeeklyScheduleEntity schedule,
  required String branchId,
  required DateTime weekStart,
  required ScheduleDay day,
  required ScheduleShift shift,
  required UserEntity requester,
  required List<UserEntity> coworkers,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.darkSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetCtx) => _SwapRequestSheet(
      cubit: cubit,
      schedule: schedule,
      branchId: branchId,
      weekStart: weekStart,
      day: day,
      shift: shift,
      requester: requester,
      coworkers: coworkers,
    ),
  );
}

class _SwapRequestSheet extends StatefulWidget {
  const _SwapRequestSheet({
    required this.cubit,
    required this.schedule,
    required this.branchId,
    required this.weekStart,
    required this.day,
    required this.shift,
    required this.requester,
    required this.coworkers,
  });

  final ShiftSwapCubit cubit;
  final WeeklyScheduleEntity schedule;
  final String branchId;
  final DateTime weekStart;
  final ScheduleDay day;
  final ScheduleShift shift;
  final UserEntity requester;
  final List<UserEntity> coworkers;

  @override
  State<_SwapRequestSheet> createState() => _SwapRequestSheetState();
}

class _SwapRequestSheetState extends State<_SwapRequestSheet> {
  final _note = TextEditingController();
  UserEntity? _target;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// The branch's swap rules (role compatibility / rest hours), resolved from
  /// the app-wide [BranchCubit] directory; permissive default when none.
  SwapPolicy get _policy =>
      context
          .read<BranchCubit>()
          .branchById(widget.branchId)
          ?.effectiveSwapPolicy ??
      SwapPolicy.permissive;

  void _send() {
    final target = _target;
    if (target == null) {
      AppSnackbar.error(context, 'Pick a coworker to swap with.');
      return;
    }
    // Immediate feedback (spec §2): can't swap a past/in-progress shift.
    if (!SwapEligibility.isRequestable(
      widget.weekStart,
      widget.day,
      widget.shift,
    )) {
      AppSnackbar.error(context, SwapEligibility.pastShiftMessage);
      return;
    }
    // Full client-side re-validation (the Cloud Function re-checks at approval).
    final reason = SwapValidation.check(
      schedule: widget.schedule,
      day: widget.day,
      requesterShift: widget.shift,
      requesterId: widget.requester.uid,
      targetId: target.uid,
      requesterPosition: widget.requester.position,
      targetPosition: target.position,
      policy: _policy,
    );
    if (reason != null) {
      AppSnackbar.error(context, reason);
      return;
    }
    final note = _note.text.trim();
    widget.cubit.requestSwap(
      branchId: widget.branchId,
      weekStart: widget.weekStart,
      day: widget.day,
      shift: widget.shift,
      requesterId: widget.requester.uid,
      requesterName: userDisplayName(widget.requester),
      targetId: target.uid,
      targetName: userDisplayName(target),
      note: note.isEmpty ? null : note,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final policy = _policy;
    final others = widget.coworkers
        .where((u) => u.uid != widget.requester.uid)
        .toList();
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.pagePadding,
        right: AppSpacing.pagePadding,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.darkBorder,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            const Text('Request a shift swap', style: AppTypography.h3),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${widget.day.label} · trade your shift with a coworker',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Exchange preview — what you give ⇄ what you get.
            _ExchangePreview(day: widget.day, yourShift: widget.shift),
            const SizedBox(height: AppSpacing.lg),

            const Text('Swap with', style: AppTypography.labelSmall),
            const SizedBox(height: AppSpacing.sm),
            if (others.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text(
                  'No coworkers on the ${widget.shift.opposite.label} shift '
                  'to swap with.',
                  style: AppTypography.bodySmall,
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: others.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    final u = others[i];
                    final compatible = policy.positionsCompatible(
                      widget.requester.position,
                      u.position,
                    );
                    return _CoworkerTile(
                      user: u,
                      shift: widget.shift.opposite,
                      selected: _target?.uid == u.uid,
                      enabled: compatible,
                      onTap: compatible
                          ? () => setState(() => _target = u)
                          : null,
                    );
                  },
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _note,
              label: 'Note (optional)',
              prefixIcon: Icons.notes_rounded,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(label: 'Send swap request', onPressed: _send),
          ],
        ),
      ),
    );
  }
}

/// "You give {shift}  ⇄  You get {opposite}" — makes the trade unmistakable
/// before the requester commits.
class _ExchangePreview extends StatelessWidget {
  const _ExchangePreview({required this.day, required this.yourShift});
  final ScheduleDay day;
  final ScheduleShift yourShift;

  @override
  Widget build(BuildContext context) {
    return AppGlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: _PreviewSlot(
              caption: 'You give',
              shift: yourShift,
              day: day,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Icon(
              Icons.swap_horiz_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ),
          Expanded(
            child: _PreviewSlot(
              caption: 'You get',
              shift: yourShift.opposite,
              day: day,
              alignEnd: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewSlot extends StatelessWidget {
  const _PreviewSlot({
    required this.caption,
    required this.shift,
    required this.day,
    this.alignEnd = false,
  });

  final String caption;
  final ScheduleShift shift;
  final ScheduleDay day;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          caption.toUpperCase(),
          style: AppTypography.caption.copyWith(
            color: AppColors.textTertiary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        _ShiftPill(shift: shift),
        const SizedBox(height: 4),
        // Weekend nights (Thu/Fri/Sat) run 16:00–00:00, weekdays 15:00–23:00.
        Text(shift.timeRangeOn(day), style: AppTypography.caption),
      ],
    );
  }
}

/// Selectable coworker row in the request sheet — avatar + name + their shift /
/// position; disabled with a reason when role-incompatible.
class _CoworkerTile extends StatelessWidget {
  const _CoworkerTile({
    required this.user,
    required this.shift,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final UserEntity user;
  final ScheduleShift shift;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      '${shift.label} shift',
      if ((user.position ?? '').trim().isNotEmpty) user.position!.trim(),
    ].join(' · ');
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          borderRadius: AppRadius.cardAll,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.darkSurfaceElevated
                  : AppColors.darkSurface,
              borderRadius: AppRadius.cardAll,
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.darkBorder,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                UserAvatar.fromUser(user, size: 38),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userDisplayName(user),
                        style: AppTypography.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        enabled ? subtitle : '$subtitle · different role',
                        style: AppTypography.caption.copyWith(
                          color: enabled
                              ? AppColors.textTertiary
                              : AppColors.warning,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected ? AppColors.primary : AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
