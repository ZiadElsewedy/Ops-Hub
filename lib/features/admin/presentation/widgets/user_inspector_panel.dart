import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/utils/app_date_formatter.dart';
import 'package:opshub/core/widgets/premium_button.dart';
import 'package:opshub/core/widgets/user_avatar.dart';
import 'package:opshub/features/admin/domain/entities/user_compensation.dart';
import 'package:opshub/features/admin/presentation/cubit/admin_users_cubit.dart';
import 'package:opshub/features/admin/presentation/employee_metrics.dart';
import 'package:opshub/features/admin/presentation/widgets/admin_user_sheets.dart';
import 'package:opshub/features/admin/presentation/widgets/compensation_fields.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';

/// Desktop person **inspector** — a right slide-over that replaces the modal
/// Details dialog. The list stays visible behind a light scrim; the panel
/// carries everything the old dialog held plus the compensation record and
/// this-week performance, with the common actions one click away.
Future<void> showUserInspector({
  required BuildContext context,
  required AdminUsersCubit cubit,
  required UserEntity user,
  String? branchLabel,
  EmployeeMetrics? metrics,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: AppColors.black.withAlpha(130),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (ctx, _, _) => Align(
      alignment: Alignment.centerRight,
      child: _InspectorPanel(
        cubit: cubit,
        user: user,
        branchLabel: branchLabel,
        metrics: metrics,
      ),
    ),
    transitionBuilder: (ctx, animation, _, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
          .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}

class _InspectorPanel extends StatelessWidget {
  const _InspectorPanel({
    required this.cubit,
    required this.user,
    this.branchLabel,
    this.metrics,
  });

  final AdminUsersCubit cubit;
  final UserEntity user;
  final String? branchLabel;
  final EmployeeMetrics? metrics;

  String get _name =>
      (user.displayName?.trim().isNotEmpty ?? false)
          ? user.displayName!.trim()
          : user.email;

  String get _subtitle => [
        if ((user.position ?? '').trim().isNotEmpty) user.position!.trim(),
        branchLabel ?? 'No branch',
        if ((user.assignedShift ?? '').isNotEmpty) user.assignedShift!,
      ].join(' · ');

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.darkSurface,
      child: Container(
        width: 380,
        height: double.infinity,
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: AppColors.darkBorder)),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
          children: [
            Row(
              children: [
                UserAvatar.fromUser(user, size: 44),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.h3),
                      const SizedBox(height: 2),
                      Text(_subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: AppColors.textTertiary),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                PremiumButton(
                  label: 'Edit info',
                  icon: Icons.edit_outlined,
                  onPressed: () => showEditDetailsSheet(
                      context: context, cubit: cubit, user: user),
                ),
                PremiumButton(
                  label: 'Reset',
                  icon: Icons.lock_reset_rounded,
                  onPressed: () => showResetAccountSheet(
                      context: context, cubit: cubit, user: user),
                ),
                PremiumButton(
                  label: user.isActive ? 'Deactivate' : 'Activate',
                  icon: user.isActive
                      ? Icons.block_rounded
                      : Icons.check_circle_outline_rounded,
                  tone: user.isActive ? AppColors.error : AppColors.success,
                  onPressed: () {
                    cubit.setActive(user, !user.isActive);
                    Navigator.of(context).pop();
                  },
                ),
                PremiumButton(
                  label: 'Delete',
                  icon: Icons.delete_forever_outlined,
                  tone: AppColors.error,
                  onPressed: () async {
                    final deleted = await confirmAndDeleteAccount(
                        context: context, cubit: cubit, user: user);
                    if (deleted && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(height: 1, color: AppColors.darkBorder),
            _section('CONTACT', [
              _row(Icons.mail_outline_rounded, 'Email', user.email),
              _row(Icons.phone_outlined, 'Phone', user.phoneNumber),
              _row(Icons.home_outlined, 'Address', user.address),
              _row(Icons.emergency_outlined, 'Emergency',
                  user.emergencyContact),
            ]),
            _section('WORK', [
              _row(Icons.badge_outlined, 'Role', user.role.value),
              _row(Icons.work_outline_rounded, 'Position', user.position),
              _row(Icons.store_mall_directory_outlined, 'Branch',
                  branchLabel ?? user.branchId),
              _row(Icons.schedule_rounded, 'Shift', user.assignedShift),
              _row(Icons.verified_user_outlined, 'Employment',
                  user.employmentStatus),
              if (user.createdAt != null)
                _row(Icons.event_outlined, 'Joined', _date(user.createdAt!)),
              if (user.mustChangePassword)
                _row(Icons.lock_clock_outlined, 'First login',
                    'Pending password change'),
            ]),
            // Compensation is private data (C2) — fetched on demand from the
            // subdocument, never carried on the user entity.
            FutureBuilder<UserCompensation?>(
              future: cubit.compensationFor(user.uid),
              builder: (_, snap) {
                final c = snap.data;
                if (c == null || c.isEmpty) return const SizedBox.shrink();
                return _section('COMPENSATION', [
                  _row(Icons.payments_outlined, 'Salary',
                      salarySummary(c.salaryAmount, c.salaryType)),
                  _row(
                      Icons.account_balance_wallet_outlined,
                      'Paid via',
                      (c.paymentMethod ?? '').isEmpty
                          ? null
                          : paymentMethodLabel(c.paymentMethod!)),
                  _row(Icons.tag_rounded, 'Payment no.', c.paymentNumber),
                ]);
              },
            ),
            if (metrics != null) ...[
              _caption('THIS WEEK'),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  _metricChip('${metrics!.completed} done'),
                  const SizedBox(width: 6),
                  _metricChip('${metrics!.pending} open'),
                  const SizedBox(width: 6),
                  _metricChip('${metrics!.late} late'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> rows) {
    final visible =
        rows.whereType<Widget>().where((w) => w is! SizedBox).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.lg),
        _caption(title),
        const SizedBox(height: AppSpacing.xs),
        ...visible,
      ],
    );
  }

  Widget _caption(String text) => Text(text,
      style: AppTypography.caption
          .copyWith(letterSpacing: 1, color: AppColors.textTertiary));

  /// One labelled row; collapses to nothing when the value is missing so
  /// sections stay clean instead of listing dashes.
  Widget _row(IconData icon, String label, String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.textTertiary),
          const SizedBox(width: 10),
          SizedBox(
            width: 86,
            child: Text(label, style: AppTypography.caption),
          ),
          Expanded(
            child: Text(v,
                style: AppTypography.labelSmall
                    .copyWith(color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _metricChip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.darkSurfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Text(label,
            style: AppTypography.caption
                .copyWith(color: AppColors.textPrimary)),
      );

  static String _date(DateTime d) => AppDateFormatter.monthDayYear(d);
}
