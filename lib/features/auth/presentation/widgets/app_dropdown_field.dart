import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';

/// Reusable dropdown styled to match [AppTextField] (same surface, radius, and
/// border). Replaces the hand-rolled `DropdownButton` boxes used for branch /
/// role / status / priority selection.
///
/// Pass [placeholder] to show a plain message instead of the dropdown (e.g.
/// "Loading…" / "No branches yet") while keeping the same field chrome.
class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint = 'Select',
    this.prefixIcon,
    this.placeholder,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String hint;
  final IconData? prefixIcon;
  final String? placeholder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.xlAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          if (prefixIcon != null) ...[
            Icon(prefixIcon, size: 20, color: AppColors.textTertiary),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: placeholder != null
                ? Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Text(placeholder!,
                        style: AppTypography.body
                            .copyWith(color: AppColors.textTertiary)),
                  )
                : DropdownButtonHideUnderline(
                    child: DropdownButton<T>(
                      value: value,
                      isExpanded: true,
                      hint: Text(hint,
                          style: AppTypography.body
                              .copyWith(color: AppColors.textTertiary)),
                      dropdownColor: AppColors.darkSurfaceElevated,
                      borderRadius: AppRadius.cardAll,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textTertiary),
                      style: AppTypography.body
                          .copyWith(color: AppColors.textPrimary),
                      items: items,
                      onChanged: onChanged,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
