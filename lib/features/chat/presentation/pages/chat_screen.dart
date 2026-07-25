import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/di/injection.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/utils/app_logger.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/drop_empty_state.dart';
import 'package:drop/core/widgets/premium_button.dart';
import 'package:drop/core/widgets/skeleton.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/chat/domain/entities/chat_conversation.dart';
import 'package:drop/features/chat/presentation/chat_format.dart';
import 'package:drop/features/chat/presentation/chat_thread_args.dart';
import 'package:drop/features/chat/presentation/cubit/chat_list_cubit.dart';
import 'package:drop/features/chat/presentation/cubit/chat_list_state.dart';
import 'package:drop/features/chat/presentation/widgets/chat_conversation_tile.dart';

/// Direct-chat inbox — the caller's conversations, most-recent-activity first
/// (server-ordered; the cubit never re-sorts). Mirrors the Cases mobile inbox
/// shape: full-screen first-load spinner, branded empty state, full-screen
/// retry on a data-less failure, pull-to-refresh, and a scroll-driven older
/// page (the NestJS list is cursor-paginated, unlike Cases).
///
/// Tapping a row pushes the conversation route; the thread UI itself is the
/// next phase.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  /// Company-wide user directory keyed by Firebase uid — resolves each row's
  /// `counterpartExternalId` to a real profile (avatar · name · role). Loaded
  /// once per session. Requires the flat `users` read rule to be deployed;
  /// until then a non-admin's directory read is denied and rows fall back to a
  /// neutral label (see `_loadDirectory`).
  // Seed from the session cache so inbox rows render real names on first build
  // (no "Teammate" placeholder flashing to the real name).
  Map<String, UserEntity> _directory = AppDependencies.chatDirectorySnapshot;

  /// Conversation search (client-side, O(n) over the loaded list). [_searching]
  /// toggles the AppBar between the title and an expanding search field;
  /// [_query] is the debounced needle (name / last message / role).
  bool _searching = false;
  String _query = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatListCubit>().load();
      _loadDirectory();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _searchController.clear();
        _query = '';
        _debounce?.cancel();
      }
    });
    if (_searching) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _searchFocus.requestFocus());
    }
  }

  /// Debounced so a fast typist doesn't trigger a filter+rebuild per keystroke.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  /// Filters [conversations] by the current query — matched against the
  /// counterpart's name/role (directory) and the resolved last-message preview.
  /// An empty query returns everything unchanged. Single pass → O(n).
  List<ChatConversationSummary> _applySearch(
    List<ChatConversationSummary> conversations,
    Map<String, String> socketPreviews,
  ) {
    final needle = _query.toLowerCase();
    if (needle.isEmpty) return conversations;
    return conversations.where((c) {
      final user = _counterpartFor(c);
      final name = user == null
          ? ''
          : chatDisplayName(user, fallbackId: c.counterpartUserId);
      final role = user == null ? '' : chatRoleLabel(user.role);
      final preview = _previewLine(c, socketPreviews) ?? '';
      return name.toLowerCase().contains(needle) ||
          role.toLowerCase().contains(needle) ||
          preview.toLowerCase().contains(needle);
    }).toList(growable: false);
  }

  Future<void> _loadDirectory() async {
    // Best-effort enrichment: resolves real names/avatars for the rows. Never
    // let it break the inbox — without it, rows fall back to a neutral label.
    try {
      final user = context.currentUser;
      final dir = await AppDependencies.loadChatDirectory(user);
      if (mounted && dir.isNotEmpty) setState(() => _directory = dir);
    } catch (e) {
      AppLog.warning('chat', 'teammate directory load skipped: $e');
    }
  }

  UserEntity? _counterpartFor(ChatConversationSummary c) {
    final uid = c.counterpartExternalId;
    return uid == null ? null : _directory[uid];
  }

  /// Resolved last-message previews keyed by conversation id — fetched once per
  /// row (thread cache → one-item history) so the inbox shows the real last
  /// message instead of a placeholder. The live socket preview (counterpart
  /// activity) always wins over this when present.
  final Map<String, ChatPreview> _previews = {};
  final Set<String> _previewFetching = {};

  /// The conversations to actually show: WhatsApp/Telegram behavior — an
  /// **empty** conversation (created but never messaged) stays hidden until it
  /// has a real message. "Has a message" = the server set `lastMessageAt`, or a
  /// live socket preview has arrived this session.
  List<ChatConversationSummary> _visible(
      List<ChatConversationSummary> conversations,
      Map<String, String> socketPreviews) {
    return conversations
        .where((c) =>
            c.lastMessageAt != null ||
            (socketPreviews[c.id]?.isNotEmpty ?? false))
        .toList(growable: false);
  }

  /// The preview line for a row: the live socket preview (counterpart's latest,
  /// no "You:") wins; otherwise the resolved last message (which may be mine →
  /// "You: …"). Null while still resolving.
  String? _previewLine(
      ChatConversationSummary c, Map<String, String> socketPreviews) {
    final socket = socketPreviews[c.id];
    if (socket != null && socket.isNotEmpty) return socket;
    return _previews[c.id]?.line;
  }

  /// Fetches the real last message for any visible row that lacks a socket
  /// preview and hasn't been resolved yet. One fetch per conversation; the
  /// thread cache makes most instant (including my own sends, which the socket
  /// never echoes back to me).
  void _resolvePreviews(List<ChatConversationSummary> visible,
      Map<String, String> socketPreviews) {
    for (final c in visible) {
      if (socketPreviews[c.id]?.isNotEmpty ?? false) continue;
      if (_previews.containsKey(c.id) || _previewFetching.contains(c.id)) {
        continue;
      }
      _previewFetching.add(c.id);
      // Derive "mine" per conversation: my internal id is the participant that
      // is not the counterpart. No global "me" needed.
      final myId = c.participantIds
          .firstWhere((p) => p != c.counterpartUserId, orElse: () => '');
      AppDependencies.latestChatMessage(c.id).then((message) {
        if (!mounted) return;
        _previewFetching.remove(c.id);
        if (message == null) return;
        setState(() => _previews[c.id] = ChatPreview(
              chatMessagePreviewText(message),
              mine: myId.isNotEmpty && message.senderId == myId,
            ));
      });
    }
  }

  /// Opens a conversation, then refreshes on return: my own first message is
  /// never delivered to my inbox over the socket (the server excludes my sends),
  /// so a re-pull is how a just-messaged conversation surfaces / updates its
  /// preview. Dropping its cached preview forces a fresh resolve.
  void _openConversation(ChatConversationSummary c, UserEntity? counterpart) {
    final listCubit = context.read<ChatListCubit>();
    listCubit.clearUnread(c.id);
    context
        .push(
      RouteNames.chatConversation(c.id),
      extra: ChatThreadArgs(
        counterpartUserId: c.counterpartUserId,
        counterpartExternalId: c.counterpartExternalId,
        counterpartName: counterpart == null
            ? null
            : chatDisplayName(counterpart, fallbackId: c.counterpartUserId),
        counterpartPhotoUrl: counterpart?.photoUrl,
      ),
    )
        .then((_) {
      if (!mounted) return;
      _previews.remove(c.id);
      listCubit.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: 'Chat',
      subtitle: _searching ? null : 'Direct messages with your team',
      titleWidget: _searching
          ? _ChatSearchField(
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: _onSearchChanged,
            )
          : null,
      actions: [
        IconButton(
          tooltip: _searching ? 'Close search' : 'Search conversations',
          icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded,
              color: AppColors.textSecondary),
          onPressed: _toggleSearch,
        ),
      ],
      // Always-available entry to the teammate picker (even with conversations
      // present); the empty state also offers it as a primary CTA.
      floatingActionButton: FloatingActionButton.extended(
        // A conversation messaged during the new-chat flow only surfaces on a
        // re-pull (my own send isn't delivered to my inbox over the socket).
        onPressed: () => context.push(RouteNames.chatNew).then((_) {
          if (context.mounted) context.read<ChatListCubit>().refresh();
        }),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.chat_bubble_outline_rounded),
        label: const Text('New Chat'),
      ),
      body: BlocConsumer<ChatListCubit, ChatListState>(
        // A failure while a list is on screen is transient (the cubit
        // immediately re-emits the last loaded list) — surface it as a
        // snackbar instead of losing the data. A first-load failure falls
        // through to the full-screen retry below.
        listenWhen: (prev, next) =>
            next.maybeMap(error: (_) => true, orElse: () => false) &&
            prev.maybeMap(loaded: (_) => true, orElse: () => false),
        listener: (context, state) {
          state.mapOrNull(
            error: (e) => ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(e.message))),
          );
        },
        builder: (context, state) {
          return state.when(
            initial: () => const _Loading(),
            loading: () => const _Loading(),
            error: (message) => _ErrorView(
              message: message,
              onRetry: () => context.read<ChatListCubit>().refresh(),
            ),
            loaded: (conversations, refreshing, loadingMore, hasMore, _,
                previews, unreadCounts) {
              // Hide empty (never-messaged) conversations, then resolve real
              // previews for what remains (post-frame — never setState in build).
              final visible = _visible(conversations, previews);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _resolvePreviews(visible, previews);
              });
              // Apply the search filter on top (empty query → everything).
              final filtered = _applySearch(visible, previews);
              return RefreshIndicator(
                onRefresh: () => context.read<ChatListCubit>().refresh(),
                color: AppColors.primary,
                child: visible.isEmpty
                    ? DropEmptyState(
                        title: 'No conversations yet',
                        message:
                            'Direct messages with your teammates will appear here.',
                        action: PremiumButton(
                          label: 'Start Chat',
                          icon: Icons.chat_bubble_outline_rounded,
                          style: PremiumButtonStyle.filled,
                          onPressed: () =>
                              context.push(RouteNames.chatNew).then((_) {
                            if (context.mounted) {
                              context.read<ChatListCubit>().refresh();
                            }
                          }),
                        ),
                      )
                    : filtered.isEmpty
                        ? const _NoSearchResults()
                        : _ConversationList(
                            conversations: filtered,
                            loadingMore: loadingMore,
                            hasMore: hasMore,
                            unreadCounts: unreadCounts,
                            counterpartOf: _counterpartFor,
                            previewOf: (c) => _previewLine(c, previews),
                            onOpen: _openConversation,
                          ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({
    required this.conversations,
    required this.loadingMore,
    required this.hasMore,
    required this.unreadCounts,
    required this.counterpartOf,
    required this.previewOf,
    required this.onOpen,
  });

  final List<ChatConversationSummary> conversations;
  final bool loadingMore;
  final bool hasMore;
  final Map<String, int> unreadCounts;

  /// Resolves a row's counterpart to a real teammate profile (company dir).
  final UserEntity? Function(ChatConversationSummary) counterpartOf;

  /// The resolved last-message preview line for a row (socket → history).
  final String? Function(ChatConversationSummary) previewOf;

  /// Opens a conversation (handles unread-clear + refresh-on-return).
  final void Function(ChatConversationSummary, UserEntity?) onOpen;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // Near the bottom → pull the next (older-activity) page. The cubit
        // no-ops while a page is in flight or when the cursor is exhausted.
        if (hasMore && notification.metrics.extentAfter < 400) {
          context.read<ChatListCubit>().loadMore();
        }
        return false;
      },
      child: ListView.separated(
        // Preserves scroll offset across search toggles / rebuilds.
        key: const PageStorageKey('chat_inbox_list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 6, bottom: AppSpacing.huge),
        itemCount: conversations.length + (loadingMore ? 1 : 0),
        // Hairline inset past the avatar (WhatsApp/iMessage rhythm) — subtle,
        // never a heavy full-width rule.
        separatorBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(left: 90),
          child: Divider(
              height: 0.5,
              thickness: 0.5,
              color: AppColors.darkBorder.withValues(alpha: 0.6)),
        ),
        itemBuilder: (context, index) {
          if (index == conversations.length) return const _PageSpinnerRow();
          final conversation = conversations[index];
          final counterpart = counterpartOf(conversation);
          return ChatConversationTile(
            conversation: conversation,
            counterpart: counterpart,
            preview: previewOf(conversation),
            unreadCount: unreadCounts[conversation.id],
            onTap: () => onOpen(conversation, counterpart),
          );
        },
      ),
    );
  }
}

