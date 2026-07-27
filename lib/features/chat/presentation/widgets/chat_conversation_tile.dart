import 'package:flutter/material.dart';
import 'package:drop/core/responsive/breakpoints.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/user_avatar.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/chat/domain/entities/chat_conversation.dart';
import 'package:drop/features/chat/presentation/chat_format.dart';
import 'package:drop/features/task/presentation/activity_format.dart'
    show relativeTime;

/// A premium inbox row for one direct conversation: a real avatar, the
/// teammate's name, a last-message preview, relative time, and an unread badge.
///
/// [counterpart] is the resolved teammate (from the Firebase directory); when
/// present it drives the avatar + name + role, so the UI never shows a backend
/// id. [title]/[preview]/[unreadCount] are optional overrides; a null
/// [unreadCount] (or 0) hides the badge.
class ChatConversationTile extends StatefulWidget {
  const ChatConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
    this.counterpart,
    this.title,
    this.preview,
    this.unreadCount,
    this.selected = false,
  });

  final ChatConversationSummary conversation;
  final VoidCallback onTap;

  /// The resolved teammate — drives avatar, name, and role. Null → a neutral
  /// avatar + the deterministic fallback label.
  final UserEntity? counterpart;

  /// Explicit name override (wins over [counterpart]).
  final String? title;

  /// Last-message body. Null → state line off `lastMessageAt`.
  final String? preview;

  /// Unread messages. Null or 0 → no badge.
  final int? unreadCount;

  /// Optional host-controlled selection highlight.
  final bool selected;

  /// Shared with inbox dividers and skeletons so all list states align to the
  /// same 8pt rhythm.
  static const double avatarSize = 56;
  static const double avatarGap = AppSpacing.lg;

  @override
  State<ChatConversationTile> createState() => _ChatConversationTileState();
}

class _ChatConversationTileState extends State<ChatConversationTile> {
  bool _hovered = false;

  static const Duration _motionDuration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final unread = (widget.unreadCount ?? 0) > 0;
    final when =
        widget.conversation.lastMessageAt ?? widget.conversation.createdAt;
    final name =
        widget.title ??
        chatDisplayName(
          widget.counterpart,
          fallbackId: widget.conversation.counterpartUserId,
        );
    final role = widget.counterpart == null
        ? null
        : chatRoleLabel(widget.counterpart!.role);
    final previewText = (widget.preview ?? '').trim();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration = reduceMotion ? Duration.zero : _motionDuration;
    final selected = widget.selected;
    final surface = selected
        ? AppColors.primarySurface.withValues(alpha: 0.10)
        : _hovered
        ? AppColors.primarySurface.withValues(alpha: 0.055)
        : AppColors.transparent;
    final borderColor = selected
        ? AppColors.primarySurface.withValues(alpha: 0.16)
        : _hovered
        ? AppColors.primarySurface.withValues(alpha: 0.09)
        : AppColors.transparent;

    return Semantics(
      button: true,
      label: unread
          ? 'Open chat with $name, ${widget.unreadCount} unread messages'
          : 'Open chat with $name',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: AppColors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: AppRadius.mdAll,
            // iOS-style press: a quiet highlight fade, no Material ripple.
            splashFactory: NoSplash.splashFactory,
            hoverColor: AppColors.transparent,
            focusColor: AppColors.primarySurface.withValues(alpha: 0.10),
            highlightColor: AppColors.primarySurface.withValues(alpha: 0.14),
            child: AnimatedContainer(
              duration: duration,
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: context.pagePadding,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: AppRadius.mdAll,
                border: Border.all(color: borderColor),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _Avatar(
                    counterpart: widget.counterpart,
                    fallbackName: name,
                    unread: unread,
                  ),
                  const SizedBox(width: ChatConversationTile.avatarGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: AppTypography.labelLarge.copyWith(
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              relativeTime(when),
                              style: AppTypography.caption.copyWith(
                                color: unread
                                    ? AppColors.textSecondary
                                    : AppColors.textTertiary,
                                fontWeight: unread
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                // The inbox only lists conversations that have
                                // a message, so there is always a real preview;
                                // a rare still-resolving row shows the subtle
                                // role instead of any placeholder.
                                previewText.isNotEmpty
                                    ? previewText
                                    : (role ?? ''),
                                style: AppTypography.body.copyWith(
                                  color: unread
                                      ? AppColors.textSecondary
                                      : AppColors.textTertiary,
                                  fontWeight: unread
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                  height: 1.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            AnimatedSwitcher(
                              duration: duration,
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeIn,
                              transitionBuilder: (child, animation) =>
                                  FadeTransition(
                                    opacity: animation,
                                    child: ScaleTransition(
                                      scale: Tween<double>(
                                        begin: 0.86,
                                        end: 1,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  ),
                              child: unread
                                  ? _UnreadBadge(
                                      key: ValueKey(
                                        'unread-${widget.unreadCount}',
                                      ),
                                      count: widget.unreadCount!,
                                    )
                                  : role != null && previewText.isNotEmpty
                                  ? Text(
                                      role,
                                      key: const ValueKey('chat-role'),
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.textQuaternary,
                                      ),
                                    )
                                  : const SizedBox(
                                      key: ValueKey('chat-row-meta-empty'),
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The counterpart avatar — real photo when resolved, otherwise the initial(s)
/// of the display name (never a generic grey glyph). An unread conversation
/// gets a subtle accent ring.
class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.counterpart,
    required this.fallbackName,
    required this.unread,
  });
  final UserEntity? counterpart;

  /// Name to derive initials from when [counterpart] hasn't resolved (the same
  /// label the row shows), so the disc stays consistent with the title.
  final String fallbackName;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final ring = unread
        ? AppColors.primary.withValues(alpha: 0.55)
        : AppColors.darkBorder.withValues(alpha: 0.82);
    if (counterpart != null) {
      return UserAvatar.fromUser(
        counterpart!,
        size: ChatConversationTile.avatarSize,
        ringColor: ring,
      );
    }
    // Unresolved (directory miss / deep link): still an initials chip, not the
    // grey placeholder — UserAvatar renders the display name's initial(s).
    return UserAvatar(
      name: fallbackName,
      size: ChatConversationTile.avatarSize,
      ringColor: ring,
    );
  }
}

/// Monochrome unread count pill.
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('chat-unread-badge'),
      width: 20,
      height: 20,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              count > 99 ? '99+' : '$count',
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
