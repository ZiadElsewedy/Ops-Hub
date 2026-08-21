import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/app_error_state.dart';
import 'package:drop/core/widgets/app_snackbar.dart';
import 'package:drop/core/widgets/brand_watermark.dart';
import 'package:drop/core/widgets/opshub_empty_state.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/core/widgets/list_skeleton.dart';
import 'package:drop/features/auth/presentation/widgets/app_button.dart';
import 'package:drop/features/sales/domain/entities/daily_sales_submission_entity.dart';
import 'package:drop/features/sales/domain/sales_kpis_calculator.dart';
import 'package:drop/features/sales/presentation/cubit/sales_month_cubit.dart';
import 'package:drop/features/sales/presentation/cubit/sales_month_state.dart';
import 'package:drop/features/sales/presentation/sales_format.dart';
import 'package:drop/features/sales/presentation/widgets/sales_needed_per_day.dart';
import 'package:drop/features/sales/presentation/widgets/sales_target_hero.dart';
import 'package:drop/features/sales/presentation/widgets/sales_submission_tile.dart';

/// The employee's view of **the branch's** sales month. Five things and nothing
/// else: the team's **target · achieved · remaining**, what today needs, today's
/// close, and the one action.
///
/// The target is a **branch** number, never a personal one — every teammate's
/// approved day counts toward the same total, and "achieved" is the branch's
/// achieved. Nothing on this page is framed as the viewer's own score.
///
/// The month-history list was removed here — every record it showed is already
/// on the branch ledger a manager reviews, and it made this page a table. The
/// one exception is a day the manager sent back: that keeps a visible row,
/// because without it `correctionRequested` is a dead end with no way back to
/// `pending`.
///
/// Reads the app-wide [SalesMonthCubit] that Home already drives, so opening
/// this page costs no extra Firestore reads and the two surfaces can never
/// disagree about what "today" is.
class EmployeeSalesScreen extends StatelessWidget {
  const EmployeeSalesScreen({super.key});

  void _reload(BuildContext context) {
    final user = context.currentUser;
    final branchId = user?.branchId;
    if (user == null || branchId == null || branchId.isEmpty) return;
    context.read<SalesMonthCubit>().loadForEmployee(
      branchId: branchId,
      uid: user.uid,
      force: true,
    );
  }

