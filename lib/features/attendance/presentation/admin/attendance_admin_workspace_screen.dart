import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/di/injection.dart';
import 'package:drop/core/responsive/breakpoints.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/core/widgets/page_hero.dart';
import 'package:drop/features/attendance/domain/reporting/admin_attendance_overview.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_period.dart';
import 'package:drop/features/attendance/presentation/admin/admin_attendance_overview_cubit.dart';
import 'package:drop/features/attendance/presentation/admin/widgets/attendance_evidence_table.dart';
import 'package:drop/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:drop/features/branch/presentation/cubit/branch_state.dart';

/// **Admin Workspace** — where the attendance record is proved rather than
/// operated (`ATTENDANCE_PRODUCT_REDESIGN_PLAN` §8).
///
/// Operational UX and audit UX are opposite design targets: one optimises for
/// speed and ruthless incompleteness, the other for completeness and
/// permanence. A single screen serving both serves neither — which is exactly
/// what the original weekly report demonstrated. This is the other half.
///
/// Nothing here was deleted from the manager surfaces; it was **relocated**.
/// The evidence table, the provenance, and the data-completeness signal all
/// existed already — they were simply pointed at the wrong reader.
///
/// Four sections, ordered by the decision an admin actually has:
/// 1. **Needs chasing** — which branch has stopped settling its days.
/// 2. **Data completeness** — which branch-week is not whole.
/// 3. **Across branches** — the rollup, and the only place a rate has a real
///    denominator.
/// 4. **Evidence** — the row-level trail, reached deliberately.
class AttendanceAdminWorkspaceScreen extends StatelessWidget {
  const AttendanceAdminWorkspaceScreen({super.key, this.cubit});

  final AdminAttendanceOverviewCubit? cubit;

  @override
  Widget build(BuildContext context) {
    const view = _WorkspaceView();
    final provided = cubit;
    if (provided != null) {
      return BlocProvider<AdminAttendanceOverviewCubit>.value(
        value: provided,
        child: view,
      );
    }
    return BlocProvider<AdminAttendanceOverviewCubit>(
      create: (_) => AppDependencies.createAdminAttendanceOverviewCubit(),
      child: view,
    );
  }
}

class _WorkspaceView extends StatefulWidget {
  const _WorkspaceView();

  @override
  State<_WorkspaceView> createState() => _WorkspaceViewState();
}

class _WorkspaceViewState extends State<_WorkspaceView> {
  bool _started = false;

  /// The active-branch set the fan-out is currently watching. Lets the cold path
  /// (the listener fires when branches load) and the warm path (bootstrap seeds
  /// it) both call [_watchBranches] without tearing down and rebuilding an
  /// identical set of streams.
  List<String>? _watching;

  late final AttendancePeriodWindow _window = weeklyWindow(DateTime.now());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  /// `BranchCubit` is an **app-level singleton** (`main.dart` provides one
  /// instance for the whole session), and the Attendance & Reports hub — the only
  /// way into this screen — already calls `loadIfNeeded()`. So by the time the
  /// workspace opens the branch list is normally *already loaded*:
  /// `loadIfNeeded()` emits nothing, a `BlocListener` alone never fires, the
  /// fan-out is never started and the screen sits on its spinner forever.
  ///
  /// Awaiting the load and then reading the cubit's own state covers the
  /// already-loaded case as well as the cold one — the same fix
  /// `attendance_history_screen.dart` documents for the same trap.
  Future<void> _bootstrap() async {
    final branchCubit = context.read<BranchCubit>();
    await branchCubit.loadIfNeeded();
    if (!mounted) return;
    _watchBranches(branchCubit.state);
  }

