import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/core/widgets/status_badge.dart';
import 'package:drop/core/widgets/user_avatar.dart';
import 'package:drop/features/admin/presentation/employee_metrics.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';

/// A compact, scan-friendly employee record for the admin Employees directory.
///
/// It deliberately keeps identity, access state, the four task facts, and only
/// the supplied primary actions in view. Less-frequent administration actions
/// belong in an [EmployeeOverflowMenu], keeping high-volume directories calm
/// without removing any capability.
class EmployeeCard extends StatelessWidget {
  const EmployeeCard({
    super.key,
    required this.user,
    this.metrics = const EmployeeMetrics(),
    this.branchLabel,
    this.onTap,
    this.actions = const [],
  });

  final UserEntity user;
  final EmployeeMetrics metrics;
  final String? branchLabel;
  final VoidCallback? onTap;

  /// Expected to contain Details, Edit, and an [EmployeeOverflowMenu]. Keeping
  /// this slot-based makes the card presentation-only; all mutations remain in
  /// the page/cubit layer.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final name = _displayName(user);
    final branch = _branchLabel(user, branchLabel);

    return Semantics(
      button: onTap != null,
      label: 'Employee $name',
      child: GlassContainer(
        onTap: onTap,
        elevated: false,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 620;
            final identity = _Identity(user: user, name: name, branch: branch);
            final metricsRow = _InlineMetrics(metrics: metrics);
            final actionRow = _Actions(actions: actions);

            if (wide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  identity,
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: metricsRow),
                      if (actions.isNotEmpty) ...[
                        const SizedBox(width: AppSpacing.lg),
                        actionRow,
                      ],
                    ],
                  ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                identity,
                const SizedBox(height: AppSpacing.sm),
                metricsRow,
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  actionRow,
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  static String _displayName(UserEntity user) {
    final name = user.displayName?.trim() ?? '';
    return name.isNotEmpty ? name : user.email;
  }

  static String _branchLabel(UserEntity user, String? branchLabel) {
    final resolved = branchLabel?.trim() ?? '';
    if (resolved.isNotEmpty) return resolved;
    final id = user.branchId?.trim() ?? '';
    return id.isNotEmpty ? id : 'No branch';
  }

  static String _capitalize(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
}

class _Identity extends StatelessWidget {
  const _Identity({
    required this.user,
    required this.name,
    required this.branch,
  });

  final UserEntity user;
  final String name;
  final String branch;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // The shared avatar preserves photo loading/fallback behaviour. Its
        // quieter white ring gives initials a more intentional desktop finish.
        UserAvatar.fromUser(
          user,
          size: 48,
          ringColor: AppColors.primarySurface,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: AppTypography.labelLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${EmployeeCard._capitalize(user.role.value)} · $branch',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Access state remains the primary status: isActive is the only login
        // gate. HR employment labels are intentionally not conflated with it.
        _AccessBadge(isActive: user.isActive),
      ],
    );
  }
}

class _AccessBadge extends StatelessWidget {
  const _AccessBadge({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 200);
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOut,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(
        key: ValueKey(isActive),
        child: StatusBadge.active(isActive, compact: true),
      ),
    );
  }
}

class _InlineMetrics extends StatelessWidget {
  const _InlineMetrics({required this.metrics});

  final EmployeeMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final rate = metrics.completionRatePct;
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.sm,
      children: [
        _InlineMetric(
          icon: Icons.check_rounded,
          value: '${metrics.completed}',
          label: 'Completed',
          color: AppColors.success,
        ),
        _InlineMetric(
          icon: Icons.hourglass_top_rounded,
          value: '${metrics.pending}',
          label: 'Pending',
          color: AppColors.textSecondary,
        ),
        _InlineMetric(
          icon: Icons.star_outline_rounded,
          value: rate == null ? '—' : '$rate%',
          label: 'Rate',
          color: rate == null ? AppColors.textTertiary : AppColors.textPrimary,
        ),
        _InlineMetric(
          icon: Icons.schedule_rounded,
          value: '${metrics.late}',
          label: 'Late',
          color: metrics.late > 0 ? AppColors.warning : AppColors.textTertiary,
        ),
      ],
    );
  }
}

class _InlineMetric extends StatelessWidget {
  const _InlineMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$value $label',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            value,
            style: AppTypography.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: actions,
    );
  }
}

/// One secondary employee action displayed by [EmployeeOverflowMenu].
class EmployeeOverflowAction {
  const EmployeeOverflowAction({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onSelected;
  final bool destructive;
}

/// Compact ellipsis menu for secondary employee administration actions.
class EmployeeOverflowMenu extends StatelessWidget {
  const EmployeeOverflowMenu({
    super.key,
    required this.employeeName,
    required this.actions,
  });

  final String employeeName;
  final List<EmployeeOverflowAction> actions;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'More actions for $employeeName',
      child: PopupMenuButton<int>(
        tooltip: 'More employee actions',
        color: AppColors.darkSurfaceElevated,
        elevation: 6,
        offset: const Offset(0, 40),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdAll,
          side: const BorderSide(color: AppColors.darkBorder),
        ),
        icon: const Icon(
          Icons.more_horiz_rounded,
          color: AppColors.textSecondary,
        ),
        onSelected: (index) => actions[index].onSelected(),
        itemBuilder: (context) => [
          for (var index = 0; index < actions.length; index++)
            PopupMenuItem<int>(
              value: index,
              height: 40,
              child: _OverflowMenuRow(action: actions[index]),
            ),
        ],
      ),
    );
  }
}

class _OverflowMenuRow extends StatelessWidget {
  const _OverflowMenuRow({required this.action});

  final EmployeeOverflowAction action;

  @override
  Widget build(BuildContext context) {
    final color = action.destructive
        ? AppColors.error
        : AppColors.textSecondary;
    return Row(
      children: [
        Icon(action.icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.sm),
        Text(
          action.label,
          style: AppTypography.labelSmall.copyWith(
            color: action.destructive ? AppColors.error : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
