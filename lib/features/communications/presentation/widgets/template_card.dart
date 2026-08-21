import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/glass_container.dart';
import 'package:opshub/features/communications/domain/entities/broadcast_template_entity.dart';
import 'package:opshub/features/communications/presentation/communications_format.dart';

/// Per-card actions on a broadcast template.
enum TemplateCardAction { use, edit, favorite, delete }

/// A reusable broadcast template card — title, category, message preview,
/// favorite star, placeholder/usage hints, and (optionally) a global badge +
/// actions menu. Used in the library (grid/list) and the composer picker.
class TemplateCard extends StatelessWidget {
  const TemplateCard({
    super.key,
    required this.template,
    required this.onTap,
    this.onAction,
    this.compact = false,
  });

  final BroadcastTemplateEntity template;
  final VoidCallback onTap;
  final void Function(TemplateCardAction action)? onAction;

  /// Grid mode (denser) vs list mode.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final catColor = categoryColor(template.category);
    final placeholders = template.placeholders;

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 0 : AppSpacing.md),
      child: GlassContainer(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(categoryIcon(template.category), size: 16, color: catColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(template.title,
                      style: AppTypography.label
                          .copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                if (template.isFavorite)
                  const Icon(Icons.star_rounded,
                      size: 16, color: AppColors.warning),
                if (onAction != null) _menu(),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(template.message,
                style: AppTypography.bodySmall,
                maxLines: compact ? 3 : 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Text(template.category.label,
                    style: AppTypography.caption.copyWith(color: catColor)),
                if (template.isGlobal) ...[
                  _dot(),
                  const Text('Global', style: AppTypography.caption),
                ],
                if (placeholders.isNotEmpty) ...[
                  _dot(),
                  const Icon(Icons.data_object_rounded,
                      size: 12, color: AppColors.textTertiary),
                  const SizedBox(width: 2),
                  Text('${placeholders.length}',
                      style: AppTypography.caption),
                ],
                const Spacer(),
                if (template.usageCount > 0)
                  Text('Used ${template.usageCount}×',
                      style: AppTypography.caption),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _menu() => PopupMenuButton<TemplateCardAction>(
        tooltip: 'Actions',
        icon: const Icon(Icons.more_vert_rounded,
            size: 18, color: AppColors.textTertiary),
        color: AppColors.darkSurfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onSelected: onAction,
        itemBuilder: (context) => [
          _item(TemplateCardAction.use, Icons.bolt_rounded, 'Use'),
          _item(TemplateCardAction.edit, Icons.edit_outlined, 'Edit'),
          _item(
              TemplateCardAction.favorite,
              template.isFavorite ? Icons.star_border_rounded : Icons.star_rounded,
              template.isFavorite ? 'Unfavorite' : 'Favorite'),
          _item(TemplateCardAction.delete, Icons.delete_outline_rounded, 'Delete',
              destructive: true),
        ],
      );

  PopupMenuItem<TemplateCardAction> _item(
      TemplateCardAction value, IconData icon, String label,
      {bool destructive = false}) {
    final color = destructive ? AppColors.error : AppColors.textPrimary;
    return PopupMenuItem<TemplateCardAction>(
      value: value,
      height: 44,
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.md),
        Text(label, style: AppTypography.body.copyWith(color: color)),
      ]),
    );
  }

  Widget _dot() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6),
        child: Text('·', style: TextStyle(color: AppColors.textTertiary)),
      );
}