  void _watchBranches(BranchState state) {
    // Only a genuinely loaded list may start a fan-out. While loading, the
    // spinner is honest; on an error, an empty overview would read as "every
    // branch reported nothing", which is the one lie this screen exists to
    // prevent.
    final branches = state.maybeWhen(
      loaded: (items, _) => items,
      orElse: () => null,
    );
    if (branches == null) return;

    final active = branches.where((b) => b.isActive).toList();
    final ids = [for (final b in active) b.id];
    if (_watching != null && listEquals(_watching, ids)) return;
    _watching = ids;

    context.read<AdminAttendanceOverviewCubit>().watch(
      branchIds: ids,
      names: {for (final b in active) b.id: b.name},
      window: _window,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: 'Attendance workspace',
      subtitle: 'Is the record complete and defensible?',
      compactDesktopHeader: true,
      body: BlocListener<BranchCubit, BranchState>(
        // Still here for the cold path (branches load *after* this screen mounts)
        // and for a later refresh of the directory. It can no longer be the only
        // trigger — see [_bootstrap].
        listenWhen: (_, next) =>
            next.maybeWhen(loaded: (_, _) => true, orElse: () => false),
        listener: (context, state) => _watchBranches(state),
        child: ListView(
          key: const PageStorageKey('attendance-admin-workspace'),
          padding: EdgeInsets.fromLTRB(
            AppSpacing.pagePadding,
            AppSpacing.lg,
            AppSpacing.pagePadding,
            context.isDesktop ? AppSpacing.xxxl : AppSpacing.xxxl * 2,
          ),
          children: [_Body(window: _window)],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.window});

  final AttendancePeriodWindow window;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminAttendanceOverviewCubit, AdminAttendanceOverviewState>(
      builder: (context, state) {
        final overview = state.overview;
        if (state.status == AdminOverviewStatus.error && overview == null) {
          return _Panel(
            title: 'Workspace unavailable',
            message: state.message ?? 'Failed to load.',
            tone: AppColors.error,
          );
        }
        if (overview == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final now = DateTime.now();
        final escalations = overview.escalations(now);
        final incomplete = overview.incompleteBranches;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHero(
              eyebrow: 'Attendance / Admin',
              title: 'Attendance workspace',
              subtitle:
                  '${_weekLabel(window)} · Africa/Cairo · '
                  '${overview.branches.length} '
                  '${overview.branches.length == 1 ? 'branch' : 'branches'}',
            ),
            const SizedBox(height: AppSpacing.xl),

            if (escalations.isNotEmpty) ...[
              _Escalations(branches: escalations, now: now),
              const SizedBox(height: AppSpacing.xl),
            ],

            _DataCompleteness(overview: overview, incomplete: incomplete),
            const SizedBox(height: AppSpacing.xl),

            _AcrossBranches(overview: overview),
            const SizedBox(height: AppSpacing.xl),

            GlassContainer(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: AttendanceEvidenceTable(
                rows: overview.rows,
                branchNames: {
                  for (final b in overview.branches) b.branchId: b.branchName,
                },
              ),
            ),
          ],
        );
      },
    );
  }

  static String _weekLabel(AttendancePeriodWindow w) =>
      'Sun ${AppDateFormatter.dayMonth(w.startDate)} – '
      'Sat ${AppDateFormatter.dayMonth(w.endDate)}';
}

/// Section 1 — the only section with a name attached to a person's inbox.
class _Escalations extends StatelessWidget {
  const _Escalations({required this.branches, required this.now});

  final List<AdminBranchWeek> branches;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      highlight: true,
      accent: AppColors.warning,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Needs chasing', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.xs),
          Text(
            // Chasing an unresponsive branch is an organisational job. A manager
            // cannot be nagged twice by the same notification, so the second ask
            // belongs to a person, not to the product.
            'These branches have shifts that have gone unsettled. The manager '
            'has already been shown them.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final branch in branches)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      branch.branchName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    '${branch.blockingRows} open · oldest '
                    '${branch.oldestBlockerAgeDays(now)}d',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Section 2 — the signal that used to be the loudest thing on a store screen.
class _DataCompleteness extends StatelessWidget {
  const _DataCompleteness({required this.overview, required this.incomplete});

  final AdminAttendanceOverview overview;
  final List<AdminBranchWeek> incomplete;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Data completeness', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.xs),
          Text(
            incomplete.isEmpty
                ? 'Every branch has a whole week recorded.'
                : '${incomplete.length} of ${overview.branches.length} '
                      '${overview.branches.length == 1 ? 'branch' : 'branches'} '
                      'have days with nothing recorded. A gap is not a zero — '
                      'it usually means nobody was scheduled, and only the '
                      'branch can say which.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final branch in overview.branches) _BranchRow(branch: branch),
        ],
      ),
    );
  }
}