  @override
  Widget build(BuildContext context) => AdaptiveScaffold(
    title: 'Branch sales',
    body: BlocConsumer<SalesMonthCubit, SalesMonthState>(
      listenWhen: (previous, current) =>
          current is SalesMonthLoaded && current.message != null,
      listener: (context, state) {
        final message = (state as SalesMonthLoaded).message!;
        if (message == salesSubmittedMessage ||
            message == salesResubmittedMessage) {
          AppSnackbar.success(context, message);
        } else {
          AppSnackbar.error(context, message);
        }
      },
      builder: (context, state) {
        if (state is SalesMonthDisabled) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.pagePadding),
            child: OpsHubEmptyState(
              title: 'Sales targets are off',
              message:
                  'This branch doesn’t track a monthly sales target, so there '
                  'is nothing to submit or review here.',
            ),
          );
        }
        if (state is SalesMonthError) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            child: AppProblemPanel(
              title: 'Sales unavailable',
              message: state.message,
              onRetry: () => _reload(context),
            ),
          );
        }
        if (state is! SalesMonthLoaded) return const ListSkeleton();

        final snapshot = state.snapshot;
        final today = state.todaySubmission;
        final kpis = computeSalesKpis(snapshot, now: DateTime.now());
        // A day the manager sent back for correction OR rejected — the employee
        // can fix and resend either.
        final resubmittable = state.resubmittable.firstOrNull;

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pagePadding,
            AppSpacing.lg,
            AppSpacing.pagePadding,
            AppSpacing.xxl,
          ),
          children: [
            // ── The month ──────────────────────────────────────────────
            GlassContainer(
              child: BrandWatermark(
                opacity: 0.05,
                assetLogo: true,
                assetHeight: 46,
                // Top-right, clear of the Achieved/Remaining figures that sit in
                // the bottom corners of this card.
                corner: Alignment.topRight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TEAM TARGET · '
                      '${formatBusinessMonth(state.todayDateKey.substring(0, 6)).toUpperCase()}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (snapshot.hasTarget)
                      SalesTargetHero(
                        targetPiastres: snapshot.target!.targetPiastres,
                        achievedPiastres: snapshot.approvedTotalPiastres,
                        remainingPiastres: snapshot.remainingPiastres,
                        progressRatio: snapshot.progressRatioCapped,
                      )
                    else
                      Text(
                        'Your manager sets the branch’s target for this month '
                        'before sales can be submitted.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── What today needs ───────────────────────────────────────
            if (snapshot.hasTarget) ...[
              const SizedBox(height: AppSpacing.lg),
              SalesNeededPerDay(
                // The branch's close for today — the employee's own record if
                // they closed it, otherwise whoever did (a manager, admin or
                // teammate). Pace judges the *branch's* day, so a teammate's
                // close counts here just as it does in the card below; only a
                // genuinely un-closed day reads as "not submitted yet".
                neededPerDayPiastres: kpis.neededPerDayPiastres,
                // A rejected close is excluded — it's not a valid contribution.
                todayPiastres: state.todayCountedPiastres,
                daysRemaining: kpis.daysRemaining,
              ),
            ],

            // ── Today ──────────────────────────────────────────────────
            const SizedBox(height: AppSpacing.lg),
            _TodayCard(
              submission: today,
              closedByTeammate: state.todayClosedByTeammate,
              dateKey: state.todayDateKey,
            ),

            // ── The one action ─────────────────────────────────────────
            if (state.canSubmitToday) ...[
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Submit today’s sales',
                onPressed: () => context.push(RouteNames.salesSubmit),
              ),
            ],

            // A day sent back for correction OR rejected keeps its way home —
            // the employee fixes the amount and resubmits it for approval.
            if (resubmittable != null) ...[
              const SizedBox(height: AppSpacing.xl),
              Text(
                resubmittable.isRejected
                    ? 'Rejected — fix and resubmit'
                    : 'Needs your correction',
                style: AppTypography.labelLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              SalesSubmissionTile(
                submission: resubmittable,
                showSubmitter: false,
                onTap: () => context.push(
                  RouteNames.salesSubmissionDetail(resubmittable.id),
                ),
                onCorrect: () => context.push(
                  '${RouteNames.salesSubmit}?correct=${Uri.encodeQueryComponent(resubmittable.id)}',
                ),
              ),
            ],
          ],
        );
      },
    ),
  );
}

/// Today's close, stated in one line the employee can act on.
class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.submission,
    required this.closedByTeammate,
    required this.dateKey,
  });

  final DailySalesSubmissionEntity? submission;
  final bool closedByTeammate;
  final String dateKey;

  @override
  Widget build(BuildContext context) {
    final sale = submission;
    final String headline;
    final String detail;
    if (sale != null) {
      headline = formatEgp(sale.amountPiastres, withSuffix: true);
      detail = switch (sale) {
        _ when sale.isApproved => 'Approved — counted toward the branch target.',
        _ when sale.isRejected =>
          sale.decisionReason == null
              ? 'Rejected by your manager.'
              : 'Rejected — ${sale.decisionReason}',
        _ when sale.needsCorrection =>
          sale.decisionReason == null
              ? 'Your manager asked for a correction.'
              : 'Correction requested — ${sale.decisionReason}',
        _ => 'Sent to your manager, waiting for approval.',
      };
    } else if (closedByTeammate) {
      headline = 'Closed by a teammate';
      detail = 'Today is already recorded for this branch.';
    } else {
      headline = 'Not submitted';
      detail = 'Close the day to send today’s sales for approval.';
    }

    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'TODAY · ${formatBusinessDate(dateKey)}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                    letterSpacing: 1,
                  ),
                ),
              ),
              if (sale != null) salesStatusBadge(sale.status),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(headline, style: AppTypography.h2),
          const SizedBox(height: AppSpacing.xs),
          Text(
            detail,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
