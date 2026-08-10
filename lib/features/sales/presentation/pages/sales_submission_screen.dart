import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/app_error_state.dart';
import 'package:drop/core/widgets/app_snackbar.dart';
import 'package:drop/core/widgets/page_hero.dart';
import 'package:drop/core/widgets/skeleton.dart';
import 'package:drop/features/auth/presentation/widgets/app_button.dart';
import 'package:drop/features/sales/presentation/cubit/sales_month_cubit.dart';
import 'package:drop/features/sales/presentation/cubit/sales_month_state.dart';
import 'package:drop/features/sales/presentation/sales_format.dart';

/// Close of day. Two modes on one screen:
///  * no [submissionId] — submit today's sales for the first time;
///  * with [submissionId] — resend a day the manager sent back for correction.
///
/// Both end in the same place (`pending`, awaiting the manager), so they share
/// the amount field, the confirmation facts, and the single CTA.
class SalesSubmissionScreen extends StatefulWidget {
  const SalesSubmissionScreen({super.key, this.submissionId});

  /// The record being corrected, when arriving from "Fix and resubmit".
  final String? submissionId;

  @override
  State<SalesSubmissionScreen> createState() => _SalesSubmissionScreenState();
}

class _SalesSubmissionScreenState extends State<SalesSubmissionScreen> {
  final _controller = TextEditingController();
  var _seeded = false;

  bool get _isCorrection => widget.submissionId != null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(SalesMonthLoaded state) {
    final user = context.currentUser;
    if (user == null) return;
    final amount = parseEgpToPiastres(_controller.text);
    if (amount == null) {
      AppSnackbar.error(context, 'Enter a valid non-negative EGP amount.');
      return;
    }
    final cubit = context.read<SalesMonthCubit>();
    if (_isCorrection) {
      cubit.resubmitCorrection(
        submissionId: widget.submissionId!,
        amountPiastres: amount,
      );
    } else {
      cubit.submitToday(amountPiastres: amount, user: user);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.currentUser;
    return AdaptiveScaffold(
      title: _isCorrection ? 'Correct sales' : 'Today’s sales',
      body: BlocConsumer<SalesMonthCubit, SalesMonthState>(
        listenWhen: (previous, current) =>
            current is SalesMonthLoaded && current.message != null,
        listener: (context, state) {
          final message = (state as SalesMonthLoaded).message!;
          if (message == salesSubmittedMessage ||
              message == salesResubmittedMessage) {
            AppSnackbar.success(context, message);
            if (context.canPop()) context.pop();
          } else {
            AppSnackbar.error(context, message);
          }
        },
        builder: (context, state) {
          if (state is SalesMonthDisabled) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.pagePadding),
              child: AppProblemPanel(
                title: 'Sales targets are off',
                message:
                    'This branch doesn’t track a monthly sales target, so there '
                    'is nothing to submit.',
              ),
            );
          }
          if (state is SalesMonthError) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.pagePadding),
              child: AppProblemPanel(
                title: 'Sales unavailable',
                message: state.message,
              ),
            );
          }
          if (state is! SalesMonthLoaded) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Skeleton(height: 30),
                  SizedBox(height: AppSpacing.xl),
                  Skeleton(height: 180),
                ],
              ),
            );
          }

          final correcting = _isCorrection
              ? state.ownSubmissions
                    .where((s) => s.id == widget.submissionId)
                    .firstOrNull
              : null;

          // Seed the field once with the amount under correction, so the
          // employee edits the figure instead of retyping it from memory.
          if (_isCorrection && !_seeded && correcting != null) {
            _seeded = true;
            _controller.text = formatEgp(correcting.amountPiastres);
          }

          if (_isCorrection) {
            if (correcting == null) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.pagePadding),
                child: AppProblemPanel(
                  title: 'Nothing to correct',
                  message: 'This submission is no longer awaiting a correction.',
                ),
              );
            }
            if (!correcting.isResubmittable) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.pagePadding),
                child: AppProblemPanel(
                  title: 'Nothing to resubmit',
                  message:
                      'Your manager already '
                      '${correcting.isApproved ? 'approved' : 'closed'} this '
                      'day, so it can’t be resubmitted.',
                ),
              );
            }
          }

          final dateKey = correcting?.businessDateKey ?? state.todayDateKey;
          final existing = state.todaySubmission;
          final blocked =
              !_isCorrection && (existing != null || state.todayClosedByTeammate);

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            children: [
              PageHero(
                eyebrow: _isCorrection ? 'Correction' : 'Close of day',
                title: _isCorrection ? 'Correct sales' : 'Today’s sales',
                subtitle: formatBusinessDate(dateKey),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (correcting?.decisionReason != null) ...[
                AppProblemPanel(
                  title: correcting!.isRejected
                      ? 'Rejected — fix and resubmit'
                      : 'Correction requested',
                  message: correcting.decisionReason!,
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              if (blocked) ...[
                AppProblemPanel(
                  title: 'Today is already closed',
                  message: existing != null
                      ? 'You submitted ${formatEgp(existing.amountPiastres, withSuffix: true)} '
                            'for today. Open Branch sales to see where it stands.'
                      : 'A teammate already recorded today’s sales for this branch.',
                ),
              ] else if (!state.snapshot.hasTarget) ...[
                const AppProblemPanel(
                  title: 'No target yet',
                  message:
                      'A monthly target must be set before sales can be '
                      'submitted. Your manager sets it.',
                ),
              ] else ...[
                TextField(
                  controller: _controller,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.center,
                  style: AppTypography.displayMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: '0.00 EGP',
                    hintStyle: AppTypography.displayMedium.copyWith(
                      color: AppColors.textQuaternary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                _Row(label: 'Business day', value: formatBusinessDate(dateKey)),
                _Row(
                  label: 'Counts toward',
                  value: '${formatBusinessMonth(dateKey.substring(0, 6))} target',
                ),
                _Row(
                  label: 'Submitting as',
                  value: user?.displayName ?? 'Employee',
                ),
                const SizedBox(height: AppSpacing.xxl),
                AppButton(
                  label: _isCorrection
                      ? 'Resubmit for approval'
                      : 'Submit for approval',
                  isLoading: state.submitting,
                  onPressed: user == null || state.submitting
                      ? null
                      : () => _submit(state),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Sent to your manager for approval. It only counts once approved.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
        Text(
          value,
          style: AppTypography.label.copyWith(color: AppColors.textPrimary),
        ),
      ],
    ),
  );
}
