import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/responsive/breakpoints.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/widgets/skeleton.dart';
import 'package:drop/core/widgets/user_avatar.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/schedule/domain/schedule_week.dart';
import 'package:drop/features/schedule/domain/today_roster.dart';
import 'package:drop/features/schedule/presentation/cubit/schedule_cubit.dart';
import 'package:drop/features/schedule/presentation/cubit/schedule_state.dart';

/// Show **who is on shift today**, grouped by shift — a fast, read-only peek.
///
/// Added 2026-08-03 (owner: *"when I click on 2 of 8 on shift today I want to
/// see who's morning and who's night, not open the schedule and edit it"*).
/// The coverage card used to push the weekly grid, which answers a different
/// question: the grid is where you *change* the roster, and it costs a
/// navigation, a week header, a day/shift hunt and a mental filter before it
/// tells you the one thing that was asked.
///
/// Reads through the app-wide [ScheduleCubit] for the current week — the same
/// one-shot load the Schedule tab uses, so opening this warms that tab rather
/// than adding a source. Both manager and admin use it; the branch is passed in.
/// [roster] lets a caller that has ALREADY derived today's roster hand it
/// straight over. Without it the sheet re-reads the same (branch, week) through
/// the shared cubit that the caller just read — a second fetch for data already
/// in memory, and a displacement of a view-wide selection it then has to put
/// back. Passing it also guarantees the sheet and the surface that opened it
/// cannot show different numbers.
///
/// [onOpenSchedule] replaces the footer's default "push the schedule route".
/// A caller that is ITSELF the schedule screen must pass this: pushing the
/// route it is already on stacks an identical copy of the screen, which reads
/// as "the button did nothing" and leaves a duplicate on the back stack.
Future<void> showTodayRosterSheet({
  required BuildContext context,
  required String branchId,
  String? branchName,
  TodayRoster? roster,
  VoidCallback? onOpenSchedule,
}) {
  // Desktop gets a centred dialog; a phone gets the bottom sheet it expects.
  if (context.isDesktop) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.darkSurface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 620),
          child: _TodayRosterView(
            branchId: branchId,
            branchName: branchName,
            roster: roster,
            onOpenSchedule: onOpenSchedule,
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.darkSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: _TodayRosterView(
        branchId: branchId,
        branchName: branchName,
        roster: roster,
        onOpenSchedule: onOpenSchedule,
      ),
    ),
  );
}

class _TodayRosterView extends StatefulWidget {
  const _TodayRosterView({
    required this.branchId,
    this.branchName,
    this.roster,
    this.onOpenSchedule,
  });

  final String branchId;
  final String? branchName;

  /// Already derived by the caller — when set, the sheet reads nothing.
  final TodayRoster? roster;

  final VoidCallback? onOpenSchedule;

  @override
  State<_TodayRosterView> createState() => _TodayRosterViewState();
}

class _TodayRosterViewState extends State<_TodayRosterView> {
  ScheduleCubit? _cubit;

  /// The (branch, week) the shared cubit was showing before this sheet moved
  /// it — restored on close. `null` when we displaced nothing.
  (String, DateTime)? _restoreTo;

