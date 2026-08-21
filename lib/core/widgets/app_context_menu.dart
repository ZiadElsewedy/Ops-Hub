import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_typography.dart';

/// One entry in a right-click context menu.
class AppContextMenuItem {
  const AppContextMenuItem({
    required this.icon,
    required this.label,
    this.onSelected,
    this.destructive = false,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onSelected;
  final bool destructive;
  final bool enabled;
}

/// The desktop right-click menu — the single styled context menu for the whole
/// app (schedule chips, employee cards, task cards). Anchored at the pointer's
/// [position] (global coordinates, e.g. from `onSecondaryTapDown.globalPosition`
/// or `onLongPressStart.globalPosition` on touch).
Future<void> showAppContextMenu({
  required BuildContext context,
  required Offset position,
  required List<AppContextMenuItem> items,
}) async {
  final overlay =
      Overlay.of(context).context.findRenderObject()! as RenderBox;
  final selected = await showMenu<AppContextMenuItem>(
    context: context,
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      overlay.size.width - position.dx,
      overlay.size.height - position.dy,
    ),
    color: AppColors.darkSurfaceElevated,
    elevation: 6,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: AppColors.darkBorder),
    ),
    items: [
      for (final item in items)
        PopupMenuItem<AppContextMenuItem>(
          value: item,
          enabled: item.enabled,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 16,
                color: !item.enabled
                    ? AppColors.textTertiary
                    : item.destructive
                        ? AppColors.error
                        : AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Text(
                item.label,
                style: AppTypography.labelSmall.copyWith(
                  color: !item.enabled
                      ? AppColors.textTertiary
                      : item.destructive
                          ? AppColors.error
                          : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
    ],
  );
  selected?.onSelected?.call();
}
