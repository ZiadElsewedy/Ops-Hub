import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/app_dialog.dart';
import 'package:drop/core/widgets/app_empty_state.dart';
import 'package:drop/core/widgets/drop_empty_state.dart';
import 'package:drop/core/widgets/app_motion.dart';
import 'package:drop/core/widgets/list_skeleton.dart';
import 'package:drop/features/notifications/domain/entities/notification_entity.dart';
import 'package:drop/features/notifications/domain/notification_deep_link.dart';
import 'package:drop/features/notifications/presentation/cubit/notification_cubit.dart';
import 'package:drop/features/notifications/presentation/cubit/notification_state.dart';
import 'package:drop/features/notifications/presentation/notification_format.dart';
import 'package:drop/features/notifications/presentation/widgets/notification_tile.dart';

/// The in-app Notification Center — an **operations workflow inbox** (§5). Not a
/// flat feed: notifications are **grouped by time** (Today / Yesterday / Earlier),
/// **filtered by category** (All / Tasks / Reviews / Broadcast), and **ordered by
/// priority** within each section so what needs acting on floats up. Swipe right
/// to mark read, swipe left to archive (delete in the Archived view); bulk
/// Mark-all-read / Clear-archived; every tile deep-links to its destination.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _scroll = ScrollController();
  NotificationCategory _category = NotificationCategory.all;
  bool _showArchived = false;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.currentUser?.uid;
      if (uid != null) context.read<NotificationCubit>().load(uid);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    final cubit = context.read<NotificationCubit>();
    if (!cubit.hasMore) return;
    setState(() => _loadingMore = true);
    await cubit.loadMore();
    if (mounted) setState(() => _loadingMore = false);
  }

  void _onTap(NotificationEntity n) {
    final cubit = context.read<NotificationCubit>();
    if (n.isUnread) cubit.markRead(n.id);
    _deepLink(n);
  }

  /// A task / review notification opens the **exact task** (its details screen
  /// carries the review surface); a broadcast opens its detail for admin/manager;
  /// a case/request opens its thread (or the list if the id is gone). Routing is
  /// delegated to the shared [resolveNotificationRoute] resolver so an in-app tap
  /// lands on exactly the same destination as an FCM push tap. A `null` result is
  /// a guarded no-op (no safe target) — the inbox simply stays put.
  void _deepLink(NotificationEntity n) {
    final location = resolveNotificationRoute(
      route: n.route,
      payload: n.payload,
      role: context.currentRole,
    );
    if (location != null) context.push(location);
  }

  /// The notifications in view: the archived set (Archived view) or the live
  /// inbox, then narrowed to the active category.
  List<NotificationEntity> _visible(List<NotificationEntity> items) => items
      .where((n) => n.isArchived == _showArchived)
      .where((n) => _category.matches(n.type))
      .toList();

  Future<void> _onSwipeRead(NotificationEntity n) async {
    if (n.isUnread) {
      HapticFeedback.selectionClick();
      await context.read<NotificationCubit>().markRead(n.id);
    }
  }

  Future<void> _onSwipeArchiveOrDelete(NotificationEntity n) async {
    HapticFeedback.mediumImpact();
    final cubit = context.read<NotificationCubit>();
    // Inbox → archive (returns to the Archived view); Archived → delete forever.
    if (_showArchived) {
      await cubit.delete(n.id);
    } else {
      await cubit.setArchived(n.id, true);
    }
  }

  Future<void> _clearArchived() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Clear archived?',
      message: 'Permanently delete all archived notifications.',
      confirmLabel: 'Clear',
      destructive: true,
    );
    if (ok && mounted) context.read<NotificationCubit>().clearArchived();
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: _showArchived ? 'Archived' : 'Notifications',
      // Two-line lockup — the title anchored by a live status line (unread count
      // in the inbox, archived count in the Archived view) so the inbox states
      // where it stands the moment it opens.
      titleWidget: _HeaderLockup(showArchived: _showArchived),
      contentMaxWidth: 760, // a chronological inbox reads best in a narrow column
      actions: [
        if (_showArchived)
          TextButton(
            onPressed: _clearArchived,
            child: Text('Clear',
                style: AppTypography.caption.copyWith(color: AppColors.error)),
          )
        else
          BlocBuilder<NotificationCubit, NotificationState>(
            builder: (context, _) {
              final hasUnread =
                  context.read<NotificationCubit>().unreadCount > 0;
              if (!hasUnread) return const SizedBox.shrink();
              return TextButton(
                onPressed: () =>
                    context.read<NotificationCubit>().markAllRead(),
                child: Text('Mark all read',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.accent)),
              );
            },
          ),
        IconButton(
          tooltip: _showArchived ? 'Inbox' : 'Archived',
          icon: Icon(
            _showArchived ? Icons.inbox_outlined : Icons.archive_outlined,
            color: AppColors.textSecondary,
          ),
          onPressed: () => setState(() => _showArchived = !_showArchived),
        ),
      ],
      body: BlocBuilder<NotificationCubit, NotificationState>(
        builder: (context, state) => state.maybeWhen(
          loading: () => const ListSkeleton(),
          loaded: (items) => _content(items),
          error: (_) => _errorState(),
          orElse: () => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _content(List<NotificationEntity> items) {
    final sections = groupByTime(_visible(items), DateTime.now());
    return Column(
      children: [
        _FilterBar(
          category: _category,
          onSelect: (c) {
            HapticFeedback.selectionClick();
            setState(() => _category = c);
          },
        ),
        Expanded(child: sections.isEmpty ? _empty() : _list(sections)),
      ],
    );
  }

  Widget _list(List<NotificationSection> sections) {
    final cubit = context.read<NotificationCubit>();
    var animIndex = 0;
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(AppSpacing.pagePadding, AppSpacing.sm,
          AppSpacing.pagePadding, AppSpacing.xxxl),
      children: [
        for (final section in sections) ...[
          Padding(
            padding:
                const EdgeInsets.fromLTRB(2, AppSpacing.md, 0, AppSpacing.sm),
            child: Text(section.title.toUpperCase(),
                style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary, letterSpacing: 0.6)),
          ),
          for (final n in section.items)
            EntranceFade(
              delay: staggerDelay(animIndex++),
              child: Dismissible(
                key: ValueKey(n.id),
                background: _readBg(),
                secondaryBackground: _trailingBg(),
                confirmDismiss: (direction) async {
                  // Both actions keep the widget in the tree (return false): the
                  // live stream re-emits without it, avoiding a dismissed-widget
                  // assertion. The swipe springs back, then the list updates.
                  if (direction == DismissDirection.startToEnd) {
                    await _onSwipeRead(n);
                  } else {
                    await _onSwipeArchiveOrDelete(n);
                  }
                  return false;
                },
                child: NotificationTile(
                  notification: n,
                  onTap: () => _onTap(n),
                ),
              ),
            ),
        ],
        if (cubit.hasMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(
              child: _loadingMore
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5))
                  : TextButton(
                      onPressed: _loadMore,
                      child: Text('Load more',
                          style: AppTypography.label
                              .copyWith(color: AppColors.primary)),
                    ),
            ),
          ),
      ],
    );
  }

  /// Leading background (swipe right) — mark read.
  Widget _readBg() => _swipeBg(
        alignment: Alignment.centerLeft,
        icon: Icons.done_all_rounded,
        label: 'Mark read',
        color: AppColors.success,
      );

  /// Trailing background (swipe left) — archive (inbox) or delete (archived).
  Widget _trailingBg() => _showArchived
      ? _swipeBg(
          alignment: Alignment.centerRight,
          icon: Icons.delete_outline_rounded,
          label: 'Delete',
          color: AppColors.error,
        )
      : _swipeBg(
          alignment: Alignment.centerRight,
          icon: Icons.archive_outlined,
          label: 'Archive',
          color: AppColors.warning,
        );

  Widget _swipeBg({
    required Alignment alignment,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final children = [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 6),
      Text(label, style: AppTypography.caption.copyWith(color: color)),
    ];
    return Container(
      alignment: alignment,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: alignment == Alignment.centerRight
            ? children
            : children.reversed.toList(),
      ),
    );
  }

  Widget _empty() {
    if (_showArchived) {
      return const DropEmptyState(
        title: 'Nothing archived',
        message: 'Archived notifications will collect here.',
      );
    }
    if (_category != NotificationCategory.all) {
      return DropEmptyState(
        title: 'No ${_category.label.toLowerCase()} notifications',
        message: 'Nothing here right now.',
      );
    }
    return const DropEmptyState(
      title: "You're all caught up",
      message: 'Task updates and announcements will show up here.',
    );
  }

  Widget _errorState() => AppEmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Could not load notifications',
        message: 'Check your connection and try again.',
        action: TextButton(
          onPressed: () {
            final uid = context.currentUser?.uid;
            if (uid != null) context.read<NotificationCubit>().load(uid);
          },
          child: Text('Retry',
              style: AppTypography.label.copyWith(color: AppColors.primary)),
        ),
      );
}

