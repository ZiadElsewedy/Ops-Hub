import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/enums/attendance_correction_kind.dart';
import 'package:drop/core/enums/leave_type.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/app_snackbar.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/features/attendance/domain/attendance_config.dart';
import 'package:drop/features/attendance/domain/attendance_gps.dart';
import 'package:drop/features/attendance/domain/attendance_location_service.dart';
import 'package:drop/features/attendance/domain/entities/attendance_entity.dart';
import 'package:drop/features/attendance/presentation/cubit/attendance_cubit.dart';
import 'package:drop/features/attendance/presentation/cubit/attendance_state.dart';
import 'package:drop/features/attendance/presentation/widgets/attendance_action_sheet.dart';

/// The employee **Attendance** screen — the whole GPS clock-in/out workflow on
/// one adaptive surface, phase-driven off the app-wide [AttendanceCubit]:
///
///   Today's Shift → Clock In → GPS Validation → Working → Clock Out → Summary
///
/// The GPS card is **state-driven**: a live location preview lets it show
/// "At branch · 22 m" / "Outside · 143 m" / a permission-or-service prompt before
/// the employee taps. Clock-in is GPS-gated; clock-out records a best-effort
/// verification but is never blocked (you must be able to end a shift).
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  @override
  void initState() {
    super.initState();
    final user = context.currentUser;
    if (user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final cubit = context.read<AttendanceCubit>();
        await cubit.load(user);
        await cubit.previewLocation();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: 'Attendance',
      subtitle: 'Clock in and out',
      body: BlocConsumer<AttendanceCubit, AttendanceState>(
        listenWhen: (_, s) => s.maybeMap(error: (_) => true, orElse: () => false),
        listener: (context, state) => state.mapOrNull(
          error: (e) => AppSnackbar.error(context, e.message),
        ),
        builder: (context, state) => state.maybeMap(
          loaded: (s) => _ClockView(
            vm: _VM(
              today: s.today,
              session: s.session,
              history: s.history,
              shift: s.shift,
              scheduledStart: s.scheduledStart,
              scheduledEnd: s.scheduledEnd,
              leave: s.leave,
              config: s.config,
              tick: s.tick,
              busy: s.busy,
              verifying: s.verifying,
              offline: s.offline,
              syncing: s.syncing,
              geofenceReady: s.geofenceReady,
              previewing: s.previewing,
              previewVerification: s.previewVerification,
              previewError: s.previewError,
            ),
          ),
          orElse: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xxl),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
        ),
      ),
    );
  }
}

enum _Phase { ready, working, summary, leave, noShift }

/// A flat view of the loaded state (the freezed `_Loaded` case is private).
class _VM {
  final AttendanceEntity? today;
  final AttendanceEntity? session;
  final List<AttendanceEntity> history;
  final ScheduleShift? shift;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final LeaveType? leave;
  final AttendanceConfig config;
  final DateTime tick;
  final bool busy;
  final bool verifying;
  final bool offline;
  final bool syncing;
  final bool geofenceReady;
  final bool previewing;
  final AttendanceVerification? previewVerification;
  final LocationError? previewError;

  const _VM({
    required this.today,
    required this.session,
    required this.history,
    required this.shift,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.leave,
    required this.config,
    required this.tick,
    required this.busy,
    required this.verifying,
    required this.offline,
    required this.syncing,
    required this.geofenceReady,
    required this.previewing,
    required this.previewVerification,
    required this.previewError,
  });

  bool get busyNow => busy || verifying;

  /// Whether to offer an unscheduled shift ([ADR-018]).
  ///
  /// Only when the branch allows it, nothing is rostered, the employee is not
  /// on leave, and the day has not already been clocked — leave loses to a real
  /// punch (workflow 10), but it should not be the thing the screen *suggests*.
  bool get canStartUnscheduled =>
      config.allowUnscheduledClockIn &&
      shift == null &&
      leave == null &&
      session == null &&
      today == null;

  _Phase get phase {
    if (session != null) return _Phase.working;
    final t = today;
    if (t != null && !t.isOpen) return _Phase.summary;
    if (leave != null) return _Phase.leave;
    if (shift == null) return _Phase.noShift;
    return _Phase.ready;
  }
}

class _ClockView extends StatelessWidget {
  const _ClockView({required this.vm});
  final _VM vm;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AttendanceCubit>();
    final phase = vm.phase;

