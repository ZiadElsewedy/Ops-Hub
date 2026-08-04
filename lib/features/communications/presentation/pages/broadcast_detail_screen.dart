import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/enums/broadcast_category.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/app_dialog.dart';
import 'package:drop/core/widgets/app_empty_state.dart';
import 'package:drop/core/widgets/app_snackbar.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/features/communications/domain/entities/broadcast_entity.dart';
import 'package:drop/features/communications/presentation/communications_format.dart';
import 'package:drop/features/communications/presentation/cubit/broadcast_cubit.dart';
import 'package:drop/features/communications/presentation/cubit/broadcast_state.dart';
import 'package:drop/features/communications/presentation/widgets/broadcast_card.dart';

/// Broadcast detail (Phase 2) — opened at `/communications/:broadcastId`. Shows
/// the full message, sender, category, audience, priority, channel, time, and
/// minimal **delivery diagnostics** (recipients · delivered · failed), plus a
/// per-item actions menu (repeat · duplicate · archive · delete).
class BroadcastDetailScreen extends StatefulWidget {
  const BroadcastDetailScreen({
    super.key,
    required this.broadcastId,
    this.broadcast,
  });

  final String broadcastId;
  final BroadcastEntity? broadcast;

  @override
  State<BroadcastDetailScreen> createState() => _BroadcastDetailScreenState();
}

class _BroadcastDetailScreenState extends State<BroadcastDetailScreen> {
  /// The broadcast fetched by id on a deep-link (feed not loaded, no `extra`).
  BroadcastEntity? _fetched;
  bool _fetching = false;
  bool _fetchAttempted = false;

  /// One-shot fetch when the broadcast is reachable neither from the live feed
  /// nor via `extra` — i.e. a notification tap opened this screen cold. Without
  /// it the deep link would dead-end on "Broadcast unavailable".
  Future<void> _fetchById() async {
    if (_fetchAttempted) return;
    _fetchAttempted = true;
    setState(() => _fetching = true);
    final entity = await context.read<BroadcastCubit>().fetchById(
      widget.broadcastId,
    );
    if (!mounted) return;
    setState(() {
      _fetched = entity;
      _fetching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BroadcastCubit, BroadcastState>(
      builder: (context, state) {
        // Prefer the live feed copy (freshest delivery counts); fall back to
        // the entity passed in via `extra`, then to a one-shot deep-link fetch.
        final fromFeed = state.maybeWhen(
          loaded: (list, _) => _byId(list, widget.broadcastId),
          orElse: () => null,
        );
        final b = fromFeed ?? widget.broadcast ?? _fetched;

        // Deep-link fallback: not in the feed, none passed in — fetch it once.
        if (b == null && !_fetchAttempted && !_fetching) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _fetchById());
        }

        return AdaptiveScaffold(
          title: 'Broadcast',
          actions: [if (b != null) _ActionsMenu(broadcast: b)],
          body: b != null
              ? _detail(context, b)
              : _fetching
              ? const Center(child: CircularProgressIndicator())
              : _missing(),
        );
      },
    );
  }

  BroadcastEntity? _byId(List<BroadcastEntity> list, String id) {
    for (final b in list) {
      if (b.id == id) return b;
    }
    return null;
  }

  Widget _missing() => const AppEmptyState(
    icon: Icons.campaign_outlined,
    title: 'Broadcast unavailable',
    message:
        'This broadcast may have been deleted, or you no longer have '
        'access to it.',
  );

