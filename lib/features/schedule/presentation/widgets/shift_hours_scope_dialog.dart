import 'package:flutter/material.dart';
import 'package:opshub/core/enums/shift_hours_scope.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';

/// Asks the manager how far a shift-hours edit should reach (Schedule V2 ·
/// Pillar 5) — *"Apply changes to: this week / future / globally"*. Returns the
/// chosen [ShiftHoursScope], or null if dismissed. History is safe in every
/// case (the copy says so); the choice only widens what the edit touches.
Future<ShiftHoursScope?> showShiftHoursScopeDialog(
  BuildContext context, {
  required String title,
  List<ShiftHoursScope> scopes = ShiftHoursScope.values,
}) {
  return showModalBottomSheet<ShiftHoursScope>(
    context: context,
    backgroundColor: AppColors.darkSurface,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AppTypography.h3),
            const SizedBox(height: 2),
            Text('Apply changes to',
                style: AppTypography.caption
                    .copyWith(color: AppColors.textTertiary)),
            const SizedBox(height: AppSpacing.md),
            for (final scope in scopes) ...[
              _ScopeOption(
                scope: scope,
                onTap: () => Navigator.of(ctx).pop(scope),
              ),
              if (scope != scopes.last) const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    ),
  );
}

class _ScopeOption extends StatelessWidget {
  const _ScopeOption({required this.scope, required this.onTap});

  final ShiftHoursScope scope;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.darkBg,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.radio_button_unchecked_rounded,
                size: 18, color: AppColors.textTertiary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(scope.label,
                      style: AppTypography.label
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(scope.detail,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textSecondary, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
