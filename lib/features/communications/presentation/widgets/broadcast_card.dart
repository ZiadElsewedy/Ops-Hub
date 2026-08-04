import 'package:flutter/material.dart';
import 'package:drop/core/enums/broadcast_category.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/features/communications/domain/entities/broadcast_entity.dart';
import 'package:drop/features/communications/presentation/communications_format.dart';

/// The per-item action menu on a broadcast feed card.
enum BroadcastCardAction { open, repeatNow, archive, unarchive, delete }

/// A single broadcast in the Communications Center history feed — a calm,
/// minimal card: a quiet category glyph, the title, one supporting meta line
/// (category · audience · sender · time), a one-line message preview, and a
/// right-aligned delivery figure. Premium monochrome (built on [GlassContainer]);
/// colour only for an emergency category or a failed delivery.
class BroadcastCard extends StatelessWidget {
  const BroadcastCard({
    super.key,
    required this.broadcast,
    required this.onTap,
    this.onAction,
    this.selected = false,
    this.onSelected,
  });

  final BroadcastEntity broadcast;
  final VoidCallback onTap;

  /// Optional per-item action handler. When null, the overflow menu is hidden
  /// (e.g. a read-only context).
  final void Function(BroadcastCardAction action)? onAction;

  /// When supplied, shows a feed-selection checkbox. Selection is owned by the
  /// parent list so it survives lazy card recycling and realtime feed updates.
  final bool selected;
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    final category = BroadcastCategory.fromString(broadcast.category);
    final catColor = categoryColor(category);
    final urgent = category.isUrgent;
    final dimmed = !broadcast.isActive; // archived / deleted read muted

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Opacity(
        opacity: dimmed ? 0.55 : 1,
        child: GlassContainer(
          onTap: onTap,
          highlight: selected,
          accent: AppColors.primary,
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (onSelected != null) ...[
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: Checkbox(
                        key: ValueKey('select-${broadcast.id}'),
                        value: selected,
                        onChanged: (value) => onSelected!(value ?? false),
                        activeColor: AppColors.primary,
                        checkColor: AppColors.black,
                        side: const BorderSide(color: AppColors.textTertiary),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  // Quiet category glyph — a soft fill, no border. Emergency is
                  // the only one that carries colour.
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: urgent
                          ? catColor.withAlpha(26)
                          : AppColors.primary.withAlpha(12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(categoryIcon(category),
                        size: 17,
                        color: urgent ? catColor : AppColors.textSecondary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          broadcast.title,
                          style: AppTypography.label
                              .copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        _MetaLine(broadcast: broadcast, category: category),
                      ],
                    ),
                  ),
                  if (onAction != null) _menu(context) else const SizedBox(width: 6),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                broadcast.message,
                style: AppTypography.body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _DeliveryLine(broadcast: broadcast),
                  const Spacer(),
                  if (!broadcast.isActive)
                    _StatusChip(broadcast: broadcast)
                  else
                    Text(broadcastTimeAgo(broadcast.createdAt),
                        style: AppTypography.caption),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menu(BuildContext context) {
    final archived = broadcast.isArchived;
    return PopupMenuButton<BroadcastCardAction>(
      tooltip: 'Actions',
      icon: const Icon(Icons.more_horiz_rounded,
          size: 20, color: AppColors.textTertiary),
      color: AppColors.darkSurfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: onAction,
      itemBuilder: (context) => [
        _item(BroadcastCardAction.open, Icons.open_in_full_rounded, 'Open'),
        _item(BroadcastCardAction.repeatNow, Icons.replay_rounded, 'Repeat now'),
        if (archived)
          _item(BroadcastCardAction.unarchive, Icons.unarchive_rounded,
              'Unarchive')
        else
          _item(BroadcastCardAction.archive, Icons.archive_outlined, 'Archive'),
        _item(BroadcastCardAction.delete, Icons.delete_outline_rounded, 'Delete',
            destructive: true),
      ],
    );
  }

  PopupMenuItem<BroadcastCardAction> _item(
    BroadcastCardAction value,
    IconData icon,
    String label, {
    bool destructive = false,
    bool enabled = true,
  }) {
    final color = destructive
        ? AppColors.error
        : (enabled ? AppColors.textPrimary : AppColors.textTertiary);
    return PopupMenuItem<BroadcastCardAction>(
      value: value,
      enabled: enabled,
      height: 44,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.md),
          Text(label, style: AppTypography.body.copyWith(color: color)),
        ],
      ),
    );
  }
}

/// The single supporting line under the title: category · audience · sender.
/// Everything muted; the emergency category is the only tinted token. Kept as
/// discrete [Text] runs (not one joined string) so each fact stays legible and
/// individually testable.
class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.broadcast, required this.category});
  final BroadcastEntity broadcast;
  final BroadcastCategory category;

  @override
  Widget build(BuildContext context) {
    final catColor = categoryColor(category);
    return Row(
      children: [
        Text(category.label,
            style: AppTypography.caption.copyWith(
              color: category.isUrgent ? catColor : AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            )),
        _dot(),
        Text(audienceLabel(broadcast), style: AppTypography.caption),
        _dot(),
        Flexible(
          child: Text(broadcast.senderName,
              style: AppTypography.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

/// Delivery summary — "Delivered M/N" once known (with a red failed count when
/// any push failed), else "N recipients". Text-only, no leading glyph.
class _DeliveryLine extends StatelessWidget {
  const _DeliveryLine({required this.broadcast});
  final BroadcastEntity broadcast;

  @override
  Widget build(BuildContext context) {
    final recipients = broadcast.recipientCount;
    if (recipients == null) return const SizedBox.shrink();
    final delivered = broadcast.deliveredCount;
    final failed = broadcast.failedCount;
    final text = delivered != null
        ? 'Delivered $delivered/$recipients'
        : '$recipients ${recipients == 1 ? 'recipient' : 'recipients'}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text,
            style: AppTypography.caption
                .copyWith(color: AppColors.textSecondary)),
        if (failed != null && failed > 0) ...[
          _dot(),
          Text('$failed failed',
              style: AppTypography.caption.copyWith(color: AppColors.error)),
        ],
      ],
    );
  }
}

/// A small status chip shown for archived / deleted broadcasts.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.broadcast});
  final BroadcastEntity broadcast;

  @override
  Widget build(BuildContext context) {
    const color = AppColors.textTertiary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.archive_outlined, size: 12, color: color),
        const SizedBox(width: 4),
        Text(broadcastStatusLabel(broadcast),
            style: AppTypography.caption.copyWith(color: color)),
      ],
    );
  }
}

Widget _dot() => const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Text('·', style: TextStyle(color: AppColors.textQuaternary)),
    );
