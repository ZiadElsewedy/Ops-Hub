import 'package:flutter/material.dart';
import 'package:opshub/core/enums/request_status.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/utils/app_date_formatter.dart';
import 'package:opshub/core/widgets/glass_container.dart';
import 'package:opshub/core/widgets/status_badge.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_correction.dart';

/// The **Corrections** section of the Details screen — a read-only history of the
/// correction requests filed against this record (the only sanctioned way a
/// settled record changes). Decisions are made on the reviewer's queue, not here;
/// this is the audit view of what was asked and what was decided.
class AttendanceCorrectionSection extends StatelessWidget {
  const AttendanceCorrectionSection({super.key, required this.corrections});

  final List<AttendanceCorrectionEntity> corrections;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < corrections.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          _CorrectionCard(correction: corrections[i]),
        ],
      ],
    );
  }
}

class _CorrectionCard extends StatelessWidget {
  const _CorrectionCard({required this.correction});
  final AttendanceCorrectionEntity correction;

  @override
  Widget build(BuildContext context) {
    final c = correction;
    final proposed = <String>[
      if (c.proposedClockIn != null)
        'In → ${AppDateFormatter.time(c.proposedClockIn!)}',
      if (c.proposedClockOut != null)
        'Out → ${AppDateFormatter.time(c.proposedClockOut!)}',
    ].join('   ·   ');

    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(c.kind.label,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge(
                  label: c.status.label, color: _statusColor(c.status)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(c.reason,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13.5, height: 1.4)),
          if (proposed.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(proposed,
                style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()])),
          ],
          if (c.requestedByName != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Filed by ${c.requestedByName}'
              '${c.createdAt == null ? '' : ' · ${AppDateFormatter.dayMonth(c.createdAt!)}'}',
              style: const TextStyle(
                  color: AppColors.textTertiary, fontSize: 12),
            ),
          ],
          if (c.isDecided) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${c.isApproved ? 'Approved' : 'Rejected'}'
                    '${c.decidedByName == null ? '' : ' by ${c.decidedByName}'}'
                    '${c.decidedAt == null ? '' : ' · ${AppDateFormatter.dayMonth(c.decidedAt!)}'}',
                    style: TextStyle(
                        color: _statusColor(c.status),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700),
                  ),
                  if ((c.decisionNote ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(c.decisionNote!,
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                            height: 1.4)),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Color _statusColor(RequestStatus s) => switch (s) {
      RequestStatus.pending => AppColors.warning,
      RequestStatus.approved => AppColors.success,
      RequestStatus.rejected => AppColors.error,
    };
