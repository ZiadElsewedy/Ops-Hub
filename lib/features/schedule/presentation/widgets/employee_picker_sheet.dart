import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/schedule/presentation/widgets/employee_row.dart';
import 'package:opshub/features/schedule/presentation/widgets/sheet_chrome.dart';

/// Shared employee picker used to assign an employee to a shift and to reassign
/// a broken slot — a single premium list so the two flows never drift. [onPick]
/// is fired with the chosen user; the caller closes the sheet.
Future<void> showEmployeePicker({
  required BuildContext context,
  required String title,
  required String subtitle,
  required List<UserEntity> employees,
  required bool Function(UserEntity) isAssigned,
  required void Function(UserEntity) onPick,
  String? Function(UserEntity)? subtitleFor,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.darkSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _EmployeePickerSheet(
      title: title,
      subtitle: subtitle,
      employees: employees,
      isAssigned: isAssigned,
      onPick: onPick,
      subtitleFor: subtitleFor,
    ),
  );
}

class _EmployeePickerSheet extends StatelessWidget {
  const _EmployeePickerSheet({
    required this.title,
    required this.subtitle,
    required this.employees,
    required this.isAssigned,
    required this.onPick,
    this.subtitleFor,
  });

  final String title;
  final String subtitle;
  final List<UserEntity> employees;
  final bool Function(UserEntity) isAssigned;
  final void Function(UserEntity) onPick;

  /// Optional per-row caption (e.g. "On leave · Sick leave") — information
  /// for the picker's judgment, never a disabled row.
  final String? Function(UserEntity)? subtitleFor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.md,
        AppSpacing.pagePadding,
        MediaQuery.of(context).padding.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: AppTypography.h3),
          const SizedBox(height: 2),
          Text(subtitle, style: AppTypography.caption),
          const SizedBox(height: AppSpacing.md),
          if (employees.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text('No employees in this branch yet.',
                  style: AppTypography.bodySmall),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: employees.length,
                itemBuilder: (context, i) {
                  final u = employees[i];
                  final assigned = isAssigned(u);
                  return EmployeeRow(
                    user: u,
                    subtitle: subtitleFor?.call(u),
                    onTap: assigned ? null : () => onPick(u),
                    trailing: Icon(
                      assigned
                          ? Icons.check_circle_rounded
                          : Icons.add_circle_outline_rounded,
                      size: 20,
                      color: assigned
                          ? AppColors.success
                          : AppColors.textTertiary,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
