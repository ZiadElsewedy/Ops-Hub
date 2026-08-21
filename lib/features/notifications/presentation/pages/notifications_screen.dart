import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:opshub/core/extensions/context_extensions.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/adaptive_scaffold.dart';
import 'package:opshub/core/widgets/app_dialog.dart';
import 'package:opshub/core/widgets/app_snackbar.dart';
import 'package:opshub/core/widgets/opshub_empty_state.dart';
import 'package:opshub/core/widgets/app_motion.dart';
import 'package:opshub/core/widgets/list_skeleton.dart';
import 'package:opshub/features/notifications/domain/entities/notification_entity.dart';
import 'package:opshub/features/notifications/domain/notification_deep_link.dart';
import 'package:opshub/features/notifications/presentation/cubit/notification_cubit.dart';
import 'package:opshub/features/notifications/presentation/cubit/notification_state.dart';
import 'package:opshub/features/notifications/presentation/notification_format.dart';
import 'package:opshub/features/notifications/presentation/widgets/notification_tile.dart';
import 'package:opshub/core/widgets/app_error_state.dart';

/// The in-app Notification Center — an **operations inbox** (§5). Not a
/// flat feed: notifications are **grouped by time** (Today / Yesterday / Earlier),
/// **filtered by category** (All / Tasks / Reviews / Requests / Cases / Schedule
/// / Sales / Broadcast), and **ordered newest-first** within each section so it
/// reads as a timeline (owner ruling 2026-08-11; priority still drives a tile's
/// unread emphasis, not the feed order). Swipe right
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

  /// Whether tapping [n] opens a destination. Resolved with the same resolver
  /// the tap uses, so the tile's presentation and its behaviour can never
  /// disagree: a notification with no safe target shows its body in full
  /// instead of clamping it behind a tap that goes nowhere.
  bool _navigable(NotificationEntity n) =>
      resolveNotificationRoute(
        route: n.route,
        payload: n.payload,
        role: context.currentRole,
      ) !=
      null;

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

  /// Both bulk actions report failure now. They are `NetworkGuard`-guarded and
  /// paged, so offline — or on an inbox past the sweep ceiling — they genuinely
  /// do nothing, and a bulk action that silently does nothing is
  /// indistinguishable from one that worked.
  Future<void> _markAllRead() async {
    final error = await context.read<NotificationCubit>().markAllRead();
    if (error != null && mounted) AppSnackbar.error(context, error);
  }

  Future<void> _clearArchived() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Clear archived?',
      message: 'Permanently delete all archived notifications.',
      confirmLabel: 'Clear',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final error = await context.read<NotificationCubit>().clearArchived();
    if (error != null && mounted) AppSnackbar.error(context, error);
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
                onPressed: _markAllRead,
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
    // The pills count the unread of the CURRENT view (inbox or archived) before
    // the category narrows it — otherwise every pill but the active one would
    // read zero.
    final inView = items.where((n) => n.isArchived == _showArchived);
    final unreadByCategory = <NotificationCategory, int>{};
    for (final n in inView.where((n) => n.isUnread)) {
      // A type this build does not recognise has no category pill (it shows
      // under All only), so it contributes to the All count and to nothing
      // else. Counting it under a pill would put a badge on a filter that,
      // when tapped, does not contain it.
      final c = categoryOf(n.type);
      if (c != null) unreadByCategory[c] = (unreadByCategory[c] ?? 0) + 1;
      unreadByCategory[NotificationCategory.all] =
          (unreadByCategory[NotificationCategory.all] ?? 0) + 1;
    }
    final sections = groupByTime(_visible(items), DateTime.now());
    return Column(
      children: [
        _FilterBar(
          category: _category,
          unreadByCategory: unreadByCategory,
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
      // A narrower gutter than the page default: an inbox row is a list item,
      // not a page section, and the extra width goes to the title.
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxxl),
      children: [
        for (final section in sections) ...[
          _SectionHeader(
            title: section.title,
            unread: section.items.where((n) => n.isUnread).length,
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
                  navigable: _navigable(n),
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
        // Matches the card it sits behind, so the reveal never shows a corner
        // that does not line up with the tile sliding over it.
        borderRadius: AppRadius.cardAll,
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
      return const OpsHubEmptyState(
        title: 'Nothing archived',
        message: 'Archived notifications will collect here.',
      );
    }
    if (_category != NotificationCategory.all) {
      return OpsHubEmptyState(
        title: 'No ${_category.label.toLowerCase()} notifications',
        message: 'Nothing here right now.',
      );
    }
    return const OpsHubEmptyState(
      title: "You're all caught up",
      message: 'Task updates and announcements will show up here.',
    );
  }

  Widget _errorState() => AppErrorState(
        icon: Icons.wifi_off_rounded,
        title: 'Could not load notifications',
        message: 'Check your connection and try again.',
        retryLabel: 'Retry',
        onRetry: () {
          final uid = context.currentUser?.uid;
          if (uid != null) context.read<NotificationCubit>().load(uid);
        },
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

/// A day divider — "TODAY" with a hairline running out to the right margin, and
/// the unread count of that day parked at the far end. The rule does the work a
/// blank gap used to do: it separates the days without spending vertical space,
/// and it gives the eye a line to return to when scrolling a long inbox.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.unread});

  final String title;
  final int unread;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, AppSpacing.lg, 2, AppSpacing.md),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Container(height: 1, color: AppColors.darkBorder),
          ),
          if (unread > 0) ...[
            const SizedBox(width: AppSpacing.md),
            Text(
              '$unread new',
              style: AppTypography.caption
                  .copyWith(color: AppColors.textQuaternary),
            ),
          ],
        ],
      ),
    );
  }
}

/// The category filter pills — subtle premium chips (no loud badges), each
/// carrying its unread count so the bar is a **signal**, not decoration: an
/// admin sees "Requests 4" without opening the filter.
///
/// The rail is masked at both ends so a scrollable row of pills fades out
/// rather than being sliced off mid-word at the screen edge (which is what made
/// the old bar read as broken).
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.category,
    required this.unreadByCategory,
    required this.onSelect,
  });

  final NotificationCategory category;
  final Map<NotificationCategory, int> unreadByCategory;
  final ValueChanged<NotificationCategory> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ShaderMask(
        // These are stencil values, not palette values: under `dstIn` only the
        // gradient's ALPHA is read (opaque = keep, transparent = fade), so they
        // are not a theme colour and must not be replaced with one.
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
          stops: [0, 0.035, 0.88, 1],
        ).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
          children: [
            for (final c in NotificationCategory.values)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: _Chip(
                  label: c.label,
                  unread: unreadByCategory[c] ?? 0,
                  selected: category == c,
                  onTap: () => onSelect(c),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.unread,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int unread;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.onPrimary : AppColors.textSecondary;
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: AppTypography.caption.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                )),
            if (unread > 0) ...[
              const SizedBox(width: 6),
              Text('$unread',
                  style: AppTypography.caption.copyWith(
                    color: selected
                        ? AppColors.onPrimary.withAlpha(140)
                        : AppColors.textQuaternary,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ],
        ),
      ),
    );
  }
}
