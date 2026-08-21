import 'dart:async';

import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/glass_container.dart';

/// One in-app notification to surface while the app is open — a foreground push
/// (task approval, swap request, …) that would otherwise only reach the
/// notification inbox. [data] is the push payload, so a tap can deep-link to the
/// same place a background tap would.
class InAppNotification {
  const InAppNotification({
    required this.title,
    this.body,
    this.data = const {},
  });

  final String title;
  final String? body;
  final Map<String, dynamic> data;
}

/// App-wide host for in-app foreground notifications — a polished banner that
/// **slides down from the top**, not the bottom snackbar that was there before
/// (removed on request as "ugly"). Mounted once above the router (beside
/// [ChatUnreadLaunchHint]), so it can appear over whatever screen is on.
///
/// Foreground pushes reach it through the static [show] channel (the FCM
/// `onForeground` handler calls it); tapping the banner routes through [onOpen]
/// with the push payload. The banner auto-dismisses, and a newer notification
/// replaces the current one (resetting the timer) rather than stacking.
///
/// Deliberately distinct from [ChatNotificationListener]: chat messages already
/// have their own richer (avatar + name) banner. This is the generic surface for
/// everything else.
class InAppNotificationHost extends StatefulWidget {
  const InAppNotificationHost({
    super.key,
    required this.child,
    required this.onOpen,
    this.visibleFor = const Duration(milliseconds: 4200),
  });

  final Widget child;

  /// Navigates to the notification's destination (resolved from its payload).
  final void Function(Map<String, dynamic> data) onOpen;

  /// How long the banner stays before dismissing itself.
  final Duration visibleFor;

  static final StreamController<InAppNotification> _controller =
      StreamController<InAppNotification>.broadcast();

  /// Raises an in-app notification banner. Best-effort — a closed controller
  /// (teardown) is ignored; no-op when no host is mounted (desktop/tests).
  static void show(InAppNotification notification) {
    if (!_controller.isClosed) _controller.add(notification);
  }

  @override
  State<InAppNotificationHost> createState() => _InAppNotificationHostState();
}

class _InAppNotificationHostState extends State<InAppNotificationHost>
    with SingleTickerProviderStateMixin {
  StreamSubscription<InAppNotification>? _sub;
  InAppNotification? _current;
  Timer? _dismissTimer;

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
    _sub = InAppNotificationHost._controller.stream.listen(_onNotification);
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _sub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  bool get _reduceMotion =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  void _onNotification(InAppNotification n) {
    if (!mounted) return;
    _dismissTimer?.cancel();
    setState(() => _current = n);
    if (_reduceMotion) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
    _dismissTimer = Timer(widget.visibleFor, _dismiss);
  }

  void _dismiss() {
    _dismissTimer?.cancel();
    if (!mounted) return;
    if (_reduceMotion) {
      _controller.value = 0;
      setState(() => _current = null);
      return;
    }
    _controller.reverse().whenComplete(() {
      if (mounted) setState(() => _current = null);
    });
  }

  void _open() {
    final n = _current;
    _dismiss();
    if (n != null) widget.onOpen(n.data);
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    return Stack(
      children: [
        widget.child,
        if (current != null)
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
                    child: _NotificationBanner(
                      notification: current,
                      onTap: _open,
                      onDismiss: _dismiss,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The banner: bell medallion · title · one-line body · dismiss. Tapping the
/// body opens the item; the × dismisses without navigating.
class _NotificationBanner extends StatelessWidget {
  const _NotificationBanner({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  final InAppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final body = notification.body?.trim() ?? '';
    return Material(
      type: MaterialType.transparency,
      child: GlassContainer(
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
                Icons.notifications_rounded,
                size: 16,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              tooltip: 'Dismiss',
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              color: AppColors.textTertiary,
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
