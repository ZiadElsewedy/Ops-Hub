import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:opshub/core/routes/route_names.dart';
import 'package:opshub/core/routes/router_extensions.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/glass_container.dart';
import 'package:opshub/features/chat/presentation/cubit/chat_list_cubit.dart';
import 'package:opshub/features/chat/presentation/cubit/chat_list_state.dart';

/// The one-per-launch "you have unread messages" hint — a small banner that
/// slides down from the top, says how much is waiting, and dismisses itself.
///
/// Mounted once above the router (`MaterialApp.router`'s builder, beside
/// [ChatNotificationListener]) so it can appear over whatever screen the launch
/// lands on. It **observes only**: the inbox load it reads is the one
/// [ChatNotificationListener] already triggers on authentication, so this costs
/// no extra request.
///
/// It fires on the **first settled** [ChatListState.loaded] of the launch — the
/// one that carries the server's own `unreadCount`s. A cold-start paint from the
/// durable cache arrives first with `refreshing: true` and no counts; announcing
/// off that would say "0 unread" on every launch. Consuming exactly one settled
/// emission is also what makes it once-per-launch: a message that arrives later
/// is [ChatNotificationListener]'s job, not this one's.
///
/// Deliberately **not** a badge. The bottom nav carries no unread dot and must
/// not grow one — this hint is the whole of the launch-time signal, and it
/// leaves on its own.
///
/// Suppressed when the launch lands anywhere under `/chat`: telling a reader
/// looking at their inbox that they have unread messages is noise.
///
/// > A sign-out and second sign-in inside one launch does not re-arm it. "Once
/// > per app launch" is the rule; the incoming-message banner covers the second
/// > user from there.
class ChatUnreadLaunchHint extends StatefulWidget {
  const ChatUnreadLaunchHint({
    super.key,
    required this.child,
    required this.router,
    this.visibleFor = const Duration(milliseconds: 3500),
  });

  final Widget child;

  /// The app router. This widget sits **above** the `GoRouter` in the tree, so
  /// `context.push` here throws "No GoRouter found in context" — navigating
  /// through the instance is the only correct path from above the router.
  final GoRouter router;

  /// How long the banner stays before dismissing itself.
  final Duration visibleFor;

  @override
  State<ChatUnreadLaunchHint> createState() => _ChatUnreadLaunchHintState();
}

class _ChatUnreadLaunchHintState extends State<ChatUnreadLaunchHint>
    with SingleTickerProviderStateMixin {
  /// The launch snapshot has been consumed — nothing shows after this, whatever
  /// the inbox does next.
  bool _decided = false;
  int _unread = 0;
  Timer? _dismissTimer;

  // Built eagerly, not lazily: `dispose` must never be the first touch, or a
  // hint that never fired would build a controller against an unmounted ticker.
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));
    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChatList(BuildContext context, ChatListState state) {
    if (_decided) return;
    final unread = state.maybeMap(
      // `refreshing` marks the durable-cache paint, whose summaries carry no
      // server counts yet. Wait for the settled load — that is the launch
      // snapshot.
      loaded: (s) => s.refreshing
          ? null
          : s.unreadCounts.values.fold<int>(0, (sum, n) => sum + n),
      orElse: () => null,
    );
    if (unread == null) return;

    _decided = true;
    if (unread <= 0) return;
    // Already reading chat — the hint would be telling them what they can see.
    // The *top* location, not the routed one: chat is always reached by an
    // imperative push, which never rewrites the match list's uri.
    final location = widget.router.topLocationOrNull;
    if (location != null && location.startsWith(RouteNames.chat)) return;

    setState(() => _unread = unread);
    if (_reduceMotion) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
    _dismissTimer = Timer(widget.visibleFor, _dismiss);
  }

  bool get _reduceMotion =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  void _dismiss() {
    _dismissTimer?.cancel();
    if (!mounted) return;
    if (_reduceMotion) {
      _controller.value = 0;
      setState(() => _unread = 0);
      return;
    }
    _controller.reverse().whenComplete(() {
      if (mounted) setState(() => _unread = 0);
    });
  }

  void _openChat() {
    _dismiss();
    // The same destination the bottom nav's Chat tab pushes — the inbox on top
    // of the role home, so Back returns where the launch landed.
    widget.router.whenReady(() {
      if (widget.router.topLocationOrNull == RouteNames.chat) return;
      widget.router.push(RouteNames.chat);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChatListCubit, ChatListState>(
      listenWhen: (_, _) => !_decided,
      listener: _onChatList,
      child: Stack(
        children: [
          widget.child,
          if (_unread > 0)
            Positioned(
              top: MediaQuery.paddingOf(context).top + AppSpacing.sm,
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: Align(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: _UnreadHintBanner(
                        unread: _unread,
                        onTap: _openChat,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The banner itself: chat glyph · count line · "Tap to open Chat."
class _UnreadHintBanner extends StatelessWidget {
  const _UnreadHintBanner({required this.unread, required this.onTap});

  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final headline = unread == 1
        ? 'You have 1 unread message.'
        : 'You have $unread unread messages.';
    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        button: true,
        label: '$headline Tap to open Chat.',
        onTap: onTap,
        child: ExcludeSemantics(
          child: GlassContainer(
            onTap: onTap,
            borderRadius: AppRadius.lgAll,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 10,
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: AppColors.primarySurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chat_bubble_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.label.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Tap to open Chat.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
