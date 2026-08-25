import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_typography.dart';

/// Shared confirmation dialog used for destructive / irreversible actions
/// (delete, sign out, …). Centralises the chrome that was copy-pasted across
/// the branch, task and role-chrome screens so every confirmation looks and
/// behaves the same.
///
/// Returns `true` only when the user taps the confirm action; dismissing the
/// dialog (tap-outside / back) resolves to `false`.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20))),
      title: Text(title, style: AppTypography.h3),
      content: Text(message, style: AppTypography.bodySmall),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: destructive
              ? TextButton.styleFrom(foregroundColor: AppColors.error)
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
