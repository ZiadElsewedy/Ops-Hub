import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/core/widgets/status_badge.dart';
import 'package:drop/core/widgets/user_avatar.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';

/// A single-line employee record for the admin Employees directory.
///
/// The card answers only the two questions a directory is scanned for — **who**
/// and **where** — plus the one state that gates everything else (access) and
/// the supplied actions. Task performance deliberately does not appear here: it
/// belongs to the Details inspector, where there is room to read it honestly
/// instead of four numbers competing with every name on the page.
///
/// Collapsing identity, access and actions onto one row roughly halves the row
/// height, so twice as many people fit on screen and the eye runs straight down
/// a single column of names.
class EmployeeCard extends StatelessWidget {
  const EmployeeCard({
    super.key,
    required this.user,
    this.branchLabel,
    this.onTap,
    this.actions = const [],
  });

  final UserEntity user;

  /// Resolved branch name. Null/blank falls back to the raw id, then to the
  /// explicit "No branch" state — an unassigned employee is worth seeing.
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
        // A compact row needs a tighter radius than a content card: 20 reads as
        // a pill once the box is only ~68px tall.
        borderRadius: AppRadius.lgAll,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final identity = _Identity(user: user, name: name, branch: branch);
            final badge = _AccessBadge(isActive: user.isActive);

            // Below this the action cluster can no longer share the row with a
            // readable name, so it drops to its own line rather than crushing
            // the identity into an ellipsis.
            final wide = constraints.maxWidth >= 520;
            if (wide) {
              return Row(
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: AppSpacing.md),
                  badge,
                  if (actions.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.md),
                    _Actions(actions: actions),
                  ],
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: identity),
                    const SizedBox(width: AppSpacing.sm),
                    badge,
                  ],
                ),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  _Actions(actions: actions),
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

  /// Null when this employee has no branch at all — the card renders that as a
  /// distinct, quieter state instead of an ordinary-looking label.
  static String? _branchLabel(UserEntity user, String? branchLabel) {
    final resolved = branchLabel?.trim() ?? '';
    if (resolved.isNotEmpty) return resolved;
    final id = user.branchId?.trim() ?? '';
    return id.isNotEmpty ? id : null;
  }
}

class _Identity extends StatelessWidget {
  const _Identity({
    required this.user,
    required this.name,
    required this.branch,
  });

  final UserEntity user;
  final String name;
  final String? branch;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // The shared avatar preserves photo loading/fallback behaviour. Its
        // quieter white ring gives initials a more intentional desktop finish.
        UserAvatar.fromUser(
          user,
          size: 44,
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
              const SizedBox(height: 3),
              _BranchLine(branch: branch),
            ],
          ),
        ),
      ],
    );
  }
}

/// Where this person works — the card's whole second line, so it carries a mark
/// of its own instead of hiding behind a middot. Three distinct steps of the
/// grey ramp keep the name, the mark and the branch from ever flattening into
/// one another.
class _BranchLine extends StatelessWidget {
  const _BranchLine({required this.branch});

  final String? branch;

  @override
  Widget build(BuildContext context) {
    final assigned = branch != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.storefront_outlined,
          size: 13,
          color: assigned ? AppColors.textTertiary : AppColors.textQuaternary,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            branch ?? 'No branch',
            style: AppTypography.bodySmall.copyWith(
              // An unassigned employee reads faint rather than red: it is a gap
              // to fill, not a failure.
              color: assigned
                  ? AppColors.textSecondary
                  : AppColors.textQuaternary,
              fontStyle: assigned ? FontStyle.normal : FontStyle.italic,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
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