  @override
  void initState() {
    super.initState();
    // Handed a roster: nothing to fetch, and — just as important — nothing to
    // displace. The shared-cubit dance below exists only for the read path.
    if (widget.roster != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cubit = context.read<ScheduleCubit>();
      _cubit = cubit;
      final week = ScheduleWeek.currentWeekStart();
      final current = cubit.state.maybeWhen(
        loaded: (branchId, weekStart, _, _, _) => (branchId, weekStart),
        orElse: () => null,
      );
      // Already showing exactly what we need (the common case — the manager
      // came straight from Home): read it, touch nothing.
      if (current != null &&
          current.$1 == widget.branchId &&
          current.$2.isAtSameMomentAs(week)) {
        return;
      }
      // `ScheduleCubit` is app-wide, so loading here would otherwise reset the
      // Schedule tab to this week behind the user's back — if they had paged
      // forward to next week, they'd come back to a different one. A read-only
      // peek must not move a shared view, so remember and put it back.
      _restoreTo = current;
      cubit.load(branchId: widget.branchId, weekStart: week);
    });
  }

  @override
  void dispose() {
    final restore = _restoreTo;
    if (restore != null) {
      _cubit?.load(branchId: restore.$1, weekStart: restore.$2);
    }
    super.dispose();
  }

  void _openSchedule() {
    final handled = widget.onOpenSchedule;
    // A caller that is already the schedule screen handles this itself —
    // pushing the route it is standing on stacks an identical copy, which looks
    // like a dead button and leaves a duplicate on the back stack.
    if (handled != null) {
      Navigator.of(context).pop();
      handled();
      return;
    }
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(
      context.isAdmin ? RouteNames.adminSchedule : RouteNames.managerSchedule,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!context.isDesktop) const _Grabber(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: _Header(branchName: widget.branchName),
          ),
          Flexible(
            child: switch (widget.roster) {
              // Precomputed by the caller — render it, read nothing.
              final TodayRoster given => _Roster(roster: given),
              _ => BlocBuilder<ScheduleCubit, ScheduleState>(
                builder: (context, state) => state.maybeWhen(
                  loaded: (branchId, weekStart, schedule, members, busy) {
                    // Guard against the cubit still showing another branch/week
                    // from a screen behind this sheet.
                    if (branchId != widget.branchId) return const _Loading();
                    return _Roster(
                      roster: todayRoster(schedule: schedule, members: members),
                    );
                  },
                  orElse: () => const _Loading(),
                ),
              ),
            },
          ),
          const Divider(height: 1, color: AppColors.darkBorder),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: _OpenScheduleButton(onTap: _openSchedule),
          ),
        ],
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 36,
      height: 4,
      margin: const EdgeInsets.only(top: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkBorder,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({this.branchName});

  final String? branchName;

  @override
  Widget build(BuildContext context) {
    final date = AppDateFormatter.weekdayDayMonth(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          [date, if ((branchName ?? '').isNotEmpty) branchName!]
              .join(' · ')
              .toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textTertiary,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('On shift today', style: AppTypography.h3),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < 3; i++) ...[
          const Skeleton(height: 44, borderRadius: AppRadius.mdAll),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    ),
  );
}

class _Roster extends StatelessWidget {
  const _Roster({required this.roster});

  final TodayRoster roster;

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      children: [
        for (final s in roster.shifts) ...[
          _ShiftGroup(roster: s),
          const SizedBox(height: AppSpacing.lg),
        ],
        // Only ever rendered when it is true — an assigned uid that no longer
        // resolves to a branch member is the one reason the headcount here
        // could differ from the card that opened it, so it is said out loud.
        if (roster.unresolved > 0)
          Text(
            '${roster.unresolved} rostered '
            '${roster.unresolved == 1 ? 'person is' : 'people are'} no longer '
            'in this branch — open the schedule to clear them.',
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
      ],
    );
  }
}

/// One shift block: its name + hours, a headcount, then the people.
class _ShiftGroup extends StatelessWidget {
  const _ShiftGroup({required this.roster});

  final ShiftRoster roster;

  IconData get _icon => roster.shift == ScheduleShift.morning
      ? Icons.wb_sunny_outlined
      : Icons.nightlight_outlined;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(_icon, size: 15, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Text(
              roster.shift.label,
              style: AppTypography.label.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              roster.hours.format(),
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
            const Spacer(),
            Text(
              '${roster.people.length}',
              style: AppTypography.label.copyWith(
                fontWeight: FontWeight.w700,
                color: roster.isEmpty
                    ? AppColors.textTertiary
                    : AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (roster.isEmpty)
          // Nobody on a shift is the most operationally important thing this
          // sheet can report, so it gets a warning tint rather than a blank.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              borderRadius: AppRadius.mdAll,
              border: Border.all(color: AppColors.warning.withAlpha(60)),
              color: AppColors.warning.withAlpha(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.person_off_outlined,
                  size: 15,
                  color: AppColors.warning,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Nobody is on this shift',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
          )
        else
          for (final u in roster.people)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _PersonRow(user: u),
            ),
      ],
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.user});

  final UserEntity user;

  String get _name =>
      (user.displayName != null && user.displayName!.trim().isNotEmpty)
      ? user.displayName!.trim()
      : user.email;

  String get _role => switch (user.role) {
    UserRole.admin => 'Admin',
    UserRole.manager => 'Manager',
    UserRole.employee => 'Employee',
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$_name, $_role',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.darkSurfaceElevated,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Row(
          children: [
            UserAvatar.fromUser(user, size: 30),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                _name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              _role,
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

class _OpenScheduleButton extends StatelessWidget {
  const _OpenScheduleButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open weekly schedule',
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.buttonAll,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: AppRadius.buttonAll,
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.calendar_view_week_outlined,
                size: 17,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  'Open weekly schedule',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
