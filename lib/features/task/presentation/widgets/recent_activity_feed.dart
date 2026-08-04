import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/app_motion.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/core/widgets/live_list_item.dart';
import 'package:drop/core/widgets/skeleton.dart';
import 'package:drop/features/task/domain/active_window.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/task/presentation/cubit/task_state.dart';
import 'package:drop/features/task/presentation/widgets/task_activity_card.dart';

/// **RecentActivityFeed** — the dashboard's "what's happening" layer (DROP Design
/// System V2). The calm, vertical replacement for the dense/filtered task feed on
/// the home screen: the most recently-touched active tasks rendered as clean
/// [TaskActivityCard]s, newest first, capped at [limit]. No filter chips, no
/// group headers, no horizontal scanning — "See all" (on the section header)
/// takes the admin to the full Tasks page for anything deeper.
///
/// Lives over the app-wide [TaskCubit] stream (zero new reads) and stays live:
/// an emit re-renders the capped list. Sits inside a scrolling page, so it never
/// scrolls itself and always renders a bounded number of rows (scalable).
class RecentActivityFeed extends StatelessWidget {
  const RecentActivityFeed({
    super.key,
    this.limit = 6,
    this.branchLocked = false,
    this.branchId,
  });

  /// Max cards shown — the rest live behind "See all".
  final int limit;

  /// Manager mode — pin to [branchId].
  final bool branchLocked;
  final String? branchId;

  static int _touch(TaskEntity t) =>
      (t.updatedAt ?? t.createdAt)?.millisecondsSinceEpoch ?? 0;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TaskCubit, TaskState>(
      builder: (context, state) {
        return state.maybeWhen(
          loaded: (tasks, busy, directory, isSubmitting, progress) {
            final branchNames = context.read<TaskCubit>().branchNames;
            final now = DateTime.now();
            final active = <TaskEntity>[
              for (final t in tasks)
                if (isTaskInActiveWindow(t, now) &&
                    (!branchLocked || t.branchId == branchId))
                  t,
            ]..sort((a, b) => _touch(b).compareTo(_touch(a)));
            final shown = active.take(limit).toList();

            if (shown.isEmpty) return const _AllClear();
            final reduceMotion = MediaQuery.of(context).disableAnimations;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, t) in shown.indexed)
                  Padding(
                    key: ValueKey('activity:${t.id}'),
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    // Each row enters once (fade + rise) and never replays on a
                    // stream emit — keyed element reuse means only a genuinely
                    // new task mounts + animates in, so a live insert slides in
                    // naturally while the settled rows stay put. Staggered on the
                    // first load; a fresh arrival (newest-first ⇒ index 0) plays
                    // immediately.
                    child: reduceMotion
                        ? TaskActivityCard(
                            task: t,
                            directory: directory,
                            branchName: branchNames[t.branchId],
                          )
                        : LiveListItem(
                            entranceDelay: staggerDelay(i),
                            highlightRadius: 20,
                            child: TaskActivityCard(
                              task: t,
                              directory: directory,
                              branchName: branchNames[t.branchId],
                            ),
                          ),
                  ),
              ],
            );
          },
          orElse: () => _FeedSkeleton(rows: limit.clamp(2, 3)),
        );
      },
    );
  }
}

/// A deliberately compact "nothing active" state — a full-bleed empty
/// illustration would over-dramatise a healthy queue and (inside an unbounded
/// list) risk an infinite-height layout. Instead of looking switched-off, the
/// healthy queue reads as *reassuring*: a check badge that softly breathes (a
/// calm heartbeat that the system is alive and under control). Under reduced
/// motion the badge sits still.
class _AllClear extends StatefulWidget {
  const _AllClear();

  @override
  State<_AllClear> createState() => _AllClearState();
}

class _AllClearState extends State<_AllClear>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  bool _animating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.of(context).disableAnimations;
    if (!reduce && !_animating) {
      _animating = true;
      _c.repeat(reverse: true);
    } else if (reduce && _animating) {
      _animating = false;
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _badge(double t) {
    return Transform.scale(
      scale: 1 + t * 0.05,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.darkSurfaceElevated,
          border: Border.all(color: AppColors.darkBorder),
          boxShadow: [
            BoxShadow(
              color: AppColors.white.withAlpha((6 + t * 12).round()),
              blurRadius: 16 + t * 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Icon(
          Icons.check_rounded,
          size: 26,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Full width so the centred column actually sits in the MIDDLE of the feed
    // area. Without this the Column shrink-wraps to its content and the parent
    // (CrossAxisAlignment.start) pins the whole block to the left.
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_animating)
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) =>
                      _badge(Curves.easeInOut.transform(_c.value)),
                ),
              )
            else
              _badge(0),
            const SizedBox(height: AppSpacing.md),
            Text(
              'All clear',
              style: AppTypography.label.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Every task is handled — nothing needs you right now.',
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Premium loading state — a few activity-card-shaped shimmer rows instead of a
/// bare spinner, so the feed's structure is already suggested while it loads.
class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton({required this.rows});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: GlassContainer(
              elevated: false,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: 14,
              ),
              child: Row(
                children: [
                  const Skeleton(width: 34, height: 34, circle: true),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Skeleton(width: 150, height: 12),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Skeleton(
                            width: 90 + (i.isEven ? 24 : 0),
                            height: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const Skeleton(width: 54, height: 18),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
