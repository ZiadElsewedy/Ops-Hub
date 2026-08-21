import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/enums/leave_type.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/opshub_loading_state.dart';
import 'package:drop/core/widgets/user_avatar.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/responsive/breakpoints.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:drop/features/schedule/domain/schedule_week.dart';
import 'package:drop/features/schedule/domain/shift_hours.dart';
import 'package:drop/features/schedule/domain/swap_eligibility.dart';
import 'package:drop/features/schedule/presentation/cubit/schedule_cubit.dart';
import 'package:drop/features/schedule/presentation/cubit/schedule_state.dart';
import 'package:drop/features/schedule/domain/shift_window.dart';
import 'package:drop/features/schedule/presentation/cubit/shift_swap_cubit.dart';
import 'package:drop/features/schedule/presentation/cubit/shift_swap_state.dart';
import 'package:drop/features/schedule/presentation/widgets/schedule_helpers.dart';
import 'package:drop/features/schedule/presentation/widgets/swap_roster_sync.dart';
import 'package:drop/features/schedule/presentation/widgets/swap_view.dart';

/// Employee schedule screen — premium design. Two tabs: "My Week" (greeting,
/// today's hero card with shift / manager / team, and the full week list with
/// per-slot Swap actions) and "Swaps". Entrance and refresh both stagger-animate
/// the content sections in with FadeTransition + SlideTransition.
///
/// ⚠️ **Owner ruling (2026-07-07): this premium hero/week-cards UI is THE
/// employee schedule UI on every tier — do NOT redesign it again.** An
/// answer-first minimal rework was built and reverted the same day (the owner
/// wants visible craft, not reduction). Only incremental improvements inside
/// this design language are allowed — e.g. the live countdown states, the
/// next-shift line, un-truncated notes and the swap-on-today fix below.
class MyScheduleScreen extends StatefulWidget {
  const MyScheduleScreen({super.key});

  @override
  State<MyScheduleScreen> createState() => _MyScheduleScreenState();
}

class _MyScheduleScreenState extends State<MyScheduleScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final user = context.currentUser;
    if (user == null) return;
    context.read<ScheduleCubit>().load(branchId: user.branchId ?? '');
    context.read<ShiftSwapCubit>().loadMine(user.uid);
  }

  @override
  Widget build(BuildContext context) {
    // Device identity, not window class: a phone rotated to landscape must not
    // flip to the legacy tablet body mid-session.
    final phone = MediaQuery.sizeOf(context).shortestSide < Breakpoints.tablet;
    return SwapRosterSync(
      child: DefaultTabController(length: 2, child: _scaffold(phone)),
    );
  }

  /// The week + swaps scaffold. Split out so [SwapRosterSync] can wrap it —
  /// an approved swap rewrites this employee's week on the server, and without
  /// that refetch the roster on screen stays pre-swap, which is how a swap gets
  /// requested for a shift its requester no longer holds.
  Widget _scaffold(bool phone) {
    return AdaptiveScaffold(
      title: 'My Schedule',
      subtitle: 'Your week and shift swaps',
      actions: [
        IconButton(
          icon: const Icon(
            Icons.refresh_rounded,
            color: AppColors.textSecondary,
          ),
          tooltip: 'Refresh',
          onPressed: _load,
        ),
      ],
      bottom: TabBar(
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textTertiary,
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        indicatorWeight: 2,
        tabs: [
          const Tab(text: 'My Week'),
          Tab(child: _SwapsTabLabel(showDot: phone)),
        ],
      ),
      body: TabBarView(
        children: [
          _MyWeekTab(),
          // Resolve the uid at build time — caching it from the post-frame
          // _load() without setState left it '' until an incidental rebuild,
          // hiding every Accept/Decline/Cancel action on the Swaps tab.
          SwapListView(
            isManager: false,
            currentUid: context.currentUser?.uid ?? '',
          ),
        ],
      ),
    );
  }
}

