import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/core/widgets/premium_button.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_ledger_row.dart';

class AttendanceReportCoverage extends StatelessWidget {
  const AttendanceReportCoverage({
    super.key,
    required this.coverage,
    required this.totalRows,
  });

  final LedgerCoverage coverage;
  final int totalRows;

  @override
  Widget build(BuildContext context) {
    final awaiting = coverage.awaitingClose;
    return GlassContainer(
      highlight: coverage.blockingExceptionRowCount > 0,
      accent: coverage.blockingExceptionRowCount > 0
          ? AppColors.warning
          : AppColors.textPrimary,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          final status = _StatusLockup(
            awaiting: awaiting,
            coverage: coverage,
            totalRows: totalRows,
          );
          final blockers = _PayrollBlockers(coverage: coverage);
          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                status,
                const SizedBox(height: AppSpacing.lg),
                blockers,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: status),
              const SizedBox(width: AppSpacing.xl),
              Expanded(flex: 2, child: blockers),
            ],
          );
        },
      ),
    );
  }
}

class _StatusLockup extends StatelessWidget {
  const _StatusLockup({
    required this.awaiting,
    required this.coverage,
    required this.totalRows,
  });

  final bool awaiting;
  final LedgerCoverage coverage;
  final int totalRows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: AppRadius.mdAll,
                color: awaiting
                    ? AppColors.warning.withValues(alpha: 0.10)
                    : AppColors.primarySurface.withValues(alpha: 0.08),
                border: Border.all(
                  color: awaiting
                      ? AppColors.warning.withValues(alpha: 0.36)
                      : AppColors.darkBorder,
                ),
              ),
              child: Icon(
                awaiting
                    ? Icons.hourglass_empty_rounded
                    : Icons.verified_outlined,
                color: awaiting ? AppColors.warning : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    awaiting ? 'Awaiting close' : 'Ledger-backed report',
                    style: AppTypography.h3,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    awaiting
                        ? 'This period has no materialized ledger rows yet. It may not be closed, or no roster was published.'
                        : '${coverage.closedRowCount} of $totalRows ledger rows are closed and backing these numbers.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          awaiting
              ? 'Rates and zero-valued totals are hidden until attendance_expectations has rows for this scope and period.'
              : 'If the period is partially closed, the row count above is the trust boundary for this report.',
          style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
        ),
      ],
    );
  }
}

class _PayrollBlockers extends StatelessWidget {
  const _PayrollBlockers({required this.coverage});

  final LedgerCoverage coverage;

  @override
  Widget build(BuildContext context) {
    final active = coverage.blockingExceptionRowCount > 0;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.darkBorder),
        color: AppColors.darkSurface.withValues(alpha: 0.72),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payroll blockers',
            style: AppTypography.label.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            coverage.awaitingClose
                ? 'Not available'
                : '${coverage.blockingExceptionRowCount}',
            style: AppTypography.displayMedium.copyWith(
              color: active ? AppColors.warning : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            coverage.awaitingClose
                ? 'Blockers are known only after rows materialize.'
                : active
                ? 'Resolve these before trusting payroll handoff.'
                : 'No blocking exception rows in this ledger window.',
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PremiumButton(
            label: 'Open exception queue · coming next',
            icon: Icons.lock_clock_outlined,
            onPressed: null,
          ),
        ],
      ),
    );
  }
}