class _BranchRow extends StatelessWidget {
  const _BranchRow({required this.branch});

  final AdminBranchWeek branch;

  @override
  Widget build(BuildContext context) {
    final toned = branch.status.isActionable;
    return InkWell(
      borderRadius: AppRadius.mdAll,
      onTap: () => context.push(
        RouteNames.attendanceWeekly(
          '${branch.branchId}_weekly_'
          '${_key(branch.report.window.startDate)}_'
          '${_key(branch.report.window.endDate)}_v1',
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Text(
                branch.branchName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              '${branch.daysCovered}/${branch.daysTotal} days',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            SizedBox(
              width: 116,
              child: Text(
                branch.status.label,
                textAlign: TextAlign.end,
                style: AppTypography.caption.copyWith(
                  color: toned ? AppColors.warning : AppColors.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}'
      '${d.month.toString().padLeft(2, '0')}'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Section 3 — where a percentage finally earns its denominator.
class _AcrossBranches extends StatelessWidget {
  const _AcrossBranches({required this.overview});

  final AdminAttendanceOverview overview;

  @override
  Widget build(BuildContext context) {
    final s = overview.summary;
    final showUp = s.showUpRate;
    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Across branches', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.xs),
          Text(
            // The rate left the store surface in Phase 1 because at one expected
            // shift `0%` is meaningless and alarming. Pooled across branches
            // there is volume for it to mean something — and comparing branches
            // is a question only an admin has.
            'Pooled across every branch, where a percentage has enough volume '
            'to mean something.',
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (!overview.hasRows)
            Text(
              'No shifts recorded in this period yet.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else
            Wrap(
              spacing: AppSpacing.xl,
              runSpacing: AppSpacing.lg,
              children: [
                _Fact(
                  value: showUp.percent == null
                      ? '--'
                      : '${showUp.percent!.round()}%',
                  label: 'Show-up rate',
                  detail:
                      '${showUp.numerator} / ${showUp.denominator} '
                      '${showUp.denominatorLabel}',
                ),
                _Fact(
                  value: '${s.absent}',
                  label: 'Unexcused absences',
                  detail: 'Across ${s.expectedWorkShifts} scheduled shifts',
                  tone: s.absent > 0 ? AppColors.error : null,
                ),
                _Fact(
                  value: _hours(s.workedMinutes),
                  label: 'Hours worked',
                  detail: 'Across ${s.present} shifts worked',
                ),
                _Fact(
                  value: _hours(s.overtimeMinutes),
                  label: 'Overtime',
                  detail: 'Across ${s.present} shifts worked',
                ),
              ],
            ),
        ],
      ),
    );
  }

  static String _hours(int minutes) {
    if (minutes <= 0) return '0h';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.value,
    required this.label,
    required this.detail,
    this.tone,
  });

  final String value;
  final String label;
  final String detail;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Semantics(
        label: '$label: $value. $detail',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: AppTypography.h2.copyWith(
                  color: tone ?? AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            Text(detail, maxLines: 2, style: AppTypography.caption),
          ],
        ),
      ),
    );
  }
}

// The payroll hand-off section lived here. ADR-019 removed it with the rest of
// the payroll machinery: DROP is an operations system, nothing ingests a payroll
// file, and an export nobody reads is worse than none. Managers export the
// timesheet and the PDF from the weekly report itself.

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.message,
    this.tone = AppColors.warning,
  });

  final String title;
  final String message;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      highlight: true,
      accent: tone,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.h3),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