  Widget _detail(BuildContext context, BroadcastEntity b) {
    final category = BroadcastCategory.fromString(b.category);
    final catColor = categoryColor(category);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.lg,
        AppSpacing.pagePadding,
        AppSpacing.xxxl,
      ),
      children: [
        // Header
        GlassContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: catColor.withAlpha(category.isUrgent ? 30 : 20),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: catColor.withAlpha(60)),
                    ),
                    child: Icon(
                      categoryIcon(category),
                      color: catColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.label,
                          style: AppTypography.caption.copyWith(
                            color: catColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(b.title, style: AppTypography.h2),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Icon(
                    audienceIcon(b.audience),
                    size: 14,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 6),
                  Text(audienceLabel(b), style: AppTypography.caption),
                  const Spacer(),
                  Text(
                    broadcastTimeAgo(b.createdAt),
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Message
        const _SectionLabel('Message'),
        GlassContainer(
          child: Text(
            b.message,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Delivery diagnostics (sent / delivered / failed) — operational health,
        // not analytics. Open/read tracking was removed in the 2026-06-23 pass.
        const _SectionLabel('Delivery'),
        GlassContainer(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      icon: Icons.group_outlined,
                      label: 'Recipients',
                      value: b.recipientCount?.toString() ?? '—',
                    ),
                  ),
                  _vDivider(),
                  Expanded(
                    child: _Stat(
                      icon: Icons.mark_email_read_outlined,
                      label: 'Delivered',
                      value:
                          b.deliveredCount?.toString() ??
                          (b.recipientCount == null ? '—' : 'Pending'),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Divider(height: 1, color: AppColors.darkBorder),
              ),
              _Stat(
                icon: Icons.error_outline_rounded,
                label: 'Failed',
                value: b.failedCount?.toString() ?? '—',
                color: (b.failedCount ?? 0) > 0 ? AppColors.error : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Details
        const _SectionLabel('Details'),
        GlassContainer(
          child: Column(
            children: [
              _MetaRow(
                icon: Icons.person_outline_rounded,
                label: 'Sender',
                value: b.senderName,
              ),
              _MetaRow(
                icon: audienceIcon(b.audience),
                label: 'Audience',
                value: audienceLabel(b),
              ),
              _MetaRow(
                icon: categoryIcon(category),
                label: 'Category',
                value: category.label,
              ),
              _MetaRow(
                icon: Icons.send_outlined,
                label: 'Delivery',
                value: b.sendsPush ? 'Push + Inbox' : 'Inbox only',
              ),
              _MetaRow(
                icon: Icons.schedule_rounded,
                label: 'Sent',
                value: broadcastFullDate(b.createdAt),
                last: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _vDivider() => Container(
    width: 1,
    height: 40,
    color: AppColors.darkBorder,
    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
  );
}

/// The detail app-bar overflow menu, reusing the feed's action handling.
class _ActionsMenu extends StatelessWidget {
  const _ActionsMenu({required this.broadcast});
  final BroadcastEntity broadcast;

  Future<void> _onAction(
    BuildContext context,
    BroadcastCardAction action,
  ) async {
    final cubit = context.read<BroadcastCubit>();
    switch (action) {
      case BroadcastCardAction.open:
        break;
      case BroadcastCardAction.repeatNow:
        final user = context.currentUser;
        if (user == null) return;
        final ok = await showConfirmDialog(
          context,
          title: 'Repeat broadcast?',
          message: 'Send "${broadcast.title}" again now to the same audience.',
          confirmLabel: 'Repeat',
        );
        if (!ok || !context.mounted) return;
        final count = await cubit.repeatNow(sender: user, source: broadcast);
        if (count != null && context.mounted) {
          AppSnackbar.success(
            context,
            'Broadcast sent to $count ${count == 1 ? 'recipient' : 'recipients'}',
          );
        }
      case BroadcastCardAction.archive:
        await cubit.setArchived(broadcast.id, true);
      case BroadcastCardAction.unarchive:
        await cubit.setArchived(broadcast.id, false);
      case BroadcastCardAction.delete:
        final ok = await showConfirmDialog(
          context,
          title: 'Delete broadcast?',
          message:
              '"${broadcast.title}" will be permanently removed. This can\'t be undone.',
          confirmLabel: 'Delete',
          destructive: true,
        );
        if (!ok || !context.mounted) return;
        await cubit.deleteBroadcast(broadcast.id);
        // The broadcast is gone — leave the now-stale detail screen.
        if (context.mounted) {
          AppSnackbar.success(context, 'Broadcast deleted');
          Navigator.of(context).pop();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final archived = broadcast.isArchived;
    return PopupMenuButton<BroadcastCardAction>(
      tooltip: 'Actions',
      icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
      color: AppColors.darkSurfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (a) => _onAction(context, a),
      itemBuilder: (context) => [
        _item(
          BroadcastCardAction.repeatNow,
          Icons.replay_rounded,
          'Repeat now',
        ),
        if (archived)
          _item(
            BroadcastCardAction.unarchive,
            Icons.unarchive_rounded,
            'Unarchive',
          )
        else
          _item(BroadcastCardAction.archive, Icons.archive_outlined, 'Archive'),
      ],
    );
  }

  PopupMenuItem<BroadcastCardAction> _item(
    BroadcastCardAction value,
    IconData icon,
    String label,
  ) {
    const color = AppColors.textPrimary;
    return PopupMenuItem<BroadcastCardAction>(
      value: value,
      height: 44,
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: 2),
    child: Text(
      text.toUpperCase(),
      style: AppTypography.caption.copyWith(
        color: AppColors.textTertiary,
        letterSpacing: 0.6,
      ),
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color ?? AppColors.textTertiary),
            const SizedBox(width: 6),
            Text(label, style: AppTypography.caption),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: AppTypography.h2.copyWith(
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textTertiary),
          const SizedBox(width: AppSpacing.md),
          Text(label, style: AppTypography.body),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: AppTypography.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
