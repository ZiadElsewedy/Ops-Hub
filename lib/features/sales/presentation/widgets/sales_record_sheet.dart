import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/features/auth/presentation/widgets/app_button.dart';
import 'package:drop/features/sales/presentation/sales_format.dart';

/// What the record sheet returns. [businessDateKey] is null for "Today" — the
/// server resolves the Cairo business day — and a `yyyyMMdd` key for a picked
/// past day. [note] is optional (empty when the manager left it blank).
typedef SalesRecordInput = ({int amountPiastres, String? businessDateKey, String note});

/// Collects a direct sales record from a manager/admin: the amount, which
/// business day it belongs to (today by default, or any past day this month),
/// and an optional note. The record lands **already approved**, so the sheet
/// says so plainly rather than implying a review step.
Future<SalesRecordInput?> showSalesRecordSheet(BuildContext context) {
  final amount = TextEditingController();
  final note = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  var selected = today;

  String? keyFor(DateTime day) => day == today
      ? null
      : '${day.year.toString().padLeft(4, '0')}'
            '${day.month.toString().padLeft(2, '0')}'
            '${day.day.toString().padLeft(2, '0')}';

  return showModalBottomSheet<SalesRecordInput>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => Padding(
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
              Text('Record sales', style: AppTypography.h3),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Adds an approved day straight to the branch total — no review needed.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount (EGP)'),
                validator: (value) =>
                    parseEgpToPiastres(value ?? '') == null ? 'Enter a valid amount.' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              _DayRow(
                label: selected == today ? 'Today' : formatBusinessDate(keyFor(selected)!),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: sheetContext,
                    initialDate: selected,
                    firstDate: DateTime(now.year, now.month, 1),
                    lastDate: today,
                  );
                  if (picked != null) {
                    setSheetState(() => selected = DateTime(picked.year, picked.month, picked.day));
                  }
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: note,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Record',
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  Navigator.pop(sheetContext, (
                    amountPiastres: parseEgpToPiastres(amount.text)!,
                    businessDateKey: keyFor(selected),
                    note: note.text.trim(),
                  ));
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: AppRadius.mdAll,
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_outlined, size: 20, color: AppColors.textTertiary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Business day',
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Text(
            label,
            style: AppTypography.label.copyWith(color: AppColors.textPrimary),
          ),
          const Icon(Icons.chevron_right, size: 20, color: AppColors.textTertiary),
        ],
      ),
    ),
  );
}