    final Widget content;
    switch (phase) {
      case _Phase.working:
        content = _WorkingView(vm: vm, session: vm.session!, cubit: cubit);
        break;
      case _Phase.summary:
        content = _SummaryView(vm: vm, record: vm.today!);
        break;
      case _Phase.leave:
        content = _MessageCard(
          icon: Icons.beach_access_outlined,
          title: 'On leave today',
          message: 'You\'re on ${vm.leave!.label.toLowerCase()} — nothing to '
              'clock.',
        );
        break;
      case _Phase.noShift:
        // ADR-018: the roster does not know about this day, but the person may
        // genuinely be at work. The offer is deliberately *secondary* — opening
        // the app on a day off must not be able to produce a shift.
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _MessageCard(
              icon: Icons.event_busy_outlined,
              title: 'No shift today',
              message: 'You have no shift scheduled today.',
            ),
            if (vm.canStartUnscheduled) ...[
              const SizedBox(height: AppSpacing.lg),
              _SecondaryButton(
                label: 'Working anyway? Start an unscheduled shift',
                icon: Icons.more_time_rounded,
                onPressed: () => _openUnscheduledSheet(context),
              ),
            ],
          ],
        );
        break;
      case _Phase.ready:
        content = _ReadyView(vm: vm, cubit: cubit);
        break;
    }

    return RefreshIndicator(
      onRefresh: () => cubit.refresh(),
      color: AppColors.primary,
      backgroundColor: AppColors.darkSurfaceElevated,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        children: [
          if (vm.offline || vm.syncing) _SyncBanner(vm: vm),
          _StatusBadge(phase: phase),
          const SizedBox(height: AppSpacing.lg),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.97, end: 1).animate(anim),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey(phase),
              child: content,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Ready: Today's Shift + state-driven GPS card + Clock In ──────────────
class _ReadyView extends StatelessWidget {
  const _ReadyView({required this.vm, required this.cubit});
  final _VM vm;
  final AttendanceCubit cubit;

  @override
  Widget build(BuildContext context) {
    final eligible = cubit.clockInCheck.allowed;
    final atBranch = vm.previewVerification?.verified ?? false;
    final canClockIn =
        eligible && vm.geofenceReady && atBranch && !vm.busyNow && !vm.previewing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ShiftBlock(vm: vm),
        const SizedBox(height: AppSpacing.lg),
        _GpsCard(vm: vm, onRecheck: cubit.previewLocation),
        const SizedBox(height: AppSpacing.xl),
        _ClockButton(
          label: vm.verifying ? 'Verifying location…' : 'Clock In',
          icon: Icons.login_rounded,
          loading: vm.busyNow,
          onPressed: canClockIn ? cubit.clockIn : null,
        ),
        if (!eligible) ...[
          const SizedBox(height: AppSpacing.md),
          _InlineHint(message: cubit.clockInCheck.message),
        ],
        // Missed-punch recovery — offered once the shift has ended and there's
        // still no record (they worked but forgot to clock in).
        if (_shiftEnded(vm)) ...[
          const SizedBox(height: AppSpacing.md),
          _SecondaryButton(
            label: 'Worked but forgot to clock in?',
            icon: Icons.more_time_rounded,
            onPressed: () => _openMissedPunchSheet(context, vm),
          ),
        ],
      ],
    );
  }

  static bool _shiftEnded(_VM vm) {
    final end = vm.scheduledEnd;
    return end != null && DateTime.now().isAfter(end);
  }
}

/// The state-driven GPS card — the whole card reflects the live location status.
class _GpsCard extends StatelessWidget {
  const _GpsCard({required this.vm, required this.onRecheck});
  final _VM vm;
  final VoidCallback onRecheck;

