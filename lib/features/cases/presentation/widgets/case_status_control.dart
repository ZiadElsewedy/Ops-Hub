import 'package:flutter/material.dart';
import 'package:opshub/core/enums/case_status.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/features/cases/presentation/case_format.dart';

/// The status control that lives in the conversation **header** (not a bottom
/// bar). For a recipient it's a dropdown of the allowed next transitions; for a
/// reporter (or when [enabled] is false) it's a static status pill.
class CaseStatusControl extends StatelessWidget {
  const CaseStatusControl({
    super.key,
    required this.status,
    required this.enabled,
    required this.onSelect,
    this.busy = false,
  });

  final CaseStatus status;
  final bool enabled;
  final ValueChanged<CaseStatus> onSelect;
  final bool busy;

  static String actionLabel(CaseStatus current, CaseStatus to) {
    if (current.isClosed && to == CaseStatus.inDiscussion) return 'Reopen case';
    return switch (to) {
      CaseStatus.inDiscussion => 'Move to In Discussion',
      CaseStatus.waitingResponse => 'Mark Waiting Response',
      CaseStatus.closed => 'Close case',
      CaseStatus.open => 'Reopen case',
    };
  }

  @override
  Widget build(BuildContext context) {
    final pill = _StatusPill(status: status, interactive: enabled, busy: busy);
    if (!enabled) return pill;

    final options = status.allowedNext;
    return PopupMenuButton<CaseStatus>(
      tooltip: 'Change status',
      color: AppColors.darkSurfaceElevated,
      onSelected: onSelect,
      itemBuilder: (context) => [
        for (final to in options)
          PopupMenuItem<CaseStatus>(
            value: to,
            child: Row(
              children: [
                Icon(caseStatusIcon(to), size: 16, color: caseStatusColor(to)),
                const SizedBox(width: 10),
                Text(actionLabel(status, to), style: AppTypography.body),
              ],
            ),
          ),
      ],
      child: pill,
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.status,
    required this.interactive,
    required this.busy,
  });
  final CaseStatus status;
  final bool interactive;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final color = caseStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: AppRadius.fullAll,
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(caseStatusIcon(status), size: 14, color: color),
          const SizedBox(width: 7),
          Text(status.label,
              style: AppTypography.label
                  .copyWith(color: color, fontWeight: FontWeight.w600)),
          if (interactive) ...[
            const SizedBox(width: 4),
            Icon(Icons.expand_more_rounded, size: 16, color: color),
          ],
        ],
      ),
    );
  }
}
