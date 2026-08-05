import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/features/auth/presentation/widgets/app_button.dart';
import 'package:drop/features/sales/presentation/sales_format.dart';

typedef SalesAmountReason = ({int amountPiastres, String reason});

Future<SalesAmountReason?> showSalesTargetEditorSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  String? initialAmount,
  String confirmLabel = 'Save',
}) {
  final amount = TextEditingController(text: initialAmount);
  final reason = TextEditingController();
  final formKey = GlobalKey<FormState>();
  return showModalBottomSheet<SalesAmountReason>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.lg,
        AppSpacing.pagePadding,
        MediaQuery.viewInsetsOf(sheetContext).bottom + AppSpacing.lg,
      ),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AppTypography.h3),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Amount (EGP)'),
              validator: (value) {
                final parsed = parseEgpToPiastres(value ?? '');
                return parsed == null ? 'Enter a valid amount.' : null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: reason,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Reason (required)'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'A reason is required.'
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: confirmLabel,
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(sheetContext, (
                  amountPiastres: parseEgpToPiastres(amount.text)!,
                  reason: reason.text.trim(),
                ));
              },
            ),
          ],
        ),
      ),
    ),
  );
}
