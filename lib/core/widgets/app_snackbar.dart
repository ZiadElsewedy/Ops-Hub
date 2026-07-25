import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_typography.dart';

/// Consistent, theme-aware snackbars used across the app.
class AppSnackbar {
  AppSnackbar._();

  static void success(BuildContext context, String message,
          {SnackBarAction? action}) =>
      _show(context, message, AppColors.success,
          Icons.check_circle_outline_rounded,
          action: action);

  static void error(BuildContext context, String message,
          {SnackBarAction? action}) =>
      _show(context, message, AppColors.error, Icons.error_outline_rounded,
          action: action);

  /// A neutral, non-status notice (e.g. "coming soon"). Uses the elevated
  /// surface rather than a semantic colour so it never reads as success/error.
  static void info(BuildContext context, String message,
          {SnackBarAction? action}) =>
      _show(context, message, AppColors.darkSurfaceElevated,
          Icons.info_outline_rounded,
          action: action);

  static void _show(
    BuildContext context,
    String message,
    Color color,
    IconData icon, {
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: AppColors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.label.copyWith(color: AppColors.white),
                ),
              ),
            ],
          ),
          action: action,
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: action == null ? 3 : 6),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
  }
}
