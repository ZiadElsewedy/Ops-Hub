import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:opshub/core/di/injection.dart';
import 'package:opshub/core/extensions/context_extensions.dart';
import 'package:opshub/core/routes/route_names.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/utils/app_logger.dart';
import 'package:opshub/core/widgets/app_glass_card.dart';
import 'package:opshub/core/widgets/user_avatar.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/chat/domain/entities/chat_conversation.dart';
import 'package:opshub/features/chat/presentation/chat_format.dart';
import 'package:opshub/features/chat/presentation/chat_thread_args.dart';
import 'package:opshub/features/chat/presentation/cubit/chat_list_cubit.dart';
import 'package:opshub/features/chat/presentation/cubit/chat_list_state.dart';
import 'package:opshub/features/task/presentation/activity_format.dart'
    show relativeTime;

/// A home-dashboard widget surfacing the caller's most recent conversations —
/// avatar · name · last message · time · unread indicator, capped at five.
/// Reuses the app-wide [ChatListCubit] (no new state), resolves real profiles
/// from the Firebase directory, and opens the thread on tap. Renders a quiet
/// empty state ("No recent conversations") when there's nothing yet.
class RecentMessagesCard extends StatefulWidget {
  const RecentMessagesCard({super.key, this.limit = 5});

  final int limit;

  @override
  State<RecentMessagesCard> createState() => _RecentMessagesCardState();
}

class _RecentMessagesCardState extends State<RecentMessagesCard> {
  // Seed from the session cache so real names render on the FIRST build when the
  // directory is already warm — no "Teammate" placeholder flashing to the name.
  Map<String, UserEntity> _directory = AppDependencies.chatDirectorySnapshot;
  final Map<String, ChatPreview> _previews = {};
  final Set<String> _fetching = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Idempotent: no-op if the inbox is already loaded elsewhere.
      context.read<ChatListCubit>().load();
      _loadDirectory();
    });
  }

  Future<void> _loadDirectory() async {
    try {
      final dir = await AppDependencies.loadChatDirectory(context.currentUser);
      if (mounted && dir.isNotEmpty) setState(() => _directory = dir);
    } catch (e) {
      AppLog.warning('chat', 'recent messages directory skipped: $e');
    }
  }

  UserEntity? _counterpartFor(ChatConversationSummary c) {
    final uid = c.counterpartExternalId;
    return uid == null ? null : _directory[uid];
  }

  String? _previewLine(ChatConversationSummary c, Map<String, String> socket) {
    final live = socket[c.id];
    if (live != null && live.isNotEmpty) return live;
    return _previews[c.id]?.line;
  }

  void _resolvePreviews(
      List<ChatConversationSummary> shown, Map<String, String> socket) {
    for (final c in shown) {
      if (socket[c.id]?.isNotEmpty ?? false) continue;
      if (_previews.containsKey(c.id) || _fetching.contains(c.id)) continue;
      _fetching.add(c.id);
      final myId = c.participantIds
          .firstWhere((p) => p != c.counterpartUserId, orElse: () => '');
      AppDependencies.latestChatMessage(c.id).then((message) {
        if (!mounted) return;
        _fetching.remove(c.id);
        if (message == null) return;
        setState(() => _previews[c.id] = ChatPreview(
              chatMessagePreviewText(message),
              mine: myId.isNotEmpty && message.senderId == myId,
            ));
      });
    }
  }

  void _open(ChatConversationSummary c, UserEntity? counterpart) {
    context.read<ChatListCubit>().clearUnread(c.id);
    context.push(
      RouteNames.chatConversation(c.id),
      extra: ChatThreadArgs(
        counterpartUserId: c.counterpartUserId,
        counterpartExternalId: c.counterpartExternalId,
        counterpartName: counterpart == null
            ? null
            : chatDisplayName(counterpart, fallbackId: c.counterpartUserId),
        counterpartPhotoUrl: counterpart?.photoUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatListCubit, ChatListState>(
      builder: (context, state) {
        return state.maybeWhen(
          loaded: (conversations, _, _, _, _, previews, unreadCounts) {
            final shown = conversations
                .where((c) =>
                    c.lastMessageAt != null ||
                    (previews[c.id]?.isNotEmpty ?? false))
                .take(widget.limit)
                .toList(growable: false);
            // Total across every visible conversation (the emitted list is
            // already filtered of cleared/deactivated rows), so Home carries a
            // clear "new messages" signal without a bottom-nav badge.
            final unreadTotal = conversations.fold<int>(
                0, (sum, c) => sum + (unreadCounts[c.id] ?? 0));
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _resolvePreviews(shown, previews);
            });
            return _Card(
              unreadTotal: unreadTotal,
              child: shown.isEmpty
                  ? const _Empty()
                  : Column(
                      children: [
                        for (final c in shown)
                          _RecentRow(
                            conversation: c,
                            counterpart: _counterpartFor(c),
                            preview: _previewLine(c, previews),
                            unread: unreadCounts[c.id] ?? 0,
                            onTap: () => _open(c, _counterpartFor(c)),
                          ),
                      ],
                    ),
            );
          },
          orElse: () => const _Card(unreadTotal: 0, child: _Empty()),
        );
      },
    );
  }
}

