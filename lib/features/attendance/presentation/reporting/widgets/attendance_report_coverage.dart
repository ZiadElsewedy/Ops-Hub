import 'package:flutter/material.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/core/widgets/premium_button.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_ledger_row.dart';

/// **The verdict** — the one card that answers both halves of the question the
/// hub exists for: *can you trust these numbers yet*, and *is anything blocking
/// payroll*.
///
/// It is deliberately two lines, not two cards. Closed-ness used to be stated in
/// three different vocabularies across three surfaces ("N Ready periods",
/// "N of N ledger rows are closed", "Fully closed") and payroll blockers were
/// rendered three times, so a reader could not tell whether that was one fact or
/// several. Both are now stated exactly once.
///
/// **Report exceptions by exception.** A zero-blocker period earns one quiet
/// muted line; a real blocker earns weight, colour and the queue affordance. No
/// space is spent announcing that nothing is wrong.
///
/// Coverage semantics are unchanged; only the words are. No rows ⇒ *No data
/// yet* (missing data, never a `0%` result), rows with no blocking exceptions ⇒
/// *Settled*, rows with blocking exceptions ⇒ *Needs attention*. The old close-
/// pipeline vocabulary (*Awaiting close · Partially closed · Fully closed*) is
/// what the pipeline computes, not what a store manager says.
class AttendanceReportCoverage extends StatelessWidget {
  const AttendanceReportCoverage({
    super.key,
    required this.coverage,
    required this.totalRows,
  });

  final LedgerCoverage coverage;
  final int totalRows;

  bool get _awaiting => coverage.awaitingClose;
  int get _blockers => coverage.blockingExceptionRowCount;

  String get _trustTitle {
    if (_awaiting) return 'No data yet';
    return _blockers > 0 ? 'Needs attention' : 'Settled';
  }

  /// The single coverage restatement. `No data yet` is the owner's rule made
  /// visible: a scope with no rows has no denominator at all, so it must never
  /// be reported as a zero-valued result.
  String get _trustDetail {
    if (_awaiting) return 'No data yet';
    return '${coverage.closedRowCount} of $totalRows shifts settled';
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      highlight: _blockers > 0,
      accent: AppColors.warning,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TrustLine(
            awaiting: _awaiting,
            blocked: _blockers > 0,
            title: _trustTitle,
            detail: _trustDetail,
          ),
          Container(
            height: 1,
            color: AppColors.darkBorder,
            margin: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          ),
          _ActionLine(coverage: coverage, totalRows: totalRows),
        ],
      ),
    );
  }
}

class _TrustLine extends StatelessWidget {
  const _TrustLine({
    required this.awaiting,
    required this.blocked,
    required this.title,
    required this.detail,
  });

  final bool awaiting;
  final bool blocked;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    // Amber for a pipeline state or a blocked close; otherwise the card stays
    // monochrome. No new hue — this is the tone the page already used.
    final toned = awaiting || blocked;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdAll,
            color: toned
                ? AppColors.warning.withValues(alpha: 0.10)
                : AppColors.primarySurface.withValues(alpha: 0.08),
            border: Border.all(
              color: toned
                  ? AppColors.warning.withValues(alpha: 0.36)
                  : AppColors.darkBorder,
            ),
          ),
          child: Icon(
            awaiting
                ? Icons.hourglass_empty_rounded
                : blocked
                ? Icons.report_problem_outlined
                : Icons.verified_outlined,
            color: toned ? AppColors.warning : AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // One trust line: the verdict word plus the single restatement of
              // how much of the period is actually closed. A Wrap so the two
              // sit side by side when there is room and stack when there is not
              // — natural height at every width, no fixed extent.
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  Text(title, style: AppTypography.h2),
                  Text(
                    '·',
                    style: AppTypography.label.copyWith(
                      color: AppColors.textQuaternary,
                    ),
                  ),
                  Text(
                    detail,
                    style: AppTypography.label.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              if (awaiting) ...[
                const SizedBox(height: AppSpacing.sm),
                // Only the awaiting state earns this disclosure: it is the one
                // state with no denominator on screen to speak for itself. Once
                // rows exist the metric denominators below say the same thing.
                Text(
                  'Nothing has been recorded for this branch and period yet — '
                  'missing data, not a 0% attendance result.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionLine extends StatelessWidget {
  const _ActionLine({required this.coverage, required this.totalRows});

  final LedgerCoverage coverage;
  final int totalRows;

  @override
  Widget build(BuildContext context) {
    if (coverage.awaitingClose) {
      return const _QuietLine(
        icon: Icons.schedule_rounded,
        message: 'Nothing to check until shifts are recorded.',
      );
    }
    final blockers = coverage.blockingExceptionRowCount;
    if (blockers == 0) {
      return const _QuietLine(
        icon: Icons.check_circle_outline_rounded,
        message: 'Nothing is waiting on you',
      );
    }

    final lockup = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '$blockers',
          style: AppTypography.displayMedium.copyWith(
            color: AppColors.warning,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Needs your decision', style: AppTypography.labelLarge),
              const SizedBox(height: 2),
              Text(
                '$blockers of $totalRows shifts still need a decision.',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    // The Exception queue itself is a later slice. The affordance stays live and
    // explains itself rather than sitting inert: a disabled button tells a
    // manager nothing about why it cannot be used.
    final queue = PremiumButton(
      label: 'Review these',
      icon: Icons.lock_clock_outlined,
      onPressed: () => context.showInfo('Daily review is coming next.'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 520) {
          return Row(
            children: [
              Expanded(child: lockup),
              const SizedBox(width: AppSpacing.md),
              queue,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            lockup,
            const SizedBox(height: AppSpacing.md),
            queue,
          ],
        );
      },
    );
  }
}

/// A zero-state costs exactly one muted line — never a card, never a big `0`.
class _QuietLine extends StatelessWidget {
  const _QuietLine({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textTertiary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: AppTypography.label.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
