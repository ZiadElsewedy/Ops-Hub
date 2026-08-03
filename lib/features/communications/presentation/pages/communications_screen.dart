import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/responsive/breakpoints.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/app_dialog.dart';
import 'package:drop/core/widgets/app_empty_state.dart';
import 'package:drop/core/widgets/app_motion.dart';
import 'package:drop/core/widgets/app_snackbar.dart';
import 'package:drop/core/widgets/list_skeleton.dart';
import 'package:drop/features/communications/domain/entities/broadcast_entity.dart';
import 'package:drop/features/communications/presentation/cubit/broadcast_cubit.dart';
import 'package:drop/features/communications/presentation/cubit/broadcast_state.dart';
import 'package:drop/features/communications/presentation/widgets/broadcast_card.dart';
import 'package:drop/core/widgets/app_error_state.dart';

/// The "···" overflow destinations — everything secondary lives here so the home
/// stays the feed + one primary action.
enum _NavMenu { scheduled, templates, toggleArchived }

/// Communications Center home (2026-06-23 lean redesign) — the broadcast **feed**
/// for the admin (all branches) or a manager (their branch + all-branches). The
/// feed is the only primary surface; **Scheduled, Templates, and Archived** live
/// behind the "···" overflow. A FAB opens Compose. Per-card actions: open ·
/// repeat · archive.
class CommunicationsScreen extends StatefulWidget {
  const CommunicationsScreen({super.key});

  @override
  State<CommunicationsScreen> createState() => _CommunicationsScreenState();
}

class _CommunicationsScreenState extends State<CommunicationsScreen> {
  bool _showArchived = false;
  bool _bulkBusy = false;
  final Set<String> _selectedIds = <String>{};

