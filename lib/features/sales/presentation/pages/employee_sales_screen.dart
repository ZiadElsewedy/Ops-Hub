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
import 'package:drop/core/widgets/drop_empty_state.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/core/widgets/list_skeleton.dart';
import 'package:drop/core/widgets/page_hero.dart';
import 'package:drop/core/widgets/primary_cta.dart';
import 'package:drop/core/widgets/stat_strip.dart';
import 'package:drop/features/sales/domain/entities/daily_sales_submission_entity.dart';
import 'package:drop/features/sales/domain/sales_business_time.dart';
import 'package:drop/features/sales/domain/sales_calculator.dart';
import 'package:drop/features/sales/presentation/cubit/sales_month_cubit.dart';
import 'package:drop/features/sales/presentation/cubit/sales_month_state.dart';
import 'package:drop/features/sales/presentation/sales_format.dart';
import 'package:drop/features/sales/presentation/widgets/sales_progress_strip.dart';
import 'package:drop/features/sales/presentation/widgets/sales_submission_tile.dart';

/// The employee's own sales page: today, the month, and their own history.
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
    title: 'My sales',
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
            child: DropEmptyState(
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
        final daysLeft = sellingDaysRemaining(
          calendarDaysInMonth(DateTime.now()),
          calendarDaysElapsed(DateTime.now()),
        );
        final history = [...state.ownSubmissions]
          ..sort((a, b) => b.businessDateKey.compareTo(a.businessDateKey));

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          children: [
            PageHero(
              eyebrow: formatBusinessMonth(state.todayDateKey.substring(0, 6)),
              title: 'My sales',
              subtitle: snapshot.hasTarget
                  ? 'Only approved days count toward the branch target.'
                  : 'Your manager sets this month’s target before sales can be '
                        'submitted.',
              trailing: [
                if (state.canSubmitToday)
                  PrimaryCta(
                    icon: Icons.add_chart_rounded,
                    label: 'Submit today’s sales',
                    onTap: () => context.push(RouteNames.salesSubmit),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            _TodayCard(
              submission: today,
              closedByTeammate: state.todayClosedByTeammate,
              dateKey: state.todayDateKey,
              hasTarget: snapshot.hasTarget,
            ),
            if (snapshot.hasTarget) ...[
              const SizedBox(height: AppSpacing.xl),
              GlassContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatStrip(
                      stats: [
                        Stat(
                          label: 'Target',
                          value: formatEgp(
                            snapshot.target!.targetPiastres,
                            withSuffix: true,
                          ),
                          tone: AppColors.textSecondary,
                        ),
                        Stat(
                          label: 'Achieved',
                          value: formatEgp(
                            snapshot.approvedTotalPiastres,
                            withSuffix: true,
                          ),
                        ),
                        Stat(
                          label: 'Remaining',
                          value: formatEgp(
                            snapshot.remainingPiastres,
                            withSuffix: true,
                          ),
                          tone: AppColors.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SalesProgressStrip(
                      ratioCapped: snapshot.progressRatioCapped,
                      ratioRaw: snapshot.progressRatioRaw,
                      remainingPiastres: snapshot.remainingPiastres,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '$daysLeft ${daysLeft == 1 ? 'day' : 'days'} left in the month',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            Text('My submissions', style: AppTypography.labelLarge),
            const SizedBox(height: AppSpacing.md),
            if (history.isEmpty)
              const DropEmptyState(
                title: 'Nothing submitted yet',
                message:
                    'Your daily closes for this month will be listed here once '
                    'you submit one.',
              ),
            for (final submission in history)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: SalesSubmissionTile(
                  submission: submission,
                  showSubmitter: false,
                  onTap: () => context.push(
                    RouteNames.salesSubmissionDetail(submission.id),
                  ),
                  onCorrect: submission.needsCorrection
                      ? () => context.push(
                          '${RouteNames.salesSubmit}?correct=${Uri.encodeQueryComponent(submission.id)}',
                        )
                      : null,
                ),
              ),
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
    required this.hasTarget,
  });

  final DailySalesSubmissionEntity? submission;
  final bool closedByTeammate;
  final String dateKey;
  final bool hasTarget;

  @override
  Widget build(BuildContext context) {
    final sale = submission;
    final String headline;
    final String detail;
    if (sale != null) {
      headline = formatEgp(sale.amountPiastres, withSuffix: true);
      detail = switch (sale.status) {
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
    } else if (!hasTarget) {
      headline = 'Not submitted';
      detail = 'Submitting opens once this month’s target is set.';
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
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                    letterSpacing: 1,
                  ),
                ),
              ),
              if (sale != null) salesStatusBadge(sale.status),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(headline, style: AppTypography.h3),
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
