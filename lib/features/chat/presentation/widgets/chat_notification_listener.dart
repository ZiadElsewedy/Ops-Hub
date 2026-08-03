import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/di/injection.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/utils/app_logger.dart';
import 'package:drop/core/utils/platform_capabilities.dart';
import 'package:drop/core/widgets/user_avatar.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:drop/features/auth/presentation/cubit/auth_state.dart';
import 'package:drop/features/chat/presentation/chat_format.dart';
import 'package:drop/features/chat/presentation/chat_thread_args.dart';
import 'package:drop/features/chat/presentation/cubit/chat_list_cubit.dart';

/// App-wide in-app message notifications. Mounted once above the router (via
/// `MaterialApp.router`'s builder) so a new chat message raises a tappable
/// banner from **any** screen — except the conversation the user is already
/// viewing (tracked by [AppDependencies.activeChatConversation]).
///
/// Works on every platform, desktop included (the banner is the desktop
/// notification here; a true OS-level notification would need a native
/// local-notifications plugin + per-platform setup, out of scope). Subscribes
/// to [ChatListCubit.incoming]; ensures the inbox is loaded once authenticated
/// so the shared socket is connected and events actually flow.
class ChatNotificationListener extends StatefulWidget {
  const ChatNotificationListener({
    super.key,
    required this.child,
    required this.router,
    this.suppressBanner,
  });

  final Widget child;

  /// Overrides the platform decision about whether the OS banner already covers
  /// an incoming chat message (see [suppressesInAppChatBanner]). Production
  /// leaves this null and takes the platform default; tests set it explicitly,
  /// since `Platform` cannot be varied from a widget test.
  final bool? suppressBanner;

  /// The app router. This widget is mounted in `MaterialApp.router`'s `builder`,
  /// which sits **above** the `GoRouter` in the tree, so `context.push` here
  /// throws "No GoRouter found in context". Navigating through the router
  /// instance directly is the only correct path from above the router.
  final GoRouter router;

  @override
  State<ChatNotificationListener> createState() =>
      _ChatNotificationListenerState();
}

class _ChatNotificationListenerState extends State<ChatNotificationListener> {
  StreamSubscription<ChatIncomingMessage>? _sub;
  // Seed from the session cache so a banner shows the real sender name on the
  // first render instead of a "Teammate" placeholder.
  Map<String, UserEntity> _directory = AppDependencies.chatDirectorySnapshot;

  @override
  void initState() {
    super.initState();
    _sub = context.read<ChatListCubit>().incoming.listen(_onIncoming);
    // If a session is already live (hot reload / already signed in), warm the
    // inbox now so the socket is connected app-wide.
    if (context.read<AuthCubit>().state.maybeWhen(
          authenticated: (_) => true,
          orElse: () => false,
        )) {
      _activate();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// Loads the inbox (idempotent → connects the socket) and the directory used
  /// to resolve sender names in banners. Best-effort.
  void _activate() {
    context.read<ChatListCubit>().load();
    _loadDirectory();
  }

  Future<void> _loadDirectory() async {
    try {
      final dir = await AppDependencies.loadChatDirectory(context.currentUser);
      if (mounted && dir.isNotEmpty) setState(() => _directory = dir);
    } catch (e) {
      AppLog.warning('chat', 'notification directory skipped: $e');
    }
  }

  void _onIncoming(ChatIncomingMessage event) {
    if (!mounted) return;
    // Suppress a banner for the conversation currently on screen.
    if (AppDependencies.activeChatConversation.value == event.conversationId) {
      return;
    }
    // A chat message now arrives by TWO paths — this socket and an FCM push
    // from the chat backend. On Apple platforms the OS draws its own foreground
    // banner (NotificationService enables it for every route), so raising this
    // one as well would notify twice for the same message. There the OS banner
    // wins and this stands down; Android keeps the in-app banner, because a
    // foreground push there reaches `onMessage` only and the OS draws nothing.
    if (widget.suppressBanner ?? suppressesInAppChatBanner) return;
    final user = event.counterpartExternalId == null
        ? null
        : _directory[event.counterpartExternalId];
    final name =
        user == null ? 'New message' : (user.displayName ?? user.email);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.darkSurfaceElevated,
          duration: const Duration(seconds: 4),
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: const BorderSide(color: AppColors.darkBorder),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          content: _NotificationBody(
            name: name,
            photoUrl: user?.photoUrl,
            preview: event.preview,
            onTap: () => _open(event.conversationId),
          ),
        ),
      );
  }

  void _open(String conversationId) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final cubit = context.read<ChatListCubit>();
    cubit.clearUnread(conversationId);
    final summary = cubit.conversationById(conversationId);
    final counterpart = summary?.counterpartExternalId == null
        ? null
        : _directory[summary!.counterpartExternalId];
    widget.router.push(
      RouteNames.chatConversation(conversationId),
      extra: summary == null
          ? null
          : ChatThreadArgs(
              counterpartUserId: summary.counterpartUserId,
              counterpartExternalId: summary.counterpartExternalId,
              counterpartName: counterpart == null
                  ? null
                  : chatDisplayName(counterpart,
                      fallbackId: summary.counterpartUserId),
              counterpartPhotoUrl: counterpart?.photoUrl,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      // On a fresh sign-in, connect the inbox socket + load the directory.
      listenWhen: (prev, next) =>
          next.maybeWhen(authenticated: (_) => true, orElse: () => false) &&
          !prev.maybeWhen(authenticated: (_) => true, orElse: () => false),
      listener: (context, _) => _activate(),
      child: widget.child,
    );
  }
}

/// The banner content: avatar · sender name · one-line preview. Tapping opens
/// the conversation.
class _NotificationBody extends StatelessWidget {
  const _NotificationBody({
    required this.name,
    required this.preview,
    required this.onTap,
    this.photoUrl,
  });

  final String name;
  final String preview;
  final String? photoUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        children: [
          UserAvatar(imageUrl: photoUrl, name: name, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 1),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded,
              size: 18, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}
