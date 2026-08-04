import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/enums/broadcast_category.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/app_dialog.dart';
import 'package:drop/core/widgets/responsive_card_grid.dart';
import 'package:drop/core/widgets/app_empty_state.dart';
import 'package:drop/core/widgets/app_motion.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/core/widgets/list_skeleton.dart';
import 'package:drop/features/communications/domain/entities/broadcast_schedule_entity.dart';
import 'package:drop/features/communications/presentation/communications_format.dart';
import 'package:drop/features/communications/presentation/cubit/broadcast_schedule_cubit.dart';
import 'package:drop/features/communications/presentation/cubit/broadcast_schedule_state.dart';
import 'package:drop/core/widgets/app_error_state.dart';

/// Scheduled broadcasts (Communications Center — Phase 2 Commit 4) — the manager
/// surface for recurring/one-time schedules: next run, recurrence, run count,
/// and pause / resume / cancel. The Cloud Function does the firing.
class BroadcastSchedulesScreen extends StatefulWidget {
  const BroadcastSchedulesScreen({super.key});

  @override
  State<BroadcastSchedulesScreen> createState() =>
      _BroadcastSchedulesScreenState();
}

class _BroadcastSchedulesScreenState extends State<BroadcastSchedulesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final user = context.currentUser;
    if (user == null) return;
    context
        .read<BroadcastScheduleCubit>()
        .load(uid: user.uid, isAdmin: user.role.isAdmin);
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: 'Scheduled broadcasts',
      subtitle: 'Recurring and one-time sends',
      body: BlocBuilder<BroadcastScheduleCubit, BroadcastScheduleState>(
        builder: (context, state) => state.maybeWhen(
          loading: () => const ListSkeleton(),
          loaded: (schedules, _) => _list(schedules),
          error: (m) => AppErrorState(
              icon: Icons.wifi_off_rounded,
              title: 'Could not load schedules',
              message: m,
              onRetry: _load),
          orElse: () => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _list(List<BroadcastScheduleEntity> schedules) {
    if (schedules.isEmpty) {
      return const AppEmptyState(
        icon: Icons.schedule_rounded,
        title: 'No scheduled broadcasts',
        message:
            'Use “Schedule” in the composer to send a broadcast later or on a '
            'repeating cadence.',
      );
    }
    return RefreshIndicator(
      onRefresh: () async => _load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.pagePadding, AppSpacing.md,
            AppSpacing.pagePadding, AppSpacing.xxxl),
        children: [
          ResponsiveCardGrid(
            runSpacing: 0, // _ScheduleCard carries its own bottom padding
            ultrawideColumns: 2,
            children: [
              for (var i = 0; i < schedules.length; i++)
                EntranceFade(
                  delay: staggerDelay(i),
                  child: _ScheduleCard(
                    schedule: schedules[i],
                    onToggle: (v) => context
                        .read<BroadcastScheduleCubit>()
                        .setEnabled(schedules[i], v),
                    onCancel: () => _cancel(schedules[i]),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _cancel(BroadcastScheduleEntity s) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Cancel schedule?',
      message:
          'This stops “${s.title}” from sending again. Already-sent broadcasts '
          'are kept.',
      confirmLabel: 'Cancel schedule',
      destructive: true,
    );
    if (ok && mounted) {
      await context.read<BroadcastScheduleCubit>().cancel(s.id);
    }
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.schedule,
    required this.onToggle,
    required this.onCancel,
  });

  final BroadcastScheduleEntity schedule;
  final ValueChanged<bool> onToggle;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final category = BroadcastCategory.fromString(schedule.category.value);
    final catColor = categoryColor(category);
    final completed = schedule.isCompleted;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: GlassContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(categoryIcon(category), size: 18, color: catColor),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(schedule.title,
                      style: AppTypography.label
                          .copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                if (!completed)
                  Switch.adaptive(
                    value: schedule.enabled,
                    onChanged: onToggle,
                    activeThumbColor: AppColors.primary,
                  )
                else
                  const Text('Completed', style: AppTypography.caption),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(schedule.message,
                style: AppTypography.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: 6,
              children: [
                _chip(schedule.isRecurring
                    ? Icons.repeat_rounded
                    : Icons.event_rounded,
                    schedule.recurrenceType.label),
                if (schedule.nextRunAt != null)
                  _chip(Icons.schedule_rounded,
                      'Next ${broadcastFullDate(schedule.nextRunAt)}'),
                if (schedule.runCount > 0)
                  _chip(Icons.send_rounded, 'Sent ${schedule.runCount}×'),
                if (!schedule.enabled && !completed)
                  _chip(Icons.pause_rounded, 'Paused', accent: AppColors.warning),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 16, color: AppColors.error),
                label: Text('Cancel',
                    style:
                        AppTypography.caption.copyWith(color: AppColors.error)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, {Color? accent}) {
    final color = accent ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: AppTypography.caption.copyWith(color: color)),
        ],
      ),
    );
  }
}
