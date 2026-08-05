import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/features/auth/presentation/widgets/app_button.dart';

Future<String?> showSalesReasonSheet(
  BuildContext context, {
  required String title,
  String confirmLabel = 'Confirm',
}) {
  final controller = TextEditingController();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.lg,
        AppSpacing.pagePadding,
        MediaQuery.viewInsetsOf(sheetContext).bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Reason (required)'),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: confirmLabel,
            onPressed: () {
              final reason = controller.text.trim();
              if (reason.isNotEmpty) Navigator.pop(sheetContext, reason);
            },
          ),
        ],
      ),
    ),
  );
}
