import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/di/injection.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/user_avatar.dart';
import 'package:drop/features/chat/domain/entities/chat_message.dart';
import 'package:drop/features/chat/presentation/chat_format.dart';
import 'package:drop/features/chat/presentation/chat_thread_args.dart';
import 'package:drop/features/chat/presentation/cubit/chat_conversation_cubit.dart';
import 'package:drop/features/chat/presentation/cubit/chat_conversation_state.dart';
import 'package:drop/features/chat/presentation/pages/conversation_info_screen.dart';
import 'package:drop/features/chat/presentation/widgets/chat_conversation_view.dart';

/// One open direct-chat thread — a per-thread [ChatConversationCubit] (owned by
/// this State, so the AppBar's menu/search can drive it) under an
/// [AdaptiveScaffold]. The header shows the counterpart's avatar + name; the
/// AppBar carries in-conversation **search** and a **three-dot menu**
/// (Conversation info · Search · Mute · Clear chat · Delete).
class ChatConversationScreen extends StatefulWidget {
  const ChatConversationScreen({
    super.key,
    required this.conversationId,
    this.args,
  });

  final String conversationId;

  /// Resolved counterpart (name/avatar) + ids, passed by the opener (inbox /
  /// picker). A bare deep link arrives without it → generic header.
  final ChatThreadArgs? args;

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  late final ChatConversationCubit _cubit;

  // ── In-conversation search ──
  bool _searching = false;
  String _searchQuery = '';
  int _matchIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;