  /// Broadcast ids whose entrance animation has already played. Lets the feed
  /// animate each card **once** (on first appearance) and never again — so a live
  /// stream emit or a ListView.builder recycle on scroll doesn't replay it.
  final Set<String> _entered = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final user = context.currentUser;
    // Admin → the whole-org feed; manager → their branch + all-branches.
    final branchId = (user?.role.isAdmin ?? false) ? null : (user?.branchId ?? '');
    context.read<BroadcastCubit>().load(branchId: branchId);
  }

  Future<void> _refresh() async => _load();

  void _openDetail(BroadcastEntity b) =>
      context.push(RouteNames.communicationsDetail(b.id), extra: b);

  bool _matches(BroadcastEntity b) => _showArchived ? b.isArchived : b.isActive;

  void _onMenu(_NavMenu item) {
    switch (item) {
      case _NavMenu.scheduled:
        context.push(RouteNames.communicationsSchedules);
      case _NavMenu.templates:
        context.push(RouteNames.communicationsTemplates);
      case _NavMenu.toggleArchived:
        setState(() {
          _showArchived = !_showArchived;
          _selectedIds.clear();
        });
  }
}
  void _toggleSelected(String id, bool selected) {
    setState(() {
      if (selected) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
    });
  }

  void _toggleSelectAll(List<BroadcastEntity> broadcasts) {
    final ids = broadcasts.map((b) => b.id).toSet();
    final allSelected = ids.isNotEmpty && ids.every(_selectedIds.contains);
    setState(() {
      if (allSelected) {
        _selectedIds.removeAll(ids);
      } else {
        _selectedIds.addAll(ids);
      }
    });
  }

  Future<void> _bulkArchive(List<BroadcastEntity> broadcasts) async {
    final selected =
        broadcasts.where((b) => _selectedIds.contains(b.id)).toList();
    if (selected.isEmpty || _bulkBusy) return;
    final archived = !_showArchived;
    final verb = archived ? 'Archive' : 'Restore';
    final noun = selected.length == 1 ? 'broadcast' : 'broadcasts';
    final ok = await showConfirmDialog(
      context,
      title: '$verb ${selected.length} $noun?',
      message: archived
          ? 'The selected broadcasts will move out of the active feed.'
          : 'The selected broadcasts will return to the active feed.',
      confirmLabel: verb,
    );
    if (!ok || !mounted) return;
    setState(() => _bulkBusy = true);
    final success = await context.read<BroadcastCubit>().setArchivedMany(
          selected.map((b) => b.id),
          archived,
        );
    if (!mounted) return;
    setState(() {
      _bulkBusy = false;
      if (success) _selectedIds.clear();
    });
    if (success) {
      AppSnackbar.success(
        context,
        '${selected.length} ${selected.length == 1 ? 'broadcast' : 'broadcasts'} '
        '${archived ? 'archived' : 'restored'}',
      );
    }
  }

  Future<void> _bulkDelete(List<BroadcastEntity> broadcasts) async {
    final selected =
        broadcasts.where((b) => _selectedIds.contains(b.id)).toList();
    if (selected.isEmpty || _bulkBusy) return;
    final noun = selected.length == 1 ? 'broadcast' : 'broadcasts';
    final ok = await showConfirmDialog(
      context,
      title: 'Delete ${selected.length} $noun?',
      message: 'The selected broadcasts will be permanently removed. '
          'This can\'t be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _bulkBusy = true);
    final success = await context
        .read<BroadcastCubit>()
        .deleteBroadcasts(selected.map((b) => b.id));
    if (!mounted) return;
    setState(() {
      _bulkBusy = false;
      if (success) _selectedIds.clear();
    });
    if (success) {
      AppSnackbar.success(
        context,
        '${selected.length} ${selected.length == 1 ? 'broadcast' : 'broadcasts'} deleted',
      );
    }
  }

  Future<void> _onAction(BroadcastEntity b, BroadcastCardAction action) async {
    final cubit = context.read<BroadcastCubit>();
    switch (action) {
      case BroadcastCardAction.open:
        _openDetail(b);
      case BroadcastCardAction.repeatNow:
        final user = context.currentUser;
        if (user == null) return;
        final ok = await showConfirmDialog(
          context,
          title: 'Repeat broadcast?',
          message: 'Send "${b.title}" again now to the same audience.',
          confirmLabel: 'Repeat',
        );
        if (!ok || !mounted) return;
        final count = await cubit.repeatNow(sender: user, source: b);
        if (count != null && mounted) {
          AppSnackbar.success(context,
              'Broadcast sent to $count ${count == 1 ? 'recipient' : 'recipients'}');
        }
      case BroadcastCardAction.archive:
        await cubit.setArchived(b.id, true);
      case BroadcastCardAction.unarchive:
        await cubit.setArchived(b.id, false);
      case BroadcastCardAction.delete:
        final ok = await showConfirmDialog(
          context,
          title: 'Delete broadcast?',
          message:
              '"${b.title}" will be permanently removed from the feed. This can\'t be undone.',
          confirmLabel: 'Delete',
          destructive: true,
        );
        if (!ok || !mounted) return;
        await cubit.deleteBroadcast(b.id);
        if (mounted) AppSnackbar.success(context, 'Broadcast deleted');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: _showArchived ? 'Archived' : 'Communications Center',
      leading: _showArchived
          ? IconButton(
              tooltip: 'Back to feed',
              icon: const Icon(Icons.arrow_back_rounded,
                  color: AppColors.textPrimary),
              onPressed: () => setState(() {
                _showArchived = false;
                _selectedIds.clear();
              }),
            )
          : null,
      actions: [
        PopupMenuButton<_NavMenu>(
          tooltip: 'More',
          icon: const Icon(Icons.more_vert_rounded,
              color: AppColors.textSecondary),
          color: AppColors.darkSurfaceElevated,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onSelected: _onMenu,
          itemBuilder: (context) => [
            _menuItem(_NavMenu.scheduled, Icons.schedule_rounded, 'Scheduled'),
            _menuItem(_NavMenu.templates, Icons.dashboard_customize_outlined,
                'Templates'),
            _menuItem(
                _NavMenu.toggleArchived,
                _showArchived ? Icons.inbox_rounded : Icons.archive_outlined,
                _showArchived ? 'Active feed' : 'Archived'),
          ],
        ),
      ],
      floatingActionButton: _showArchived
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push(RouteNames.communicationsCompose),
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.onAccent,
              icon: const Icon(Icons.add_rounded),
              label: Text('New Broadcast',
                  style:
                      AppTypography.label.copyWith(color: AppColors.onAccent)),
            ),
      body: BlocConsumer<BroadcastCubit, BroadcastState>(
        listener: (context, state) =>
            state.whenOrNull(error: (m) => AppSnackbar.error(context, m)),
        builder: (context, state) => state.maybeWhen(
          loading: () => const ListSkeleton(),
          loaded: (broadcasts, _) {
            final feed = broadcasts.where(_matches).toList();
            return context.isDesktop
                ? _desktopLayout(feed, broadcasts)
                : _feed(feed);
          },
          error: (_) => _errorState(),
          orElse: () => const SizedBox.shrink(),
        ),
      ),
    );
  }

  PopupMenuItem<_NavMenu> _menuItem(_NavMenu value, IconData icon, String label) {
    return PopupMenuItem<_NavMenu>(
      value: value,
      height: 44,
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textPrimary),
          const SizedBox(width: AppSpacing.md),
          Text(label, style: AppTypography.body),
        ],
      ),
    );
  }

  Widget _feed(List<BroadcastEntity> broadcasts) {
    if (broadcasts.isEmpty) return _emptyState();
    final visibleIds = broadcasts.map((b) => b.id).toSet();
    final selectedCount = visibleIds.where(_selectedIds.contains).length;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        // Lazy: only on-screen cards are built (was a non-lazy ListView that
        // built the whole history up front).
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          AppSpacing.md,
          AppSpacing.pagePadding,
          AppSpacing.xxxl * 2,
        ),
        itemCount: broadcasts.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return _selectionBar(
              broadcasts,
              selectedCount: selectedCount,
              allSelected: selectedCount == broadcasts.length,
            );
          }
          final broadcastIndex = i - 1;
          final b = broadcasts[broadcastIndex];
          // Key by broadcast id (not index) so a stream update that reorders /
          // inserts reuses each card's element instead of shuffling state.
          final card = BroadcastCard(
            key: ValueKey(b.id),
            broadcast: b,
            onTap: () => _openDetail(b),
            onAction: (a) => _onAction(b, a),
            selected: _selectedIds.contains(b.id),
            onSelected: (selected) => _toggleSelected(b.id, selected),
          );
          // Play the entrance exactly once per broadcast. Already-seen cards
          // render bare, so neither a live emit nor a scroll-recycle replays it.
          if (_entered.contains(b.id)) return card;
          _entered.add(b.id);
          return EntranceFade(
            key: ValueKey('enter-${b.id}'),
            delay: staggerDelay(broadcastIndex),
            child: card,
          );
        },
      ),
    );
  }

  Widget _selectionBar(
    List<BroadcastEntity> broadcasts, {
    required int selectedCount,
    required bool allSelected,
  }) {
    final hasSelection = selectedCount > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TextButton.icon(
                key: const ValueKey('broadcast-select-all'),
                onPressed:
                    _bulkBusy ? null : () => _toggleSelectAll(broadcasts),
                icon: Icon(
                  allSelected
                      ? Icons.deselect_rounded
                      : Icons.select_all_rounded,
                  size: 18,
                ),
                label: Text(allSelected ? 'Clear all' : 'Select all'),
              ),
              if (hasSelection) ...[
                const SizedBox(width: AppSpacing.sm),
                Text('$selectedCount selected', style: AppTypography.caption),
              ],
              if (_bulkBusy) ...[
                const Spacer(),
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          if (hasSelection) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: _bulkBusy ? null : () => _bulkArchive(broadcasts),
                  icon: Icon(
                    _showArchived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                    size: 18,
                  ),
                  label: Text(_showArchived ? 'Restore' : 'Archive'),
                ),
                const SizedBox(width: AppSpacing.xs),
                TextButton.icon(
                  onPressed: _bulkBusy ? null : () => _bulkDelete(broadcasts),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _emptyState() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: AppEmptyState(
        icon: Icons.campaign_outlined,
        title: _showArchived ? 'Nothing archived' : 'No broadcasts yet',
        message: _showArchived
            ? 'Archived broadcasts are kept here, out of the main feed.'
            : 'Send your first announcement, reminder or alert with the New '
                'Broadcast button.',
      ),
    );
  }

  Widget _errorState() => AppErrorState(
        icon: Icons.wifi_off_rounded,
        title: 'Could not load broadcasts',
        message: 'Check your connection and try again.',
        retryLabel: 'Retry',
        onRetry: _load,
      );

  // ── Desktop: command-center (history feed + delivery/command panel) ──
  Widget _desktopLayout(
      List<BroadcastEntity> feed, List<BroadcastEntity> all) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _feed(feed)),
        const VerticalDivider(width: 1, color: AppColors.darkBorder),
        SizedBox(width: 320, child: _commandPanel(all)),
      ],
    );
  }

  Widget _commandPanel(List<BroadcastEntity> all) {
    final active = all.where((b) => b.isActive).toList();
    final sent = active.length;
    final recipients =
        active.fold<int>(0, (s, b) => s + (b.recipientCount ?? 0));
    final delivered =
        active.fold<int>(0, (s, b) => s + (b.deliveredCount ?? 0));
    final rate = recipients == 0 ? 0.0 : delivered / recipients;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 40, 48),
      children: [
        _panelHeader('DELIVERY'),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(child: _statTile('Broadcasts', '$sent')),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _statTile('Recipients', '$recipients')),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(child: _statTile('Delivered', '$delivered')),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _statTile('Delivery rate',
                  recipients == 0 ? '—' : '${(rate * 100).round()}%',
                  accent: true),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        _panelHeader('MANAGE'),
        const SizedBox(height: AppSpacing.md),
        _panelAction(
          icon: Icons.add_rounded,
          label: 'New Broadcast',
          accent: true,
          onTap: () => context.push(RouteNames.communicationsCompose),
        ),
        _panelAction(
          icon: Icons.dashboard_customize_outlined,
          label: 'Templates',
          onTap: () => context.push(RouteNames.communicationsTemplates),
        ),
        _panelAction(
          icon: Icons.schedule_rounded,
          label: 'Scheduled',
          onTap: () => context.push(RouteNames.communicationsSchedules),
        ),
        _panelAction(
          icon: _showArchived ? Icons.inbox_rounded : Icons.archive_outlined,
          label: _showArchived ? 'Active feed' : 'Archived',
          onTap: () => setState(() {
            _showArchived = !_showArchived;
            _selectedIds.clear();
          }),
        ),
      ],
    );
  }

  Widget _panelHeader(String label) => Text(
        label,
        style: AppTypography.caption.copyWith(
          color: AppColors.textTertiary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      );

  Widget _statTile(String label, String value, {bool accent = false}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: accent ? AppColors.accentBorder : AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: AppTypography.h2.copyWith(
                  color: accent ? AppColors.accent : AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.caption),
        ],
      ),
    );
  }

  Widget _panelAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool accent = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: accent ? AppColors.accentSurface : AppColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color:
                      accent ? AppColors.accentBorder : AppColors.darkBorder),
            ),
            child: Row(
              children: [
                Icon(icon,
                    size: 18,
                    color: accent ? AppColors.accent : AppColors.textSecondary),
                const SizedBox(width: AppSpacing.md),
                Text(label,
                    style: AppTypography.label.copyWith(
                        color: accent
                            ? AppColors.accent
                            : AppColors.textPrimary)),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded,
                    size: 16, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
