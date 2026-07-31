import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_ledger_row.dart';

/// **The evidence table** — one line per recorded shift, with the record behind
/// it one tap away.
///
/// This used to sit at the foot of the weekly report. Phase 1 removed it from
/// the manager surface because row-level evidence answers *"can I defend this
/// number?"*, which is an auditor's question asked rarely and deliberately —
/// not a store manager's, asked daily. It was **relocated, not deleted**: the
/// capability is unchanged, the audience is not.
///
/// It is deliberately the last section here too. An admin who opens this
/// workspace is usually chasing a branch, not a row.
class AttendanceEvidenceTable extends StatelessWidget {
  const AttendanceEvidenceTable({
    super.key,
    required this.rows,
    this.branchNames = const {},
  });

  final List<AttendanceLedgerRow> rows;

  /// branchId → display name. Missing ids fall back to the raw id, which is
  /// still the truth — an admin can act on it.
  final Map<String, String> branchNames;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Evidence', style: AppTypography.h3),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'One line per recorded shift. Open a row for its full audit trail.',
          style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (rows.isEmpty)
          Text(
            'No shifts recorded in this period.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          )
        else
          ClipRRect(
            borderRadius: AppRadius.lgAll,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.darkBorder),
                borderRadius: AppRadius.lgAll,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 1040),
                  child: Column(
                    children: [
                      const _EvidenceRow(
                        cells: [
                          'Date',
                          'Branch',
                          'Employee',
                          'Shift',
                          'Outcome',
                          'Worked',
                          'Late',
                          'Record',
                        ],
                        header: true,
                      ),
                      for (final row in rows)
                        _EvidenceRow(
                          cells: _cellsFor(row, branchNames),
                          recordId: row.recordId,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  static List<String> _cellsFor(
    AttendanceLedgerRow row,
    Map<String, String> names,
  ) => [
    row.businessDate,
    names[row.branchId] ?? row.branchId,
    row.userName?.trim().isNotEmpty ?? false ? row.userName!.trim() : row.userId,
    row.shift.label,
    // `label`, never `wireValue` — the persisted contract is not English, even
    // on an admin surface.
    row.outcome.label,
    '${row.workedMinutes}',
    '${row.lateMinutes}',
    row.recordId == null ? 'No clock-in recorded' : 'Open record',
  ];
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({required this.cells, this.header = false, this.recordId});

  final List<String> cells;
  final bool header;
  final String? recordId;

  @override
  Widget build(BuildContext context) {
    final last = cells.length - 1;
    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: header
            ? AppColors.darkSurfaceElevated
            : AppColors.darkSurface.withValues(alpha: 0.72),
        border: const Border(bottom: BorderSide(color: AppColors.darkBorder)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            SizedBox(
              width: switch (i) {
                1 || 2 => 170,
                _ when i == last => 170,
                _ => 106,
              },
              child: i == last && recordId != null && !header
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () =>
                            context.push(RouteNames.attendanceRecord(recordId!)),
                        child: const Text('Open record'),
                      ),
                    )
                  : Text(
                      cells[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          (header
                                  ? AppTypography.caption
                                  : AppTypography.label)
                              .copyWith(
                                color: header
                                    ? AppColors.textTertiary
                                    : i == last &&
                                          cells[i].startsWith('No clock-in')
                                    ? AppColors.warning
                                    : AppColors.textSecondary,
                                fontWeight: header
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                    ),
            ),
        ],
      ),
    );
  }
}
