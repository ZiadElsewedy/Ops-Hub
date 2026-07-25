import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/features/chat/domain/entities/chat_message.dart';

/// The long-press context menu for one chat message — a bottom sheet in the
/// house style (`chip_action_sheet` chrome), followed by a Cases-style
/// confirmation dialog. Selection only: the caller owns the actual delete.
///
/// Which actions appear:
/// * **Delete for me** — always (the backend allows hiding sent *and*
///   received messages, tombstones included).
/// * **Delete for everyone** — only on the caller's **own**, not-yet-deleted
///   messages. That's an identity fact the UI already renders (bubble
///   alignment), not a permission check: the real rules — original sender
///   only, within the server's time window — stay entirely server-side, and
///   a refusal surfaces the server's own 403 message.
Future<ChatMessageAction?> showChatMessageActions(
  BuildContext context, {
  required ChatMessage message,
  required bool mine,
}) async {
  final canDeleteForEveryone = mine && !message.deletedForEveryone;
  // A tombstone has no content to reply to or copy — only the delete-for-me
  // escape hatch stays meaningful on it.
  final tombstone = message.deletedForEveryone;
  final hasText = (message.body ?? '').trim().isNotEmpty && !tombstone;
  final action = await showModalBottomSheet<ChatMessageAction>(
    context: context,
    backgroundColor: AppColors.darkSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      // Scrollable so a short viewport (or a full menu) can never overflow the
      // sheet's capped height — it simply scrolls the last row into reach.
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.darkBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (!tombstone)
            _ActionRow(
              icon: Icons.reply_rounded,
              label: 'Reply',
              detail: 'Quote this message in your next reply.',
              onTap: () =>
                  Navigator.of(sheetContext).pop(ChatMessageAction.reply),
            ),
          if (hasText)
            _ActionRow(
              icon: Icons.copy_rounded,
              label: 'Copy',
              detail: 'Copy the message text.',
              onTap: () => Navigator.of(sheetContext).pop(ChatMessageAction.copy),
            ),
          _ActionRow(
            icon: Icons.info_outline_rounded,
            label: 'Message info',
            detail: 'Delivery details and identifiers.',
            onTap: () =>
                Navigator.of(sheetContext).pop(ChatMessageAction.messageInfo),
          ),
          _ActionRow(
            icon: Icons.visibility_off_outlined,
            label: 'Delete for me',
            detail: 'Removes it from your view only.',
            onTap: () =>
                Navigator.of(sheetContext).pop(ChatMessageAction.deleteForMe),
          ),
          if (canDeleteForEveryone)
            _ActionRow(
              icon: Icons.delete_forever_outlined,
              label: 'Delete for everyone',
              detail: 'Replaced by a placeholder for both of you.',
              destructive: true,
              onTap: () => Navigator.of(sheetContext)
                  .pop(ChatMessageAction.deleteForEveryone),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    ),
  );
  if (action == null || !context.mounted) return null;

  // Reply, Copy and Message info are non-destructive and instant — no confirm.
  if (action == ChatMessageAction.reply ||
      action == ChatMessageAction.copy ||
      action == ChatMessageAction.messageInfo) {
    return action;
  }
  final confirmed = await _confirm(context, action);
  return confirmed ? action : null;
}

enum ChatMessageAction {
  reply,
  copy,
  forward,
  messageInfo,
  deleteForMe,
  deleteForEveryone,
}

/// The desktop **right-click** context menu for a message — a native-feeling
/// popup at the cursor, the counterpart to [showChatMessageActions] (the mobile
/// long-press sheet). Same action vocabulary; destructive actions still route
/// through the shared confirmation. [Forward] is a UI placeholder (no backend
/// fan-out yet). Returns the confirmed action, or null if dismissed/declined.
Future<ChatMessageAction?> showChatMessageContextMenu(
  BuildContext context, {
  required Offset position,
  required ChatMessage message,
  required bool mine,
}) async {
  final tombstone = message.deletedForEveryone;
  final hasText = (message.body ?? '').trim().isNotEmpty && !tombstone;
  final canDeleteForEveryone = mine && !tombstone;
  final overlay =
      Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (overlay == null) return null;

  PopupMenuItem<ChatMessageAction> item(
          ChatMessageAction value, IconData icon, String label,
          {bool destructive = false}) =>
      PopupMenuItem<ChatMessageAction>(
        value: value,
        height: 40,
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: destructive ? AppColors.error : AppColors.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Text(label,
                style: AppTypography.body.copyWith(
                    color:
                        destructive ? AppColors.error : AppColors.textPrimary)),
          ],
        ),
      );

  final action = await showMenu<ChatMessageAction>(
    context: context,
    color: AppColors.darkSurfaceElevated,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: AppColors.darkBorder),
    ),
    position: RelativeRect.fromRect(
      position & const Size(40, 40),
      Offset.zero & overlay.size,
    ),
    items: [
      if (!tombstone) item(ChatMessageAction.reply, Icons.reply_rounded, 'Reply'),
      if (hasText) item(ChatMessageAction.copy, Icons.copy_rounded, 'Copy'),
      item(ChatMessageAction.forward, Icons.forward_rounded, 'Forward'),
      item(ChatMessageAction.deleteForMe, Icons.visibility_off_outlined,
          'Delete for me'),
      if (canDeleteForEveryone)
        item(ChatMessageAction.deleteForEveryone,
            Icons.delete_forever_outlined, 'Delete for everyone',
            destructive: true),
    ],
  );
  if (action == null || !context.mounted) return null;
  // Destructive actions get the same confirmation as the mobile sheet.
  if (action == ChatMessageAction.deleteForMe ||
      action == ChatMessageAction.deleteForEveryone) {
    final confirmed = await _confirm(context, action);
    return confirmed ? action : null;
  }
  return action;
}

Future<bool> _confirm(BuildContext context, ChatMessageAction action) async {
  final forEveryone = action == ChatMessageAction.deleteForEveryone;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.darkSurfaceElevated,
      title: Text(forEveryone ? 'Delete for everyone?' : 'Delete for me?'),
      content: Text(forEveryone
          ? 'Both of you will see "This message was deleted" instead. '
              'This cannot be undone.'
          : 'The message disappears from your view only — the other person '
              'still sees it.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return ok == true;
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.error : AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTypography.body.copyWith(
                          color: color, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(detail,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textTertiary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
