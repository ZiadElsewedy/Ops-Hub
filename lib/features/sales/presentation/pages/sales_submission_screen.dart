import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/app_snackbar.dart';
import 'package:drop/core/widgets/page_hero.dart';
import 'package:drop/features/auth/presentation/widgets/app_button.dart';
import 'package:drop/features/sales/domain/sales_business_time.dart';
import 'package:drop/features/sales/presentation/cubit/sales_month_cubit.dart';
import 'package:drop/features/sales/presentation/cubit/sales_month_state.dart';
import 'package:drop/features/sales/presentation/sales_format.dart';

class SalesSubmissionScreen extends StatefulWidget {
  const SalesSubmissionScreen({super.key});
  @override
  State<SalesSubmissionScreen> createState() => _SalesSubmissionScreenState();
}

class _SalesSubmissionScreenState extends State<SalesSubmissionScreen> {
  final _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.currentUser;
    final now = cairoCivilTime(DateTime.now());
    final date =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    return AdaptiveScaffold(
      title: 'Today’s sales',
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        children: [
          PageHero(
            eyebrow: 'Close of day',
            title: 'Today’s sales',
            subtitle: '${user?.branchId ?? 'Branch'} · $date',
          ),
          const SizedBox(height: AppSpacing.xxl),
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
          _Row(label: 'Business day', value: date),
          _Row(
            label: 'Counts toward',
            value: '${now.month.toString().padLeft(2, '0')}/${now.year} target',
          ),
          _Row(label: 'Submitting as', value: user?.displayName ?? 'Employee'),
          const SizedBox(height: AppSpacing.xxl),
          BlocConsumer<SalesMonthCubit, SalesMonthState>(
            listener: (context, state) {
              if (state is! SalesMonthLoaded || state.message == null) return;
              if (state.message == 'Sales submitted for approval.') {
                AppSnackbar.success(context, state.message!);
                context.pop();
              } else {
                AppSnackbar.error(context, state.message!);
              }
            },
            builder: (context, state) {
              final loaded = state is SalesMonthLoaded ? state : null;
              final noTarget = loaded != null && !loaded.snapshot.hasTarget;
              return Column(
                children: [
                  AppButton(
                    label: 'Submit for approval',
                    isLoading: loaded?.submitting ?? false,
                    onPressed: user == null || noTarget
                        ? null
                        : () {
                            final amount = parseEgpToPiastres(_controller.text);
                            if (amount == null) {
                              AppSnackbar.error(
                                context,
                                'Enter a valid non-negative EGP amount.',
                              );
                              return;
                            }
                            context.read<SalesMonthCubit>().submitToday(
                              amountPiastres: amount,
                              user: user,
                            );
                          },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    noTarget
                        ? 'A monthly target must be set before sales can be submitted.'
                        : 'Sent to your manager for approval. It only counts once approved.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
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
