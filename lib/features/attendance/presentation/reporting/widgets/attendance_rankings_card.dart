import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/glass_container.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_ledger_row.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_rankings.dart';

/// The **Rankings** board on the reports hub — the answer to "who has the most X
/// this period?" that the flat report could only give by scanning. Pick a metric
/// (Overtime · Lateness · Absences · Missing punches · Hours worked) and the top
/// employees for the *currently selected period + branch* rank highest-first.
///
/// Derived entirely from the ledger rows the hub already streams — no new read,
/// no new cubit. Strictly monochrome (ADR-004): rank, name and figure are the
/// grey ramp; nothing tints, because "most overtime" is a fact, not a status.
class AttendanceRankingsCard extends StatefulWidget {
  const AttendanceRankingsCard({super.key, required this.rows, this.limit = 5});

  final List<AttendanceLedgerRow> rows;

  /// How many places the board shows (0 = everyone with a value).
  final int limit;

  @override
  State<AttendanceRankingsCard> createState() => _AttendanceRankingsCardState();
}

class _AttendanceRankingsCardState extends State<AttendanceRankingsCard> {
  AttendanceRankingMetric _metric = AttendanceRankingMetric.overtime;

  @override
  Widget build(BuildContext context) {
    final board = attendanceRankings(
      rows: widget.rows,
      metric: _metric,
      limit: widget.limit,
    );

    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rankings', style: AppTypography.h3),
          const SizedBox(height: 2),
          Text(
            _metric.question,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final m in AttendanceRankingMetric.values)
                _MetricChip(
                  label: m.label,
                  selected: m == _metric,
                  onTap: () => setState(() => _metric = m),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (board.isEmpty)
            _EmptyBoard(metric: _metric)
          else
            for (final entry in board) ...[
              if (entry.rank > 1)
                const Divider(
                  color: AppColors.darkBorder,
                  height: AppSpacing.lg,
                ),
              _RankRow(entry: entry, metric: _metric),
            ],
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.entry, required this.metric});

  final AttendanceRankingEntry entry;
  final AttendanceRankingMetric metric;

  @override
  Widget build(BuildContext context) {
    final value = _formatValue(entry.value, metric);
    return Semantics(
      label: 'Rank ${entry.rank}. ${entry.displayName}. $value.',
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.darkBorder),
              color: AppColors.primarySurface.withValues(alpha: 0.06),
            ),
            child: Text(
              '${entry.rank}',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              entry.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body.copyWith(color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            value,
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBoard extends StatelessWidget {
  const _EmptyBoard({required this.metric});

  final AttendanceRankingMetric metric;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(
        'No ${metric.label.toLowerCase()} recorded this period.',
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? AppColors.primary : AppColors.darkSurfaceElevated,
        borderRadius: AppRadius.fullAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.fullAll,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              borderRadius: AppRadius.fullAll,
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.darkBorder,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.onPrimary : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Minutes → `Xh Ym` (or a bare count for a count metric).
String _formatValue(int value, AttendanceRankingMetric metric) {
  if (metric.isMinutes) {
    if (value <= 0) return '0m';
    final h = value ~/ 60;
    final m = value % 60;
    if (h == 0) return '${m}m';
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
  // Count metric: "1 absence" / "3 absences" — singular from the metric's noun,
  // plural from its already-plural label.
  final unit = value == 1 ? metric.countNoun : metric.label.toLowerCase();
  return '$value $unit';
}