  // ── Local (UI-ready) mute ──
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _cubit = AppDependencies.createChatConversationCubit(
      widget.conversationId,
      counterpartUserId: widget.args?.counterpartUserId,
    );
    // Mark this conversation as the one on screen so the global in-app
    // notification listener suppresses banners for it.
    AppDependencies.activeChatConversation.value = widget.conversationId;
  }

  @override
  void dispose() {
    if (AppDependencies.activeChatConversation.value == widget.conversationId) {
      AppDependencies.activeChatConversation.value = null;
    }
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _cubit.close();
    super.dispose();
  }

  String get _name {
    final n = widget.args?.counterpartName?.trim();
    if (n != null && n.isNotEmpty) return n;
    final id = widget.args?.counterpartUserId;
    return id == null ? 'Conversation' : chatCounterpartLabel(id);
  }

  // ── Search ──────────────────────────────────────────────────────────────

  void _openSearch() {
    setState(() => _searching = true);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _searchFocus.requestFocus());
  }

  void _closeSearch() {
    setState(() {
      _searching = false;
      _searchQuery = '';
      _matchIndex = 0;
      _searchController.clear();
      _debounce?.cancel();
    });
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = value.trim();
        _matchIndex = 0;
      });
    });
  }

  /// Ids of the loaded messages whose text matches the query — computed live
  /// from the cubit's current state (pure; no side effects).
  List<String> get _matches {
    final q = _searchQuery.toLowerCase();
    if (q.isEmpty) return const [];
    final messages = _cubit.state.maybeMap(
      loaded: (s) => s.messages,
      orElse: () => const <ChatMessage>[],
    );
    return [
      for (final m in messages)
        if (!m.deletedForEveryone &&
            (m.body ?? '').toLowerCase().contains(q))
          m.id,
    ];
  }

  String? _activeMatchId(List<String> matches) {
    if (matches.isEmpty) return null;
    final i = _matchIndex.clamp(0, matches.length - 1);
    return matches[i];
  }

  void _jump(int delta, int count) {
    if (count == 0) return;
    setState(() => _matchIndex = (_matchIndex + delta) % count < 0
        ? (_matchIndex + delta) % count + count
        : (_matchIndex + delta) % count);
  }

  // ── Menu actions ──────────────────────────────────────────────────────────

  void _openInfo() {
    final counts = _cubit.sharedAttachmentCounts;
    ConversationInfoScreen.push(
      context,
      name: _name,
      photoUrl: widget.args?.counterpartPhotoUrl,
      counterpartExternalId: widget.args?.counterpartExternalId,
      mediaCount: counts.media,
      documentCount: counts.documents,
      muted: _muted,
      onSearch: _openSearch,
      onToggleMute: _toggleMute,
      onClear: _confirmClear,
      onDelete: _confirmDelete,
    );
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    context.showInfo(_muted ? 'Conversation muted' : 'Conversation unmuted');
  }

  Future<void> _confirmClear() async {
    final ok = await _confirmDestructive(
      title: 'Clear chat history?',
      body: 'This removes every message from your view only — the other person '
          'still has their copy. This cannot be undone.',
      confirmLabel: 'Clear',
    );
    if (!ok || !mounted) return;
    final cleared = await _cubit.clearChatForMe();
    if (cleared && mounted) context.showSuccess('Chat cleared');
  }

  Future<void> _confirmDelete() async {
    final ok = await _confirmDestructive(
      title: 'Delete conversation?',
      body: 'This clears the conversation for you and closes it. The other '
          'person keeps their copy. This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return;
    final cleared = await _cubit.clearChatForMe();
    if (cleared && mounted) Navigator.of(context).pop();
  }

  Future<bool> _confirmDestructive({
    required String title,
    required String body,
    required String confirmLabel,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.darkSurfaceElevated,
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return ok == true;
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ChatConversationCubit>.value(
      value: _cubit,
      // Rebuild the AppBar's live match count as messages/search change.
      child: BlocBuilder<ChatConversationCubit, ChatConversationState>(
        builder: (context, _) {
          final matches = _matches;
          final activeId = _searching ? _activeMatchId(matches) : null;
          return AdaptiveScaffold(
            title: _name,
            titleWidget: _searching
                ? _SearchField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    onChanged: _onSearchChanged,
                    // Enter jumps to the next match (keyboard navigation).
                    onSubmitted: () => _jump(1, matches.length),
                  )
                : _Header(
                    name: _name, photoUrl: widget.args?.counterpartPhotoUrl),
            leading: _searching
                ? IconButton(
                    tooltip: 'Close search',
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: _closeSearch,
                  )
                : null,
            actions: _searching
                ? _searchActions(matches)
                : _menuActions(),
            bottom: _searching && _searchQuery.isNotEmpty && matches.isEmpty
                ? const _NoMatchesBar()
                : null,
            contentMaxWidth: 820,
            body: ChatConversationView(
              counterpartName: widget.args?.counterpartName,
              attachmentSource: AppDependencies.chatAttachmentSource,
              searchQuery: _searching ? _searchQuery : null,
              activeMatchId: activeId,
            ),
          );
        },
      ),
    );
  }

  List<Widget> _searchActions(List<String> matches) {
    final count = matches.length;
    return [
      if (count > 0)
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '${_matchIndex.clamp(0, count - 1) + 1}/$count',
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
        ),
      IconButton(
        tooltip: 'Previous match',
        icon: const Icon(Icons.keyboard_arrow_up_rounded),
        onPressed: count == 0 ? null : () => _jump(-1, count),
      ),
      IconButton(
        tooltip: 'Next match',
        icon: const Icon(Icons.keyboard_arrow_down_rounded),
        onPressed: count == 0 ? null : () => _jump(1, count),
      ),
    ];
  }

  List<Widget> _menuActions() {
    return [
      IconButton(
        tooltip: 'Search in conversation',
        icon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
        onPressed: _openSearch,
      ),
      PopupMenuButton<_ConvMenu>(
        tooltip: 'Conversation options',
        icon: const Icon(Icons.more_vert_rounded,
            color: AppColors.textSecondary),
        color: AppColors.darkSurfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
        onSelected: (m) {
          switch (m) {
            case _ConvMenu.info:
              _openInfo();
            case _ConvMenu.search:
              _openSearch();
            case _ConvMenu.mute:
              _toggleMute();
            case _ConvMenu.clear:
              _confirmClear();
            case _ConvMenu.delete:
              _confirmDelete();
          }
        },
        itemBuilder: (context) => [
          _menuItem(_ConvMenu.info, Icons.info_outline_rounded,
              'Conversation info'),
          _menuItem(_ConvMenu.search, Icons.search_rounded,
              'Search in conversation'),
          _menuItem(
            _ConvMenu.mute,
            _muted
                ? Icons.notifications_off_rounded
                : Icons.notifications_none_rounded,
            _muted ? 'Unmute conversation' : 'Mute conversation',
          ),
          _menuItem(_ConvMenu.clear, Icons.cleaning_services_outlined,
              'Clear chat history'),
          _menuItem(_ConvMenu.delete, Icons.delete_outline_rounded,
              'Delete conversation',
              destructive: true),
        ],
      ),
    ];
  }

  PopupMenuItem<_ConvMenu> _menuItem(
    _ConvMenu value,
    IconData icon,
    String label, {
    bool destructive = false,
  }) {
    final color = destructive ? AppColors.error : AppColors.textPrimary;
    return PopupMenuItem<_ConvMenu>(
      value: value,
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

enum _ConvMenu { info, search, mute, clear, delete }

/// The AppBar search field for in-conversation search.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onSubmitted: (_) => onSubmitted(),
      textInputAction: TextInputAction.search,
      style: AppTypography.body,
      cursorColor: AppColors.primary,
      decoration: const InputDecoration(
        hintText: 'Search messages',
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

/// The thin "No matching messages." bar shown under the AppBar when a search
/// query matches nothing.
class _NoMatchesBar extends StatelessWidget implements PreferredSizeWidget {
  const _NoMatchesBar();

  @override
  Size get preferredSize => const Size.fromHeight(34);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      width: double.infinity,
      alignment: Alignment.center,
      color: AppColors.darkSurface,
      child: Text(
        'No matching messages.',
        style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
      ),
    );
  }
}

/// Avatar + name lockup for the thread app bar.
class _Header extends StatelessWidget {
  const _Header({required this.name, this.photoUrl});
  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        UserAvatar(imageUrl: photoUrl, name: name, size: 32),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(name,
              style: AppTypography.h3,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