class _PageSpinnerRow extends StatelessWidget {
  const _PageSpinnerRow();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primary),
          ),
        ),
      );
}

/// Skeleton inbox — a handful of shimmering conversation-tile placeholders,
/// matching the real tile's avatar + two-line layout, so a cold load reads as
/// "loading this list" rather than a bare spinner.
class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 6),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 8,
      separatorBuilder: (_, _) => const Padding(
        padding: EdgeInsets.only(left: 90),
        child: Divider(height: 0.5, thickness: 0.5, color: AppColors.darkBorder),
      ),
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePadding, vertical: 12),
        child: Row(
          children: [
            const Skeleton(
                width: 52, height: 52, borderRadius: BorderRadius.all(Radius.circular(26))),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Skeleton(
                    width: 120 + (index % 3) * 40,
                    height: 13,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  const SizedBox(height: 8),
                  Skeleton(
                    width: 200 + (index % 2) * 40,
                    height: 11,
                    borderRadius: BorderRadius.circular(5),
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

/// The AppBar search field shown while searching — monochrome, borderless, with
/// a clear affordance. Filtering happens live (debounced) as the user types.
class _ChatSearchField extends StatelessWidget {
  const _ChatSearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: AppTypography.body,
      cursorColor: AppColors.primary,
      decoration: const InputDecoration(
        hintText: 'Search conversations',
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

/// Empty state for a search that matched nothing (distinct from the "no
/// conversations yet" first-run state). Scrollable so pull-to-refresh still
/// works over it.
class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults();

  @override
  Widget build(BuildContext context) {
    return const DropEmptyState(
      title: 'No conversations found.',
      message: 'Try a different name or message.',
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.textTertiary, size: 40),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