  @override
  Widget build(BuildContext context) {
    // Resolve the card's state, top of precedence first.
    final _GpsCardData d;
    if (!vm.geofenceReady) {
      d = const _GpsCardData(
        icon: Icons.wrong_location_outlined,
        tint: AppColors.textSecondary,
        title: 'GPS not set up here',
        big: null,
        sub: 'This branch has no attendance area configured yet.',
        recheck: false,
      );
    } else if (vm.previewing || vm.verifying) {
      d = const _GpsCardData(
        icon: Icons.my_location_rounded,
        tint: AppColors.textSecondary,
        title: 'Checking location…',
        big: null,
        sub: 'Making sure you\'re at the branch',
        spinner: true,
        recheck: false,
      );
    } else if (vm.previewError == LocationError.serviceDisabled) {
      d = const _GpsCardData(
        icon: Icons.location_off_rounded,
        tint: AppColors.warning,
        title: 'Location is off',
        big: null,
        sub: 'Turn on location services, then tap to retry.',
      );
    } else if (vm.previewError == LocationError.permissionDenied) {
      d = const _GpsCardData(
        icon: Icons.lock_outline_rounded,
        tint: AppColors.warning,
        title: 'Location permission needed',
        big: null,
        sub: 'Allow location access, then tap to retry.',
      );
    } else if (vm.previewError != null || vm.previewVerification == null) {
      d = const _GpsCardData(
        icon: Icons.gps_off_rounded,
        tint: AppColors.warning,
        title: 'Couldn\'t read your location',
        big: null,
        sub: 'Tap to try again in the open.',
      );
    } else {
      final v = vm.previewVerification!;
      final dist = '${v.distanceMeters.round()} m';
      final acc = '±${(v.location.accuracyMeters ?? 0).round()} m';
      if (v.verified) {
        d = _GpsCardData(
          icon: Icons.where_to_vote_rounded,
          tint: AppColors.success,
          title: 'At branch',
          big: dist,
          sub: 'Accuracy $acc',
          recheck: false,
        );
      } else if (!v.withinRadius) {
        d = _GpsCardData(
          icon: Icons.wrong_location_outlined,
          tint: AppColors.warning,
          title: 'Outside work area',
          big: '$dist away',
          sub: 'Move closer to the branch, then tap to retry.',
        );
      } else {
        d = _GpsCardData(
          icon: Icons.gps_not_fixed_rounded,
          tint: AppColors.warning,
          title: 'Weak GPS signal',
          big: acc,
          sub: 'Move to open sky, then tap to retry.',
        );
      }
    }

    return GlassContainer(
      onTap: d.recheck ? onRecheck : null,
      child: Column(
        children: [
          _StatusGlyph(icon: d.icon, tint: d.tint, spinner: d.spinner),
          const SizedBox(height: AppSpacing.md),
          Text(
            d.title,
            style: TextStyle(
              color: d.tint == AppColors.textSecondary
                  ? AppColors.textPrimary
                  : d.tint,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (d.big != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              d.big!,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            d.sub,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
          ),
          if (d.recheck) ...[
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Tap to re-check',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GpsCardData {
  final IconData icon;
  final Color tint;
  final String title;
  final String? big;
  final String sub;
  final bool spinner;
  final bool recheck;
  const _GpsCardData({
    required this.icon,
    required this.tint,
    required this.title,
    required this.big,
    required this.sub,
    this.spinner = false,
    this.recheck = true,
  });
}

// ─── Working: live HH:MM:SS + Clock Out ───────────────────────────────────
class _WorkingView extends StatefulWidget {
  const _WorkingView({
    required this.vm,
    required this.session,
    required this.cubit,
  });
  final _VM vm;
  final AttendanceEntity session;
  final AttendanceCubit cubit;

  @override
  State<_WorkingView> createState() => _WorkingViewState();
}

class _WorkingViewState extends State<_WorkingView> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // A local per-second tick just drives the live HH:MM:SS display (the cubit's
    // own 30s tick still owns the persisted minute snapshot).
    _ticker = Timer.periodic(
        const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final session = widget.session;
    final since = session.effectiveClockIn ?? DateTime.now();
    final elapsed = DateTime.now().difference(since);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ShiftBlock(vm: vm),
        const SizedBox(height: AppSpacing.lg),
        GlassContainer(
          child: Column(
            children: [
              Text(
                _hhmmss(elapsed),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 46,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: 1,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Since ${_hhmm(since)}',
                style: const TextStyle(
                    color: AppColors.textTertiary, fontSize: 13),
              ),
              if (session.clockInVerification != null) ...[
                const SizedBox(height: AppSpacing.lg),
                _VerificationChip(verification: session.clockInVerification!),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _ClockButton(
          label: vm.verifying ? 'Verifying location…' : 'Clock Out',
          icon: Icons.logout_rounded,
          loading: vm.busyNow,
          onPressed: vm.busyNow ? null : widget.cubit.clockOut,
        ),
      ],
    );
  }
}

// ─── Done: Today's Summary + View history ─────────────────────────────────
class _SummaryView extends StatelessWidget {
  const _SummaryView({required this.vm, required this.record});
  final _VM vm;
  final AttendanceEntity record;

  @override
  Widget build(BuildContext context) {
    final needsReview = record.needsReview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ShiftBlock(vm: vm, titleOverride: '${record.shift.label} Shift'),
        const SizedBox(height: AppSpacing.lg),
        GlassContainer(
          child: Column(
            children: [
              _StatusGlyph(
                icon: needsReview
                    ? Icons.error_outline_rounded
                    : Icons.verified_rounded,
                tint: needsReview ? AppColors.warning : AppColors.success,
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Worked today',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                _hmPadded(record.workedMinutes),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SummaryRow(
                label: 'Clock in',
                value: record.clockIn == null ? '—' : _hhmm(record.clockIn!),
                verified: record.isClockInVerified,
                hasGps: record.clockInVerification != null,
              ),
              const Divider(color: AppColors.darkBorder, height: AppSpacing.lg),
              _SummaryRow(
                label: 'Clock out',
                value: record.clockOut == null ? '—' : _hhmm(record.clockOut!),
                verified: record.isClockOutVerified,
                hasGps: record.clockOutVerification != null,
              ),
              if (record.overtimeMinutes > 0) ...[
                const Divider(
                    color: AppColors.darkBorder, height: AppSpacing.lg),
                _SummaryRow(
                    label: 'Overtime',
                    value: _hmPadded(record.overtimeMinutes)),
              ],
            ],
          ),
        ),
        if (needsReview) ...[
          const SizedBox(height: AppSpacing.md),
          const _InlineHint(
            message:
                'This shift was auto-closed. File a correction with your real '
                'clock-out time.',
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _SecondaryButton(
          label: 'Request a correction',
          icon: Icons.edit_calendar_outlined,
          onPressed: () => _openCorrectionSheet(context, record),
        ),
        const SizedBox(height: AppSpacing.sm),
        _SecondaryButton(
          label: 'View history',
          icon: Icons.history_rounded,
          onPressed: () => context.push(RouteNames.attendanceHistory),
        ),
      ],
    );
  }
}

// ─── Employee write-action sheets (reuse the existing cubit + validation) ──
Future<void> _openCorrectionSheet(
    BuildContext context, AttendanceEntity record) async {
  final cubit = context.read<AttendanceCubit>();
  // A pending-review record is missing its clock-out; anything else is a time fix.
  final kind = record.needsReview
      ? AttendanceCorrectionKind.missingClockOut
      : AttendanceCorrectionKind.wrongTime;
  final ok = await showAttendanceActionSheet(
    context,
    title: 'Request a correction',
    subtitle: 'Propose the right times — a manager reviews it.',
    submitLabel: 'Send request',
    askTimes: true,
    day: record.date,
    seedClockIn: record.clockIn ?? record.scheduledStart,
    seedClockOut: record.clockOut ?? record.scheduledEnd,
    onSubmit: (r) => cubit.requestCorrection(
      record: record,
      kind: kind,
      reason: r.reason,
      proposedClockIn: r.clockIn,
      proposedClockOut: r.clockOut,
    ),
  );
  if (ok == true && context.mounted) {
    AppSnackbar.success(context, 'Correction sent for review.');
  }
}

/// Start an unscheduled shift ([ADR-018]).
///
/// Reason is mandatory — it is what makes the shift approvable by a manager
/// afterwards, and what keeps this from becoming a casual second clock-in
/// button. No times are asked for: this starts *now*, like any other clock-in.
Future<void> _openUnscheduledSheet(BuildContext context) async {
  final cubit = context.read<AttendanceCubit>();
  final ok = await showAttendanceActionSheet(
    context,
    title: 'Start an unscheduled shift',
    subtitle: 'You are working a shift that is not on the schedule. Your '
        'manager reviews it before it counts.',
    submitLabel: 'Start shift',
    askTimes: false,
    day: DateTime.now(),
    onSubmit: (r) => cubit.clockInUnscheduled(reason: r.reason),
  );
  if (ok != true) return;
  if (context.mounted) {
    AppSnackbar.success(
      context,
      'Unscheduled shift started — your manager will review it.',
    );
  }
}

Future<void> _openMissedPunchSheet(BuildContext context, _VM vm) async {
  final cubit = context.read<AttendanceCubit>();
  final ok = await showAttendanceActionSheet(
    context,
    title: 'Add a missed shift',
    subtitle: 'You worked but didn\'t clock in — a manager reviews it.',
    submitLabel: 'Send request',
    askTimes: true,
    day: DateTime.now(),
    seedClockIn: vm.scheduledStart,
    seedClockOut: vm.scheduledEnd,
    onSubmit: (r) {
      final start = r.clockIn;
      if (start == null) return Future.value(false);
      return cubit.requestMissedPunch(
        proposedClockIn: start,
        proposedClockOut: r.clockOut,
        reason: r.reason,
      );
    },
  );
  if (ok == true && context.mounted) {
    AppSnackbar.success(context, 'Request sent for review.');
  }
}

// ─── Shared pieces ────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.phase});
  final _Phase phase;

  @override
  Widget build(BuildContext context) {
    final (String label, Color color) = switch (phase) {
      _Phase.working => ('On shift', AppColors.success),
      _Phase.summary => ('Shift complete', AppColors.success),
      _Phase.leave => ('On leave', AppColors.warning),
      _Phase.noShift => ('No shift today', AppColors.textTertiary),
      _Phase.ready => ('Not clocked in', AppColors.textTertiary),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: AppRadius.fullAll,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: TextStyle(
                color: color == AppColors.textTertiary
                    ? AppColors.textSecondary
                    : color,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShiftBlock extends StatelessWidget {
  const _ShiftBlock({required this.vm, this.titleOverride});
  final _VM vm;
  final String? titleOverride;

  @override
  Widget build(BuildContext context) {
    final title = titleOverride ??
        (vm.shift != null ? '${vm.shift!.label} Shift' : 'Today');
    final start = vm.scheduledStart, end = vm.scheduledEnd;
    final range = (start != null && end != null)
        ? '${_hhmm(start)} — ${_hhmm(end)}'
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TODAY\'S SHIFT',
          style: TextStyle(
            color: AppColors.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (range != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              range,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
      ],
    );
  }
}

class _StatusGlyph extends StatelessWidget {
  const _StatusGlyph({
    required this.icon,
    required this.tint,
    this.spinner = false,
  });
  final IconData icon;
  final Color tint;
  final bool spinner;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: spinner
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: CircularProgressIndicator(strokeWidth: 2.4, color: tint),
            )
          : Icon(icon, color: tint, size: 36),
    );
  }
}

/// The prominent primary CTA — the biggest thing on the screen.
class _ClockButton extends StatelessWidget {
  const _ClockButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Material(
      color: enabled ? AppColors.primary : AppColors.darkSurfaceElevated,
      borderRadius: AppRadius.buttonAll,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: AppRadius.buttonAll,
        child: Container(
          height: 64,
          alignment: Alignment.center,
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.4, color: AppColors.onPrimary),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon,
                        size: 22,
                        color: enabled
                            ? AppColors.onPrimary
                            : AppColors.textTertiary),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      label,
                      style: TextStyle(
                        color: enabled
                            ? AppColors.onPrimary
                            : AppColors.textTertiary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.buttonAll,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.buttonAll,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: AppRadius.buttonAll,
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The clock-in GPS chip on the Working card — pin · distance · accuracy.
class _VerificationChip extends StatelessWidget {
  const _VerificationChip({required this.verification});
  final AttendanceVerification verification;

  @override
  Widget build(BuildContext context) {
    final ok = verification.verified;
    final tint = ok ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          Icon(ok ? Icons.where_to_vote_rounded : Icons.wrong_location_outlined,
              size: 20, color: tint),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              ok ? 'Verified at branch' : 'Recorded — not at branch',
              style: TextStyle(
                  color: tint, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '${verification.distanceMeters.round()} m · '
            '±${(verification.location.accuracyMeters ?? 0).round()} m',
            style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12,
                fontFeatures: [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.verified = false,
    this.hasGps = false,
  });
  final String label;
  final String value;
  final bool verified;
  final bool hasGps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 14)),
        const Spacer(),
        if (hasGps) ...[
          Icon(
            verified ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
            size: 14,
            color: verified ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      child: Column(
        children: [
          _StatusGlyph(icon: icon, tint: AppColors.textSecondary),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _InlineHint extends StatelessWidget {
  const _InlineHint({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded,
            size: 16, color: AppColors.textTertiary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.vm});
  final _VM vm;

  @override
  Widget build(BuildContext context) {
    final offline = vm.offline;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          Icon(
            offline ? Icons.cloud_off_rounded : Icons.sync_rounded,
            size: 16,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            offline ? 'Offline — saved on this device' : 'Syncing…',
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─── Formatting ───────────────────────────────────────────────────────────
String _two(int n) => n.toString().padLeft(2, '0');

String _hhmm(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

String _hhmmss(Duration d) {
  final s = d.isNegative ? Duration.zero : d;
  return '${_two(s.inHours)}:${_two(s.inMinutes % 60)}:${_two(s.inSeconds % 60)}';
}

/// Worked/overtime as `HHh MMm`, zero-padded (e.g. `08h 03m`).
String _hmPadded(int minutes) {
  final m = minutes < 0 ? 0 : minutes;
  return '${_two(m ~/ 60)}h ${_two(m % 60)}m';
}
