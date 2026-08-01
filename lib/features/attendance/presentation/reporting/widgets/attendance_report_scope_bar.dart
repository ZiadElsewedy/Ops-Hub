import 'package:flutter/material.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/widgets/branch_avatar.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_period.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';

class AttendanceReportScopeBar extends StatelessWidget {
  const AttendanceReportScopeBar({
    super.key,
    required this.role,
    required this.branches,
    required this.selectedBranchId,
    required this.periodType,
    required this.window,
    required this.now,
    required this.onBranchChanged,
    required this.onPeriodTypeChanged,
    required this.onPrevious,
    required this.onNext,
  });

  final UserRole role;
  final List<BranchEntity> branches;
  final String? selectedBranchId;
  final AttendancePeriodType periodType;
  final AttendancePeriodWindow window;
  final DateTime now;
  final ValueChanged<String?> onBranchChanged;
  final ValueChanged<AttendancePeriodType> onPeriodTypeChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  bool get _isAdmin => role.isAdmin;

  bool get _canGoNext {
    final current = _windowFor(periodType, now);
    return window.startDate.isBefore(current.startDate);
  }

  BranchEntity? get _selectedBranch {
    for (final branch in branches) {
      if (branch.id == selectedBranchId) return branch;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // A **control bar, not a content card.** Function is unchanged; only the
    // framing is. Wrapped in a GlassContainer this read as another data panel
    // and competed with the numbers for attention — and it put form controls
    // inside a card inside a card, which the design system rules out. It now
    // sits on the page ground and is closed by a hairline, so it reads as page
    // chrome that scopes what follows.
    return Container(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.darkBorder)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 860;
          final children = [
            Expanded(flex: 3, child: _branchScope(context)),
            const SizedBox(width: AppSpacing.md),
            Expanded(flex: 2, child: _periodTypeControl(context)),
            const SizedBox(width: AppSpacing.md),
            Expanded(flex: 3, child: _windowControl(context)),
          ];
          if (wide) return Row(children: children);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _branchScope(context),
              const SizedBox(height: AppSpacing.md),
              _periodTypeControl(context),
              const SizedBox(height: AppSpacing.md),
              _windowControl(context),
            ],
          );
        },
      ),
    );
  }

  Widget _branchScope(BuildContext context) {
    final selected = _selectedBranch;
    if (!_isAdmin) {
      final label = selected?.name ?? selectedBranchId ?? 'Manager branch';
      return _ControlShell(
        label: 'Branch scope',
        child: Row(
          children: [
            BranchAvatar(name: label, logoUrl: selected?.logoUrl, size: 32),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.lock_outline_rounded,
              size: 16,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      );
    }

    return _ControlShell(
      label: 'Branch scope',
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: selectedBranchId,
          dropdownColor: AppColors.darkSurfaceElevated,
          hint: Text(
            'Choose branch',
            style: AppTypography.label.copyWith(
              color: AppColors.textQuaternary,
            ),
          ),
          icon: const Icon(
            Icons.expand_more_rounded,
            color: AppColors.textSecondary,
          ),
          items: [
            for (final branch in branches.where((b) => !b.isDeleted))
              DropdownMenuItem(
                value: branch.id,
                child: Text(
                  branch.name,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label,
                ),
              ),
          ],
          onChanged: onBranchChanged,
        ),
      ),
    );
  }

  Widget _periodTypeControl(BuildContext context) {
    return _ControlShell(
      label: 'Report period',
      child: SegmentedButton<AttendancePeriodType>(
        segments: const [
          ButtonSegment(
            value: AttendancePeriodType.weekly,
            icon: Icon(Icons.calendar_view_week_outlined, size: 16),
            label: Text('Week'),
          ),
          ButtonSegment(
            value: AttendancePeriodType.monthly,
            icon: Icon(Icons.calendar_month_outlined, size: 16),
            label: Text('Month'),
          ),
        ],
        selected: {periodType},
        showSelectedIcon: false,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.darkSurfaceElevated,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.onPrimary
                : AppColors.textSecondary,
          ),
          side: WidgetStateProperty.all(
            const BorderSide(color: AppColors.darkBorder),
          ),
          textStyle: WidgetStateProperty.all(AppTypography.caption),
        ),
        onSelectionChanged: (selection) =>
            onPeriodTypeChanged(selection.single),
      ),
    );
  }

  Widget _windowControl(BuildContext context) {
    return _ControlShell(
      label: 'Period window',
      child: Row(
        children: [
          _IconTap(icon: Icons.chevron_left_rounded, onTap: onPrevious),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              _windowLabel(window),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label.copyWith(color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _IconTap(
            icon: Icons.chevron_right_rounded,
            onTap: _canGoNext ? onNext : null,
          ),
        ],
      ),
    );
  }

  static AttendancePeriodWindow _windowFor(
    AttendancePeriodType type,
    DateTime anchor,
  ) {
    return switch (type) {
      AttendancePeriodType.monthly => monthlyWindow(anchor.year, anchor.month),
      _ => weeklyWindow(anchor),
    };
  }

  static String _windowLabel(AttendancePeriodWindow window) {
    final start = AppDateFormatter.dayMonthYear(window.startDate);
    final end = AppDateFormatter.dayMonthYear(window.endDate);
    return '$start - $end';
  }
}

class _ControlShell extends StatelessWidget {
  const _ControlShell({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quieter than the old `labelSmall`: a control legend, not a heading.
        // It must not compete with the section titles below it.
        Text(
          label.toUpperCase(),
          style: AppTypography.caption.copyWith(
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.darkSurfaceElevated,
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: AppColors.darkBorder),
          ),
          alignment: Alignment.centerLeft,
          child: child,
        ),
      ],
    );
  }
}

class _IconTap extends StatelessWidget {
  const _IconTap({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: icon == Icons.chevron_left_rounded
          ? 'Previous period'
          : 'Next period',
      onPressed: onTap,
      icon: Icon(
        icon,
        color: onTap == null ? AppColors.textQuaternary : AppColors.textPrimary,
      ),
    );
  }
}