/// The titled card shell — "Recent Messages" header + a "View all" affordance.
/// [unreadTotal] draws a small count pill beside the title so Home flags new
/// messages contextually (the bottom nav carries no badge, by decision).
class _Card extends StatelessWidget {
  const _Card({required this.child, this.unreadTotal = 0});
  final Widget child;
  final int unreadTotal;

  @override
  Widget build(BuildContext context) {
    return AppGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.chat_bubble_outline_rounded,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              const Text('Recent Messages', style: AppTypography.h3),
              if (unreadTotal > 0) ...[
                const SizedBox(width: AppSpacing.sm),
                _UnreadCountPill(count: unreadTotal),
              ],
              const Spacer(),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.push(RouteNames.chat),
                child: Row(
                  children: [
                    Text('View all',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textSecondary)),
                    const Icon(Icons.chevron_right_rounded,
                        size: 16, color: AppColors.textTertiary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

/// A compact unread-count pill for the card header — the single, uncluttered
/// "you have new messages" signal on Home. Uses the white primary accent (the
/// same badge language as the per-row count), never a chromatic fill.
class _UnreadCountPill extends StatelessWidget {
  const _UnreadCountPill({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: count == 1 ? '1 unread message' : '$count unread messages',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
        constraints: const BoxConstraints(minWidth: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          count > 99 ? '99+' : '$count',
          style: AppTypography.caption.copyWith(
            color: AppColors.onPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({
    required this.conversation,
    required this.counterpart,
    required this.preview,
    required this.unread,
    required this.onTap,
  });

  final ChatConversationSummary conversation;
  final UserEntity? counterpart;
  final String? preview;
  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = counterpart == null
        ? chatCounterpartLabel(conversation.counterpartUserId)
        : chatDisplayName(counterpart!,
            fallbackId: conversation.counterpartUserId);
    final at = conversation.lastMessageAt;
    final hasUnread = unread > 0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            UserAvatar(
              imageUrl: counterpart?.photoUrl,
              name: name,
              size: 40,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.label.copyWith(
                            fontWeight:
                                hasUnread ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (at != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          relativeTime(at),
                          style: AppTypography.caption.copyWith(
                            color: hasUnread
                                ? AppColors.textSecondary
                                : AppColors.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          preview ?? '…',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: hasUnread
                                ? AppColors.textSecondary
                                : AppColors.textTertiary,
                          ),
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          constraints: const BoxConstraints(minWidth: 18),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.onPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.darkSurfaceElevated,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.forum_outlined,
                size: 18, color: AppColors.textTertiary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'No recent conversations',
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}