/// "Notifications" over a live status line — a two-line app-bar title. Watches
/// the cubit so the count stays current as items are read, archived, or arrive.
/// The subtitle height is always reserved (a non-breaking space while loading)
/// so the app bar never jumps when the first snapshot lands.
class _HeaderLockup extends StatelessWidget {
  const _HeaderLockup({required this.showArchived});

  final bool showArchived;

  @override
  Widget build(BuildContext context) {
    final title = showArchived ? 'Archived' : 'Notifications';
    return BlocBuilder<NotificationCubit, NotificationState>(
      builder: (context, state) {
        final summary = state.maybeWhen(
          loaded: _summary,
          orElse: () => ' ', // reserve the line height while loading
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.h3),
            const SizedBox(height: 1),
            Text(
              summary,
              style:
                  AppTypography.caption.copyWith(color: AppColors.textTertiary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      },
    );
  }

  String _summary(List<NotificationEntity> items) {
    if (showArchived) {
      final n = items.where((e) => e.isArchived).length;
      return n == 0 ? 'Nothing archived' : '$n archived';
    }
    final unread = items.where((e) => e.isUnread && !e.isArchived).length;
    return unread == 0
        ? "You're all caught up"
        : '$unread unread notification${unread == 1 ? '' : 's'}';
  }
}

/// The category filter pills — subtle premium chips (no loud badges).
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.category, required this.onSelect});

  final NotificationCategory category;
  final ValueChanged<NotificationCategory> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.pagePadding, AppSpacing.sm, AppSpacing.pagePadding, 0),
        children: [
          for (final c in NotificationCategory.values)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: _Chip(
                label: c.label,
                selected: category == c,
                onTap: () => onSelect(c),
              ),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        alignment: Alignment.center,
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.darkSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.darkBorder),
        ),
        child: Text(label,
            style: AppTypography.caption.copyWith(
              color: selected ? AppColors.onPrimary : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            )),
      ),
    );
  }
}