/// The Swaps tab label — on phones it carries a small warning dot while a swap
/// on a **still-future** slot awaits this user's answer, so an actionable
/// request is never invisible behind the tab. Stale pending requests (their
/// slot already passed) are filtered out and never nag. Plain label on
/// tablet/desktop.
class _SwapsTabLabel extends StatelessWidget {
  const _SwapsTabLabel({required this.showDot});
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    if (!showDot) return const Text('Swaps');
    final uid = context.currentUser?.uid ?? '';
    return BlocBuilder<ShiftSwapCubit, ShiftSwapState>(
      builder: (context, state) {
        final needsAnswer = state.maybeWhen(
          loaded: (swaps, _) => swaps.any(
            (s) =>
                s.targetId == uid &&
                s.status.isPending &&
                SwapEligibility.isRequestable(s.weekStart, s.day, s.shift),
          ),
          orElse: () => false,
        );
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Swaps'),
            if (needsAnswer) ...[
              const SizedBox(width: 6),
              Container(
                key: const Key('swaps-tab-dot'),
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.warning,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ─── My Week Tab ─────────────────────────────────────────────────────────────

class _MyWeekTab extends StatefulWidget {
  @override
  State<_MyWeekTab> createState() => _MyWeekTabState();
}

class _MyWeekTabState extends State<_MyWeekTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    // TabBarView disposes this tab whenever the user visits Swaps and
    // recreates it on return — with the cubit still `loaded`, so the listener
    // below (which only fires on a state CHANGE) never plays the entrance
    // animation and the whole week renders at opacity 0. If the data is
    // already there at mount, show it immediately; the stagger remains for
    // real load/refresh cycles.
    final alreadyLoaded = context.read<ScheduleCubit>().state.maybeWhen(
      loaded: (_, _, _, _, _) => true,
      orElse: () => false,
    );
    if (alreadyLoaded) _ctrl.value = 1.0;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // Each section gets its own fade/slide interval within [0,1].
  Animation<double> _fade(double t0, double t1) =>
      Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(t0, t1, curve: Curves.easeOut),
        ),
      );

  Animation<Offset> _slide(double t0, double t1) =>
      Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(t0, t1, curve: Curves.easeOutCubic),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ScheduleCubit, ScheduleState>(
      listener: (context, state) {
        state.whenOrNull(
          loaded: (_, _, _, _, busy) {
            if (!busy) _ctrl.forward(from: 0);
          },
        );
      },
      builder: (context, state) => state.maybeWhen(
        loading: () => const OpsHubLoadingState(message: 'Loading your week…'),
        loaded: (branchId, weekStart, schedule, members, busy) =>
            _buildList(context, weekStart, schedule, members),
        error: (m) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            child: Text(
              m,
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
        ),
        // `initial` (load not kicked off yet, e.g. before the post-frame _load
        // or a momentarily-null user) must never render as a blank screen —
        // show the loader; the app-bar Refresh recovers any stuck state.
        orElse: () => const OpsHubLoadingState(message: 'Loading your week…'),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    DateTime weekStart,
    WeeklyScheduleEntity? schedule,
    List<UserEntity> members,
  ) {
    final user = context.currentUser;
    final uid = user?.uid ?? '';

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.darkSurface,
      onRefresh: () => context.read<ScheduleCubit>().refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          AppSpacing.lg,
          AppSpacing.pagePadding,
          AppSpacing.xxxl,
        ),
        children: [
          // ── Greeting ────────────────────────────────────────────
          FadeTransition(
            opacity: _fade(0.00, 0.35),
            child: SlideTransition(
              position: _slide(0.00, 0.35),
              child: _GreetingHeader(user: user),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          if (schedule == null) ...[
            FadeTransition(
              opacity: _fade(0.20, 0.60),
              child: _NoScheduleCard(),
            ),
          ] else ...[
            // ── Today hero card ──────────────────────────────────
            FadeTransition(
              opacity: _fade(0.15, 0.55),
              child: SlideTransition(
                position: _slide(0.15, 0.55),
                child: _TodayHeroCard(
                  schedule: schedule,
                  members: members,
                  uid: uid,
                  weekStart: weekStart,
                  onSwap: (d, s) =>
                      _requestSwap(context, schedule, members, user, d, s),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // ── This Week header ─────────────────────────────────
            FadeTransition(
              opacity: _fade(0.30, 0.60),
              child: SlideTransition(
                position: _slide(0.30, 0.60),
                child: _WeekSectionHeader(weekStart: weekStart),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Week rows — staggered per day ────────────────────
            ...ScheduleDay.values.asMap().entries.map((entry) {
              final i = entry.key;
              final day = entry.value;
              final t0 = (0.40 + i * 0.05).clamp(0.0, 0.90);
              final t1 = (t0 + 0.25).clamp(0.0, 1.00);
              return FadeTransition(
                opacity: _fade(t0, t1),
                child: SlideTransition(
                  position: _slide(t0, t1),
                  child: _WeekDayRow(
                    schedule: schedule,
                    members: members,
                    user: user,
                    day: day,
                    weekStart: weekStart,
                    onSwap: (d, s) =>
                        _requestSwap(context, schedule, members, user, d, s),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  void _requestSwap(
    BuildContext context,
    WeeklyScheduleEntity schedule,
    List<UserEntity> members,
    UserEntity? user,
    ScheduleDay day,
    ScheduleShift shift,
  ) {
    if (user == null) return;
    // Exchange model: you may only swap with a coworker on the OPPOSITE shift
    // that same day — they hold the slot you want, you hold theirs. This also
    // enforces "requester ≠ target" and "target slot must exist". Eligibility is
    // "same branch, any role" (the picker doesn't filter by app-role); role/
    // position compatibility is a per-branch policy applied inside the sheet.
    final opposite = shift.opposite;
    final oppositeUids = schedule.employeesFor(day, opposite).toSet();
    final coworkers = members
        .where((u) => u.uid != user.uid && oppositeUids.contains(u.uid))
        .toList();
    if (coworkers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No coworkers on the ${opposite.label} shift to swap with.',
          ),
        ),
      );
      return;
    }
    showSwapRequestSheet(
      context: context,
      cubit: context.read<ShiftSwapCubit>(),
      schedule: schedule,
      branchId: schedule.branchId,
      weekStart: schedule.weekStart,
      day: day,
      shift: shift,
      requester: user,
      coworkers: coworkers,
    );
  }
}

// ─── Greeting ────────────────────────────────────────────────────────────────

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({this.user});
  final UserEntity? user;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good morning'
        : (hour < 17 ? 'Good afternoon' : 'Good evening');
    final name = _firstName(user);
    final date = _dateLabel(now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$greeting, $name 👋', style: AppTypography.h1),
        const SizedBox(height: AppSpacing.xs),
        Text(
          date,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  String _firstName(UserEntity? u) {
    final n = (u?.displayName ?? '').trim();
    if (n.isEmpty) return 'there';
    return n.split(RegExp(r'\s+')).first;
  }

  String _dateLabel(DateTime d) => AppDateFormatter.weekdayDayMonth(d);
}

// ─── No Schedule Card ────────────────────────────────────────────────────────

class _NoScheduleCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.event_busy_outlined,
            size: 48,
            color: AppColors.textTertiary,
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            'No schedule published for this week yet.',
            textAlign: TextAlign.center,
            style: AppTypography.body,
          ),
        ],
      ),
    );
  }
}

// ─── Today Hero Card ─────────────────────────────────────────────────────────

/// Employee-facing wording for a leave entry — their own day, stated plainly.
String _leaveLabel(LeaveType type) => switch (type) {
  LeaveType.annual => 'Annual Leave',
  LeaveType.sick => 'Sick Leave',
  LeaveType.dayOff => 'Day Off',
  LeaveType.pending => 'Leave Requested',
};

IconData _leaveIcon(LeaveType type) => switch (type) {
  LeaveType.annual => Icons.beach_access_outlined,
  LeaveType.sick => Icons.medical_services_outlined,
  LeaveType.dayOff => Icons.event_busy_outlined,
  LeaveType.pending => Icons.hourglass_empty_rounded,
};

/// Employee-facing time range with an **arrow** separator (e.g. `16:00 →
/// 00:00`). Owner-preferred form for the employee surfaces; hours come from the
/// loaded schedule so configured overrides display consistently.
String _arrowRange(ShiftHours hours) => hours.format(separator: '→');

ScheduleDay _previousDay(ScheduleDay day) =>
    ScheduleDay.values[(day.index + ScheduleDay.values.length - 1) %
        ScheduleDay.values.length];

/// A quiet "has notes" indicator for the glanceable cards — the full bulleted
/// note lives in the tap-to-open shift sheet, never duplicated on the card
/// (owner ruling, 2026-07-07). Monochrome; the 📝 in mockups maps to the
/// app's Material sticky-note glyph.
class _NoteIndicator extends StatelessWidget {
  const _NoteIndicator({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: AppRadius.fullAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.sticky_note_2_outlined,
            size: 12,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            count <= 1 ? 'Note' : '$count notes',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the employee's read-only shift/day sheet — the premium detail surface
/// the glanceable cards route into: day + shift, arrow time, the day's notes as
/// bullets, manager, teammates, and a **Swap Shift** action when eligible.
/// [shift] is null for an off/leave day (no time/team/swap; note + manager
/// only). [onSwap] fires the branch's swap-request flow for (day, shift).
void showEmployeeShiftSheet({
  required BuildContext context,
  required ScheduleDay day,
  required ScheduleShift? shift,
  required DateTime weekStart,
  required WeeklyScheduleEntity schedule,
  required List<UserEntity> members,
  required String uid,
  required LeaveType? leaveType,
  required void Function(ScheduleDay, ScheduleShift) onSwap,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.darkSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ShiftDetailsSheet(
      day: day,
      shift: shift,
      weekStart: weekStart,
      schedule: schedule,
      members: members,
      uid: uid,
      leaveType: leaveType,
      onSwap: onSwap,
    ),
  );
}

class _TodayHeroCard extends StatelessWidget {
  const _TodayHeroCard({
    required this.schedule,
    required this.members,
    required this.uid,
    required this.weekStart,
    required this.onSwap,
  });

  final WeeklyScheduleEntity schedule;
  final List<UserEntity> members;
  final String uid;
  final DateTime weekStart;
  final void Function(ScheduleDay, ScheduleShift) onSwap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = ScheduleDay.fromDate(now);
    final myShifts = schedule.shiftsFor(uid, today);
    final leaveType = schedule.leaveTypeOf(uid, today);
    final note = schedule.noteFor(today);

    // Post-midnight tail: yesterday's configured overnight shift may still be
    // running, so the hero keeps showing it instead of flipping to "Day Off".
    // The Saturday → Sunday seam only has previous-week crew context available;
    // use standing hours there rather than this week's future Saturday override.
    final spillDay = _previousDay(today);
    final spillHours = spillDay == ScheduleDay.saturday
        ? ShiftHours.standard(spillDay, ScheduleShift.night)
        : schedule.hoursFor(spillDay, ScheduleShift.night);
    final hasSpill = ShiftWindow.nightSpillEnd(now, spillHours) != null;
    ScheduleDay? activeSpill;
    if (hasSpill) {
      final onIt = spillDay == ScheduleDay.saturday
          ? context.read<ScheduleCubit>().previousSaturdayNight.contains(uid)
          : schedule.isAssigned(uid, spillDay, ScheduleShift.night);
      if (onIt) activeSpill = spillDay;
    }

    final isOff = activeSpill == null && myShifts.isEmpty;
    final shift = activeSpill != null
        ? ScheduleShift.night
        : (isOff ? null : myShifts.first);
    // The (day, week) that anchors the shown shift's clock times and phase —
    // during a spill it's yesterday's slot (previous week for the Sat→Sun tail).
    final displayDay = activeSpill ?? today;
    final phaseWeekStart = activeSpill == ScheduleDay.saturday
        ? weekStart.subtract(const Duration(days: 7))
        : weekStart;
    final shiftHours = shift == null
        ? null
        : (activeSpill == ScheduleDay.saturday
              ? ShiftHours.standard(displayDay, shift)
              : schedule.hoursFor(displayDay, shift));

    // Coworkers on the same shift(s).
    final teamUids = <String>{};
    if (activeSpill != null) {
      teamUids.addAll(
        schedule
            .employeesFor(displayDay, ScheduleShift.night)
            .where((u) => u != uid),
      );
    } else {
      for (final s in myShifts) {
        teamUids.addAll(schedule.employeesFor(today, s).where((u) => u != uid));
      }
    }
    final teamUsers = teamUids
        .map((t) => userForUid(t, members))
        .whereType<UserEntity>()
        .toList();

    final managers = members
        .where((m) => m.role.isManager || m.role.isAdmin)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(
          color: isOff
              ? AppColors.darkBorder
              : AppColors.primary.withAlpha(70), // ~27% white border
        ),
      ),
      child: Column(
        children: [
          _buildHeader(
            today,
            displayDay,
            phaseWeekStart,
            shift,
            shiftHours,
            isOff,
            leaveType,
            note,
          ),
          const Divider(height: 1, color: AppColors.darkBorder),
          _buildTeamRow(teamUsers, managers, isOff),
          const Divider(height: 1, color: AppColors.darkBorder),
          _buildDetailsRow(
            context,
            displayDay,
            phaseWeekStart,
            shift,
            leaveType,
            note,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    ScheduleDay today,
    ScheduleDay displayDay,
    DateTime phaseWeekStart,
    ScheduleShift? shift,
    ShiftHours? shiftHours,
    bool isOff,
    LeaveType? leaveType,
    String? note,
  ) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShiftIconBox(shift: shift, leaveType: isOff ? leaveType : null),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TODAY pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: AppRadius.fullAll,
                    border: Border.all(color: AppColors.primary.withAlpha(50)),
                  ),
                  child: Text(
                    'TODAY',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  // A leave day names its reason instead of a generic "Day
                  // Off" — the schedule tells the employee what their manager
                  // recorded (Schedule 5.0).
                  isOff
                      ? (leaveType == null ? 'Day Off' : _leaveLabel(leaveType))
                      : '${shift!.label} Shift',
                  style: AppTypography.h2,
                ),
                if (!isOff) ...[
                  const SizedBox(height: 4),
                  _CountdownRow(
                    shift: shift!,
                    day: displayDay,
                    hours: shiftHours!,
                    weekStart: phaseWeekStart,
                  ),
                ],
                if (isOff) ...[
                  // The off/leave answer's natural follow-up — "so when do I
                  // work next?" — from the already-loaded week.
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.event_outlined,
                        size: 12,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _nextShiftLabel(today),
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (note != null) ...[
                  const SizedBox(height: 8),
                  // Glanceable indicator only — the full bulleted note lives in
                  // the tap-to-open sheet below (owner ruling, 2026-07-07).
                  _NoteIndicator(
                    count: schedule.noteLinesFor(displayDay).length,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _nextShiftLabel(ScheduleDay today) {
    final next = schedule.nextShiftAfter(uid, today);
    if (next == null) return 'No more shifts this week';
    final start = schedule.hoursFor(next.$1, next.$2).startLabel;
    return 'Next shift · ${next.$1.label} ${next.$2.label} · $start';
  }

  Widget _buildTeamRow(
    List<UserEntity> team,
    List<UserEntity> managers,
    bool isOff,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Manager
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Manager', style: AppTypography.caption),
                const SizedBox(height: AppSpacing.sm),
                if (managers.isEmpty)
                  const Text('—', style: AppTypography.body)
                else
                  Row(
                    children: [
                      UserAvatar.fromUser(managers.first, size: 32),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userDisplayName(managers.first),
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _roleLabel(managers.first),
                              style: AppTypography.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Working with
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Working with', style: AppTypography.caption),
                const SizedBox(height: AppSpacing.sm),
                if (team.isEmpty || isOff)
                  Text(isOff ? '—' : 'Just you', style: AppTypography.body)
                else
                  _TeamAvatars(users: team),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsRow(
    BuildContext context,
    ScheduleDay displayDay,
    DateTime phaseWeekStart,
    ScheduleShift? shift,
    LeaveType? leaveType,
    String? note,
  ) {
    // There's a sheet worth opening whenever the day has a shift or a note.
    final hasSheet = shift != null || note != null;
    return InkWell(
      onTap: !hasSheet
          ? null
          : () => showEmployeeShiftSheet(
              context: context,
              day: displayDay,
              shift: shift,
              weekStart: phaseWeekStart,
              schedule: schedule,
              members: members,
              uid: uid,
              leaveType: leaveType,
              onSwap: onSwap,
            ),
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(
              shift != null
                  ? Icons.calendar_today_outlined
                  : Icons.notes_rounded,
              size: 15,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                shift != null ? 'View shift details' : 'View day details',
                style: AppTypography.label.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            if (hasSheet)
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textTertiary,
              ),
          ],
        ),
      ),
    );
  }

  String _roleLabel(UserEntity u) => u.role.isAdmin ? 'Admin' : 'Store Manager';
}

// ─── Shift Icon Box ───────────────────────────────────────────────────────────

class _ShiftIconBox extends StatelessWidget {
  const _ShiftIconBox({this.shift, this.leaveType});
  final ScheduleShift? shift;

  /// Set on an off day that is a recorded leave — the box shows why.
  final LeaveType? leaveType;

  @override
  Widget build(BuildContext context) {
    final icon = shift == null
        ? (leaveType == null
              ? Icons.do_not_disturb_on_outlined
              : _leaveIcon(leaveType!))
        : (shift == ScheduleShift.morning
              ? Icons.wb_sunny_rounded
              : Icons.nightlight_rounded);

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Icon(icon, color: AppColors.textSecondary, size: 26),
    );
  }
}

// ─── Countdown Row (time + live shift-status pill) ────────────────────────────

/// Time range + a live status pill: `In 4h 30m` before the shift, `On now ·
/// till 00:00` while it runs (a night that closes at/after midnight correctly
/// stays "on" up to its end — the phase comes from [ShiftWindow], never from
/// same-day clock math), and a quiet `Ended` after. Re-renders on a
/// minute-aligned tick so the countdown is never stale.
class _CountdownRow extends StatefulWidget {
  const _CountdownRow({
    required this.shift,
    required this.day,
    required this.hours,
    required this.weekStart,
  });

  final ScheduleShift shift;
  final ScheduleDay day;
  final ShiftHours hours;

  /// The week anchoring this (day, shift) slot — during the post-midnight
  /// Saturday-night tail this is the *previous* week's Sunday.
  final DateTime weekStart;

  @override
  State<_CountdownRow> createState() => _CountdownRowState();
}

class _CountdownRowState extends State<_CountdownRow> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _scheduleTick();
  }

  /// Self-rescheduling tick aligned to the wall-clock minute, so "In 45m"
  /// counts down honestly instead of freezing at its mount-time value.
  void _scheduleTick() {
    _tick?.cancel();
    _tick = Timer(Duration(seconds: 61 - DateTime.now().second), () {
      if (!mounted) return;
      setState(() {});
      _scheduleTick();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final phase = ShiftWindow.phaseOf(
      widget.weekStart,
      widget.day,
      widget.shift,
      widget.hours,
      now,
    );
    final (label, ended) = switch (phase) {
      ShiftPhase.upcoming => (
        _countdown(
          ShiftWindow.startOf(widget.weekStart, widget.day, widget.hours),
          now,
        ),
        false,
      ),
      ShiftPhase.active => ('On now · till ${widget.hours.endLabel}', false),
      ShiftPhase.finished => ('Ended', true),
    };

    return Row(
      children: [
        const Icon(
          Icons.access_time_rounded,
          size: 12,
          color: AppColors.textTertiary,
        ),
        const SizedBox(width: 4),
        Text(
          // The configured time (arrow form) — tabular figures so the live
          // countdown beside it never nudges this label as digits change.
          _arrowRange(widget.hours),
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: ended
                  ? AppColors.darkSurfaceElevated
                  : AppColors.primarySurface,
              borderRadius: AppRadius.fullAll,
              border: Border.all(
                color: ended
                    ? AppColors.darkBorder
                    : AppColors.primary.withAlpha(40),
              ),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: ended ? AppColors.textTertiary : AppColors.primary,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _countdown(DateTime start, DateTime now) {
    final diff = start.difference(now);
    if (diff.inHours >= 48) return 'In ${diff.inDays}d';
    if (diff.inHours >= 1) {
      final m = diff.inMinutes % 60;
      return m == 0 ? 'In ${diff.inHours}h' : 'In ${diff.inHours}h ${m}m';
    }
    return 'In ${diff.inMinutes < 1 ? 1 : diff.inMinutes}m';
  }
}

// ─── Team Avatars (with first names below) ────────────────────────────────────

class _TeamAvatars extends StatelessWidget {
  const _TeamAvatars({required this.users});
  final List<UserEntity> users;

  @override
  Widget build(BuildContext context) {
    const size = 30.0;
    const step = size * 0.62;
    final shown = users.length > 3 ? users.take(3).toList() : users;
    final overflow = users.length - shown.length;
    final discCount = shown.length + (overflow > 0 ? 1 : 0);
    final totalWidth = size + (discCount - 1) * step;

    final overflowNames = overflow > 0
        ? users.skip(3).map((u) => userDisplayName(u).split(' ').first).toList()
        : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: totalWidth,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ...shown.asMap().entries.map(
                (e) => Positioned(
                  left: e.key * step,
                  child: UserAvatar.fromUser(
                    e.value,
                    size: size,
                    ringColor: AppColors.darkSurface,
                  ),
                ),
              ),
              if (overflow > 0)
                Positioned(
                  left: shown.length * step,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.darkSurfaceElevated,
                      border: Border.all(
                        color: AppColors.darkSurface,
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '+$overflow',
                      style: AppTypography.labelSmall.copyWith(
                        fontSize: size * 0.34,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _namesSummary(shown, overflowNames),
          style: AppTypography.caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  String _namesSummary(List<UserEntity> shown, List<String> extra) {
    final names = shown
        .map((u) => userDisplayName(u).split(' ').first)
        .toList();
    if (extra.isEmpty) return names.join(', ');
    return '${names.join(', ')}, +${extra.length} more';
  }
}

// ─── Shift Details Bottom Sheet ───────────────────────────────────────────────

/// The employee's read-only detail surface for a day (the tap-to-open premium
/// sheet from the glanceable cards): day + shift, arrow time, the manager's
/// note as bullets, manager, teammates, and a **Swap Shift** action when the
/// slot is still requestable. [shift] is null for an off/leave day — then it's
/// a day/note view (no time, team or swap).
class _ShiftDetailsSheet extends StatelessWidget {
  const _ShiftDetailsSheet({
    required this.day,
    required this.shift,
    required this.weekStart,
    required this.schedule,
    required this.members,
    required this.uid,
    required this.leaveType,
    required this.onSwap,
  });

  final ScheduleDay day;
  final ScheduleShift? shift;
  final DateTime weekStart;
  final WeeklyScheduleEntity schedule;
  final List<UserEntity> members;
  final String uid;
  final LeaveType? leaveType;
  final void Function(ScheduleDay, ScheduleShift) onSwap;

  @override
  Widget build(BuildContext context) {
    final s = shift;
    final noteLines = schedule.noteLinesFor(day);
    final team = s == null
        ? const <UserEntity>[]
        : schedule
              .employeesFor(day, s)
              .where((u) => u != uid)
              .map((u) => userForUid(u, members))
              .whereType<UserEntity>()
              .toList();
    final managers = members
        .where((m) => m.role.isManager || m.role.isAdmin)
        .toList();
    final hours = s == null ? null : schedule.hoursFor(day, s);
    final canSwap =
        s != null &&
        SwapEligibility.isRequestable(weekStart, day, s) &&
        schedule.employeesFor(day, s.opposite).any((u) => u != uid);

    final title = s != null
        ? '${s.label} Shift'
        : (leaveType != null ? _leaveLabel(leaveType!) : 'Day Off');
    final subtitle = s != null
        ? '${day.label} · ${_arrowRange(hours!)}'
        : day.label;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          AppSpacing.lg,
          AppSpacing.pagePadding,
          32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.darkBorder,
                  borderRadius: AppRadius.fullAll,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Header — day / shift / arrow time
            Row(
              children: [
                _ShiftIconBox(
                  shift: shift,
                  leaveType: shift == null ? leaveType : null,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTypography.h3),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (s != null) ...[
                            const Icon(
                              Icons.access_time_rounded,
                              size: 13,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            subtitle,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Notes as bullets — the full note, never hidden or truncated.
            if (noteLines.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              const Row(
                children: [
                  Icon(
                    Icons.sticky_note_2_outlined,
                    size: 15,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: 6),
                  Text('Notes', style: AppTypography.caption),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final line in noteLines) _NoteBullet(text: line),
            ],
            const SizedBox(height: AppSpacing.xl),
            if (managers.isNotEmpty) ...[
              const Text('Manager', style: AppTypography.caption),
              const SizedBox(height: AppSpacing.sm),
              _MemberTile(user: managers.first),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (s != null)
              if (team.isNotEmpty) ...[
                const Text('Team on this shift', style: AppTypography.caption),
                const SizedBox(height: AppSpacing.sm),
                ...team.map((u) => _MemberTile(user: u)),
              ] else
                const Text(
                  'You are the only one on this shift.',
                  style: AppTypography.body,
                ),
            if (canSwap) ...[
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onSwap(day, shift!);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.darkBorder),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.buttonAll,
                    ),
                  ),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text('Swap Shift'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One note line as a bullet — the manager writes one instruction per line.
class _NoteBullet extends StatelessWidget {
  const _NoteBullet({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7, right: 10),
            child: Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: AppColors.textSecondary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: AppTypography.body.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.user});
  final UserEntity user;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          UserAvatar.fromUser(user, size: 36),
          const SizedBox(width: AppSpacing.md),
          Text(userDisplayName(user), style: AppTypography.label),
        ],
      ),
    );
  }
}

// ─── Week Section Header ──────────────────────────────────────────────────────

class _WeekSectionHeader extends StatelessWidget {
  const _WeekSectionHeader({required this.weekStart});
  final DateTime weekStart;

  @override
  Widget build(BuildContext context) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final range = _range(weekStart, weekEnd);
    return Row(
      children: [
        const Text('This Week', style: AppTypography.h3),
        const Spacer(),
        Text(
          range,
          style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
        ),
      ],
    );
  }

  String _range(DateTime s, DateTime e) {
    return s.month == e.month
        ? '${s.day} – ${AppDateFormatter.dayMonth(e)}'
        : '${AppDateFormatter.dayMonth(s)} – ${AppDateFormatter.dayMonth(e)}';
  }
}

// ─── Week Day Row ─────────────────────────────────────────────────────────────

class _WeekDayRow extends StatelessWidget {
  const _WeekDayRow({
    required this.schedule,
    required this.members,
    required this.user,
    required this.day,
    required this.weekStart,
    required this.onSwap,
  });

  final WeeklyScheduleEntity schedule;
  final List<UserEntity> members;
  final UserEntity? user;
  final ScheduleDay day;
  final DateTime weekStart;
  final void Function(ScheduleDay, ScheduleShift) onSwap;

  @override
  Widget build(BuildContext context) {
    final uid = user?.uid ?? '';
    final shifts = schedule.shiftsFor(uid, day);
    // Exact calendar-date match against the displayed week — never weekday-only,
    // so viewing another week highlights no "Today" (bug fix).
    final isToday = ScheduleWeek.isToday(weekStart, day);
    // weekStart is Sunday = index 0; day.index maps directly.
    final dayDate = weekStart.add(Duration(days: day.index));
    // The employee's own leave + the manager's day note (Schedule 5.0) — the
    // week list states them without opening anything.
    final leaveType = schedule.leaveTypeOf(uid, day);
    final note = schedule.noteFor(day);

    if (shifts.isEmpty) {
      return _buildRow(
        context,
        null,
        isToday,
        dayDate,
        leaveType: leaveType,
        note: note,
      );
    }

    // Multiple shifts on same day → one row each (day-level extras ride the
    // first row only, so they never repeat).
    return Column(
      children: [
        for (final (i, s) in shifts.indexed)
          _buildRow(
            context,
            s,
            isToday,
            dayDate,
            leaveType: i == 0 ? leaveType : null,
            note: i == 0 ? note : null,
          ),
      ],
    );
  }

  Widget _buildRow(
    BuildContext context,
    ScheduleShift? shift,
    bool isToday,
    DateTime dayDate, {
    LeaveType? leaveType,
    String? note,
  }) {
    final isOff = shift == null;
    final uid = user?.uid ?? '';
    final noteCount = note == null ? 0 : schedule.noteLinesFor(day).length;
    // A row opens the sheet when there's a shift to detail or a note to read.
    // Plain off days stay glanceable and inert (owner: keep cards clean).
    final hasSheet = shift != null || note != null;

    final row = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isToday ? AppColors.darkSurfaceElevated : AppColors.darkSurface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(
          color: isToday
              ? AppColors.primary.withAlpha(40)
              : AppColors.darkBorder,
        ),
      ),
      child: Row(
        children: [
          // ── Day chip ──────────────────────────────────────────
          _DayChip(day: day, date: dayDate, isToday: isToday),
          const SizedBox(width: AppSpacing.md),

          // ── Shift icon circle ─────────────────────────────────
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.darkBg,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Icon(
              isOff
                  ? (leaveType == null
                        ? Icons.remove_circle_outline_rounded
                        : _leaveIcon(leaveType))
                  : (shift == ScheduleShift.morning
                        ? Icons.wb_sunny_outlined
                        : Icons.nightlight_outlined),
              size: 16,
              color: isOff ? AppColors.textTertiary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // ── Shift name + time + note indicator ────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // An off day that is recorded leave names its reason;
                  // a plain unscheduled day stays "Off".
                  isOff
                      ? (leaveType == null ? 'Off' : _leaveLabel(leaveType))
                      : '${shift.label} Shift',
                  style: AppTypography.label.copyWith(
                    color: isOff && leaveType == null
                        ? AppColors.textTertiary
                        : AppColors.textPrimary,
                  ),
                ),
                if (!isOff)
                  // The configured shift time — the operational payload of this
                  // row, so it reads at secondary (not the dimmest tertiary) and
                  // uses tabular figures so times align down the column and the
                  // digits never jitter.
                  Text(
                    _arrowRange(schedule.hoursFor(day, shift)),
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                if (!isOff && leaveType != null)
                  // Rostered AND marked away — say it, the manager resolves.
                  Text(
                    'Also marked ${leaveType.label.toLowerCase()} — '
                    'check with your manager',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.warning,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (note != null) ...[
                  const SizedBox(height: 6),
                  // Indicator only — the bullets live in the tap-to-open sheet.
                  _NoteIndicator(count: noteCount),
                ],
              ],
            ),
          ),

          // ── Affordance: chevron when the row opens a sheet ────
          if (hasSheet)
            const Padding(
              padding: EdgeInsets.only(left: AppSpacing.sm),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textTertiary,
              ),
            ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: hasSheet
          ? Material(
              color: Colors.transparent,
              borderRadius: AppRadius.cardAll,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => showEmployeeShiftSheet(
                  context: context,
                  day: day,
                  shift: shift,
                  weekStart: weekStart,
                  schedule: schedule,
                  members: members,
                  uid: uid,
                  leaveType: leaveType,
                  onSwap: onSwap,
                ),
                child: row,
              ),
            )
          : row,
    );
  }
}

// ─── Day Chip ─────────────────────────────────────────────────────────────────

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.date,
    required this.isToday,
  });

  final ScheduleDay day;
  final DateTime date;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            day.shortLabel,
            style: AppTypography.caption.copyWith(
              color: isToday ? AppColors.textSecondary : AppColors.textTertiary,
              fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 3),
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: isToday
                ? const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: AppRadius.smAll,
                  )
                : null,
            child: Text(
              '${date.day}',
              style: AppTypography.label.copyWith(
                color: isToday ? AppColors.onPrimary : AppColors.textSecondary,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
