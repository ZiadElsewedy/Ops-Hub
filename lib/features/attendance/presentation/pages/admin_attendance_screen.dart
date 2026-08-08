import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/app_snackbar.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/core/widgets/premium_button.dart';
import 'package:drop/core/widgets/stat_strip.dart';
import 'package:drop/features/attendance/domain/attendance_board.dart';
import 'package:drop/features/attendance/domain/attendance_review_link.dart';
import 'package:drop/features/attendance/domain/attendance_gps.dart';
import 'package:drop/features/attendance/domain/entities/attendance_correction.dart';
import 'package:drop/features/attendance/presentation/cubit/attendance_admin_cubit.dart';
import 'package:drop/features/attendance/presentation/cubit/attendance_admin_state.dart';
import 'package:drop/features/attendance/presentation/widgets/attendance_manager_actions.dart';
import 'package:drop/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:drop/features/auth/presentation/cubit/auth_state.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:drop/features/branch/presentation/cubit/branch_state.dart';
import 'package:drop/features/branch/presentation/pages/branch_geofence_editor_screen.dart';

/// The manager/admin **Today** destination. It is the live roster × attendance
/// board: managers stay pinned to their own branch while admins choose a branch
/// before the board loads. Reports and the per-person ledger are next steps, not
/// competing landing pages.
class AdminAttendanceScreen extends StatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  State<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen> {
  int _tab = 0; // 0 = Today's board, 1 = Corrections
  AttendanceBoardStatus? _filter;
  bool _bootstrapped = false;
  String? _selectedBranchId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStart());
  }

  Future<void> _maybeStart() async {
    if (_bootstrapped) return;
    final user = context.currentUser;
    if (user == null) return;
    _bootstrapped = true;
    if (!user.role.isAdmin) {
      await context.read<AttendanceAdminCubit>().load(
        user,
        branchId: user.branchId,
      );
      return;
    }
    // BranchCubit is app-level. Await + read covers the already-loaded case,
    // where loadIfNeeded deliberately emits nothing.
    await context.read<BranchCubit>().loadIfNeeded();
    if (mounted) setState(() {});
  }

  Future<void> _selectBranch(String branchId) async {
    final user = context.currentUser;
    if (user == null) return;
    setState(() => _selectedBranchId = branchId);
    await context.read<AttendanceAdminCubit>().load(user, branchId: branchId);
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: 'Today',
      // No subtitle: the counts and the grouped rows below say what this is
      // better than a sentence restating them.
      subtitle: null,
      actions: [
        IconButton(
          tooltip: 'Find a person',
          onPressed: () => context.push(RouteNames.attendanceReview),
          icon: const Icon(
            Icons.person_search_rounded,
            color: AppColors.textSecondary,
          ),
        ),
        IconButton(
          tooltip: 'Reports',
          onPressed: () => context.push(RouteNames.attendanceReportsHub),
          icon: const Icon(
            Icons.assessment_outlined,
            color: AppColors.textSecondary,
          ),
        ),
      ],
      body: BlocListener<AuthCubit, AuthState>(
        listenWhen: (previous, next) =>
            next.maybeWhen(authenticated: (_) => true, orElse: () => false) &&
            !previous.maybeWhen(
              authenticated: (_) => true,
              orElse: () => false,
            ),
        listener: (context, _) => _maybeStart(),
        child: BlocBuilder<BranchCubit, BranchState>(
          builder: (context, branchState) {
            final branches = branchState.maybeWhen(
              loaded: (items, _) => items.where((b) => b.isActive).toList(),
              orElse: () => const <BranchEntity>[],
            );
            final user = context.currentUser;
            if (user?.role.isAdmin == true && _selectedBranchId == null) {
              return _NoBranchSelected(
                branches: branches,
                onSelect: _selectBranch,
              );
            }
            return BlocConsumer<AttendanceAdminCubit, AttendanceAdminState>(
              listenWhen: (_, s) =>
                  s.maybeMap(error: (_) => true, orElse: () => false),
              listener: (context, state) => state.mapOrNull(
                error: (e) => AppSnackbar.error(context, e.message),
              ),
              builder: (context, state) => state.maybeMap(
                loaded: (s) => _Dashboard(
                  branchId: s.branchId,
                  branches: s.branches,
                  board: s.board,
                  corrections: s.corrections,
                  now: s.now,
                  deciding: s.deciding,
                  tab: _tab,
                  filter: _filter,
                  onTab: (t) => setState(() => _tab = t),
                  onFilter: (f) =>
                      setState(() => _filter = _filter == f ? null : f),
                  isAdmin: user?.role.isAdmin == true,
                ),
                error: (e) => _CenterMessage(message: e.message),
                orElse: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xxl),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({
    required this.branchId,
    required this.branches,
    required this.board,
    required this.corrections,
    required this.now,
    required this.deciding,
    required this.tab,
    required this.filter,
    required this.onTab,
    required this.onFilter,
    required this.isAdmin,
  });

  final String branchId;
  final List<BranchEntity> branches;
  final AttendanceBoard board;
  final List<AttendanceCorrectionEntity> corrections;
  final DateTime now;
  final bool deciding;
  final int tab;
  final AttendanceBoardStatus? filter;
  final ValueChanged<int> onTab;
  final ValueChanged<AttendanceBoardStatus> onFilter;
  final bool isAdmin;

  BranchEntity? get _branch {
    for (final b in branches) {
      if (b.id == branchId) return b;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AttendanceAdminCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pagePadding,
            AppSpacing.pagePadding,
            AppSpacing.pagePadding,
            0,
          ),
          child: _Header(
            branches: branches,
            branchId: branchId,
            now: now,
            branch: _branch,
            onSelect: isAdmin ? cubit.selectBranch : null,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePadding,
          ),
          child: _Segmented(
            tab: tab,
            correctionCount: corrections.length,
            onTab: onTab,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => cubit.refresh(),
            color: AppColors.primary,
            backgroundColor: AppColors.darkSurfaceElevated,
            child: tab == 0
                ? _BoardView(
                    board: board,
                    branchId: branchId,
                    filter: filter,
                    onFilter: onFilter,
                  )
                : _CorrectionsView(
                    corrections: corrections,
                    deciding: deciding,
                    onDecide: (c, approve) =>
                        cubit.decideCorrection(c, approve: approve),
                  ),
          ),
        ),
      ],
    );
  }
}

class _NoBranchSelected extends StatelessWidget {
  const _NoBranchSelected({required this.branches, required this.onSelect});

  final List<BranchEntity> branches;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (branches.isEmpty) {
      return const Center(
        child: Text(
          'No branch is available yet.',
          style: TextStyle(color: AppColors.textTertiary),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        child: GlassContainer(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Choose a branch', style: AppTypography.h2),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Select a branch to see who is present, late, absent, or needs a decision today.',
                  style: AppTypography.body,
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final branch in branches)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: SizedBox(
                      width: double.infinity,
                      child: PremiumButton(
                        label: branch.name,
                        icon: Icons.store_outlined,
                        style: PremiumButtonStyle.tonal,
                        onPressed: () => onSelect(branch.id),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Header: branch picker + date + geofence shortcut ─────────────────────
class _Header extends StatelessWidget {
  const _Header({
    required this.branches,
    required this.branchId,
    required this.now,
    required this.branch,
    required this.onSelect,
  });
  final List<BranchEntity> branches;
  final String branchId;
  final DateTime now;
  final BranchEntity? branch;
  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (onSelect != null && branches.length > 1)
                _BranchDropdown(
                  branches: branches,
                  branchId: branchId,
                  onSelect: onSelect!,
                )
              else
                Text(
                  branch?.name ?? 'Branch',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              const SizedBox(height: 2),
              Text(
                'Today · ${AppDateFormatter.weekdayDayMonth(now)}',
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        // Geofence shortcut — only meaningful when a branch is resolved.
        if (branch != null)
          IconButton(
            tooltip: branch!.hasGeofence ? 'GPS area' : 'Set GPS area',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BranchGeofenceEditorScreen(branch: branch!),
              ),
            ),
            icon: Icon(
              branch!.hasGeofence
                  ? Icons.my_location_rounded
                  : Icons.location_searching_rounded,
              color: branch!.hasGeofence
                  ? AppColors.textSecondary
                  : AppColors.warning,
            ),
          ),
      ],
    );
  }
}

class _BranchDropdown extends StatelessWidget {
  const _BranchDropdown({
    required this.branches,
    required this.branchId,
    required this.onSelect,
  });
  final List<BranchEntity> branches;
  final String branchId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: branchId,
        isDense: true,
        borderRadius: AppRadius.lgAll,
        dropdownColor: AppColors.darkSurfaceElevated,
        icon: const Icon(
          Icons.expand_more_rounded,
          color: AppColors.textSecondary,
        ),
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
        onChanged: (v) {
          if (v != null) onSelect(v);
        },
        items: [
          for (final b in branches)
            DropdownMenuItem(value: b.id, child: Text(b.name)),
        ],
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.tab,
    required this.correctionCount,
    required this.onTab,
  });
  final int tab;
  final int correctionCount;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          _seg('Today', 0),
          _seg(
            correctionCount > 0
                ? 'Corrections ($correctionCount)'
                : 'Corrections',
            1,
          ),
        ],
      ),
    );
  }

  Widget _seg(String label, int index) {
    final selected = tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTab(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: AppRadius.smAll,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.onPrimary : AppColors.textSecondary,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Board tab: KPI strip + roster rows ───────────────────────────────────
class _BoardView extends StatelessWidget {
  const _BoardView({
    required this.board,
    required this.branchId,
    required this.filter,
    required this.onFilter,
  });
  final AttendanceBoard board;
  final String branchId;
  final AttendanceBoardStatus? filter;
  final ValueChanged<AttendanceBoardStatus> onFilter;

  @override
  Widget build(BuildContext context) {
    final needsDecision = board.rows
        .where(
          (row) =>
              row.status == AttendanceBoardStatus.unscheduled ||
              row.status == AttendanceBoardStatus.pendingReview,
        )
        .toList();
    final present = board.rows
        .where(
          (row) =>
              row.status == AttendanceBoardStatus.working ||
              row.status == AttendanceBoardStatus.completed,
        )
        .toList();
    final late = board.rows.where((row) => row.isLate).toList();
    final absent = board.withStatus(AttendanceBoardStatus.absent);
    final groups = <_BoardGroup>[
      _BoardGroup('Needs a decision', needsDecision, AppColors.warning),
      _BoardGroup('Present / working now', present, AppColors.success),
      _BoardGroup('Late', late, AppColors.warning),
      _BoardGroup('Absent', absent, AppColors.error),
    ];
    final visibleGroups = filter == null
        ? groups
        : groups
              .where(
                (group) => switch (filter) {
                  AttendanceBoardStatus.working =>
                    group.title == 'Present / working now',
                  AttendanceBoardStatus.late => group.title == 'Late',
                  AttendanceBoardStatus.absent => group.title == 'Absent',
                  _ => true,
                },
              )
              .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        0,
        AppSpacing.pagePadding,
        AppSpacing.xl,
      ),
      children: [
        StatStrip(
          stats: [
            Stat(
              label: 'Present',
              count: board.present,
              tone: AppColors.success,
            ),
            Stat(
              label: 'Late',
              count: board.late,
              tone: AppColors.warning,
              onTap: () => onFilter(AttendanceBoardStatus.late),
            ),
            Stat(
              label: 'Absent',
              count: board.absent,
              tone: AppColors.error,
              onTap: () => onFilter(AttendanceBoardStatus.absent),
            ),
            Stat(
              label: 'Needs review',
              count: needsDecision.length,
              tone: AppColors.warning,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _SummaryLine(board: board),
        const SizedBox(height: AppSpacing.lg),
        for (final group in visibleGroups)
          if (group.rows.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              '${group.title} · ${group.rows.length}',
              style: AppTypography.labelLarge.copyWith(color: group.tone),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final row in group.rows)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _BoardRow(row: row, branchId: branchId),
              ),
          ],
        if (visibleGroups.every((group) => group.rows.isEmpty))
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: Text(
              'No attendance changes to show yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textTertiary),
            ),
          ),
      ],
    );
  }
}

class _BoardGroup {
  const _BoardGroup(this.title, this.rows, this.tone);
  final String title;
  final List<AttendanceBoardRow> rows;
  final Color tone;
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.board});
  final AttendanceBoard board;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${board.present} of ${board.rostered} present · '
      '${board.completed} done · ${board.notStarted} not started · '
      '${board.onLeave} on leave',
      style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
    );
  }
}

class _BoardRow extends StatelessWidget {
  const _BoardRow({required this.row, required this.branchId});
  final AttendanceBoardRow row;
  final String branchId;

  @override
  Widget build(BuildContext context) {
    final (Color tint, _) = _statusStyle(row.status);
    final record = row.record;
    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => _showDetails(context, row, branchId),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 38,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // Every text here must be able to give ground: on a phone the
                // name column can fall to ~120px, and a Row of rigid children
                // overflows rather than compressing.
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        row.shift.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (record != null && record.clockIn != null) ...[
                      const Text(
                        '  ·  ',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                      Icon(
                        row.isVerified
                            ? Icons.gps_fixed_rounded
                            : (row.hasGps
                                  ? Icons.gps_off_rounded
                                  : Icons.location_disabled_rounded),
                        size: 12,
                        color: row.isVerified
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          AppDateFormatter.time(record.clockIn!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          _StatusChip(status: row.status, late: row.isLate),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.late});
  final AttendanceBoardStatus status;
  final bool late;

  @override
  Widget build(BuildContext context) {
    final (tint, label) = _statusStyle(status);
    // A late arrival still working/completed gets a "· late" hint.
    final showLate = late && status != AttendanceBoardStatus.late;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: AppRadius.fullAll,
      ),
      child: Text(
        showLate ? '$label · late' : label,
        style: TextStyle(
          color: tint,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── Attendance details sheet ─────────────────────────────────────────────
void _showDetails(
  BuildContext context,
  AttendanceBoardRow row,
  String branchId,
) {
  final r = row.record;
  final cubit = context.read<AttendanceAdminCubit>();
  // A reviewer may never settle their OWN shift (no self-approval — enforced in
  // `firestore.rules`). Keyed on uid so it holds even for an absent row with no
  // record yet; on the own row the write actions are replaced by a notice.
  final isOwnRow = context.currentUser?.uid == row.uid;
  // Which manager actions apply (all reuse the existing cubit + validation).
  final canResolve = !isOwnRow && r != null && r.needsReview;
  final isUnscheduled =
      !isOwnRow && r != null && row.status == AttendanceBoardStatus.unscheduled;
  final canAddOrExcuse =
      !isOwnRow &&
      r == null &&
      (row.status == AttendanceBoardStatus.absent ||
          row.status == AttendanceBoardStatus.late);
  // Whether this own row would otherwise have offered a write action.
  final ownRowHadActions =
      isOwnRow &&
      (r != null && r.needsReview ||
          r != null && row.status == AttendanceBoardStatus.unscheduled ||
          r == null &&
              (row.status == AttendanceBoardStatus.absent ||
                  row.status == AttendanceBoardStatus.late));

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.darkSurface,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          0,
          AppSpacing.pagePadding,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              row.name,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '${row.shift.label} · ${row.status.label}',
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (r != null) ...[
              _DetailClock(
                label: 'Clock in',
                time: r.clockIn,
                verification: r.clockInVerification,
              ),
              const SizedBox(height: AppSpacing.sm),
              _DetailClock(
                label: 'Clock out',
                time: r.clockOut,
                verification: r.clockOutVerification,
              ),
              const SizedBox(height: AppSpacing.md),
              _DetailStat(label: 'Worked', value: _hm(r.workedMinutes)),
              if (r.lateMinutes > 0)
                _DetailStat(label: 'Late by', value: _hm(r.lateMinutes)),
              if (r.overtimeMinutes > 0)
                _DetailStat(label: 'Overtime', value: _hm(r.overtimeMinutes)),
            ] else
              const Text(
                'No record for this shift yet.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            const SizedBox(height: AppSpacing.lg),

            // ── Manager write actions ──
            if (isUnscheduled) ...[
              PremiumButton(
                label: 'Mark present',
                icon: Icons.check_circle_outline_rounded,
                style: PremiumButtonStyle.filled,
                onPressed: () => resolveShiftDirectly(
                  context,
                  cubit,
                  r,
                  dismissContext: sheetContext,
                  title: 'Mark present',
                  subtitle:
                      'He was working. Confirm the times and leave an audit note.',
                  submitLabel: 'Mark present',
                  appliedMessage: 'Marked present.',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Not sure? Leave the clock-in unapproved.',
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              PremiumButton(
                label: 'Leave unapproved',
                icon: Icons.more_time_outlined,
                style: PremiumButtonStyle.tonal,
                onPressed: () => Navigator.of(sheetContext).pop(),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (canResolve) ...[
              PremiumButton(
                label: 'Resolve shift',
                icon: Icons.fact_check_outlined,
                style: PremiumButtonStyle.filled,
                onPressed: () => resolveShiftDirectly(
                  context,
                  cubit,
                  r,
                  dismissContext: sheetContext,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (canAddOrExcuse) ...[
              PremiumButton(
                label: 'Add record',
                icon: Icons.add_task_rounded,
                style: PremiumButtonStyle.filled,
                onPressed: () => addAttendanceRecord(
                  context,
                  cubit,
                  row,
                  dismissContext: sheetContext,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              PremiumButton(
                label: 'Excuse absence',
                icon: Icons.event_available_outlined,
                style: PremiumButtonStyle.tonal,
                onPressed: () => excuseAttendanceAbsence(
                  context,
                  cubit,
                  row,
                  dismissContext: sheetContext,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],

            if (ownRowHadActions) ...[
              const OwnAttendanceNotice(),
              const SizedBox(height: AppSpacing.sm),
            ],

            if (r != null)
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    context.push(RouteNames.attendanceRecord(r.id), extra: r);
                  },
                  icon: const Icon(Icons.open_in_full_rounded, size: 16),
                  label: const Text('View full record'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  context.push(
                    RouteNames.attendanceReview,
                    extra: AttendanceReviewLink(
                      employeeName: row.name,
                      branchId: branchId,
                    ),
                  );
                },
                icon: const Icon(Icons.history_rounded, size: 16),
                label: const Text('History'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DetailClock extends StatelessWidget {
  const _DetailClock({
    required this.label,
    required this.time,
    required this.verification,
  });
  final String label;
  final DateTime? time;
  final AttendanceVerification? verification;

  @override
  Widget build(BuildContext context) {
    final v = verification;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time == null ? '—' : AppDateFormatter.time(time!),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          if (v != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Icon(
                      v.verified
                          ? Icons.where_to_vote_rounded
                          : Icons.wrong_location_outlined,
                      size: 15,
                      color: v.verified ? AppColors.success : AppColors.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      v.verified ? 'At branch' : 'Off-site',
                      style: TextStyle(
                        color: v.verified
                            ? AppColors.success
                            : AppColors.warning,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${v.distanceMeters.round()} m · '
                  '±${(v.location.accuracyMeters ?? 0).round()} m',
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            )
          else
            const Text(
              'No GPS',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  const _DetailStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const Spacer(),
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
      ),
    );
  }
}

// ─── Corrections tab ──────────────────────────────────────────────────────
class _CorrectionsView extends StatelessWidget {
  const _CorrectionsView({
    required this.corrections,
    required this.deciding,
    required this.onDecide,
  });
  final List<AttendanceCorrectionEntity> corrections;
  final bool deciding;
  final void Function(AttendanceCorrectionEntity, bool approve) onDecide;

  @override
  Widget build(BuildContext context) {
    if (corrections.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          Icon(Icons.inbox_rounded, size: 44, color: AppColors.textTertiary),
          SizedBox(height: AppSpacing.md),
          Text(
            'No pending corrections',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        0,
        AppSpacing.pagePadding,
        AppSpacing.xl,
      ),
      itemCount: corrections.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: _CorrectionCard(
          correction: corrections[i],
          deciding: deciding,
          onDecide: onDecide,
        ),
      ),
    );
  }
}

class _CorrectionCard extends StatelessWidget {
  const _CorrectionCard({
    required this.correction,
    required this.deciding,
    required this.onDecide,
  });
  final AttendanceCorrectionEntity correction;
  final bool deciding;
  final void Function(AttendanceCorrectionEntity, bool approve) onDecide;

  @override
  Widget build(BuildContext context) {
    final c = correction;
    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  c.userName ?? 'Employee',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: AppRadius.fullAll,
                ),
                child: Text(
                  c.kind.label,
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            c.reason,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
          if (c.proposedClockIn != null || c.proposedClockOut != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              [
                if (c.proposedClockIn != null)
                  'In → ${AppDateFormatter.time(c.proposedClockIn!)}',
                if (c.proposedClockOut != null)
                  'Out → ${AppDateFormatter.time(c.proposedClockOut!)}',
              ].join('   ·   '),
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _DecisionButton(
                  label: 'Reject',
                  tone: AppColors.error,
                  filled: false,
                  onTap: deciding ? null : () => onDecide(c, false),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _DecisionButton(
                  label: 'Approve',
                  tone: AppColors.success,
                  filled: true,
                  onTap: deciding ? null : () => onDecide(c, true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DecisionButton extends StatelessWidget {
  const _DecisionButton({
    required this.label,
    required this.tone,
    required this.filled,
    required this.onTap,
  });
  final String label;
  final Color tone;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: filled
          ? (enabled ? tone : AppColors.darkSurfaceElevated)
          : Colors.transparent,
      borderRadius: AppRadius.buttonAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.buttonAll,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: AppRadius.buttonAll,
            border: filled
                ? null
                : Border.all(color: tone.withValues(alpha: 0.6)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: filled
                  ? (enabled ? AppColors.onPrimary : AppColors.textTertiary)
                  : tone,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _CenterMessage extends StatelessWidget {
  const _CenterMessage({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textTertiary),
        ),
      ),
    );
  }
}

(Color, String) _statusStyle(AttendanceBoardStatus s) => switch (s) {
  AttendanceBoardStatus.working => (AppColors.success, 'Working'),
  AttendanceBoardStatus.completed => (AppColors.textSecondary, 'Completed'),
  AttendanceBoardStatus.late => (AppColors.warning, 'Late'),
  AttendanceBoardStatus.absent => (AppColors.error, 'Absent'),
  AttendanceBoardStatus.notStarted => (AppColors.textTertiary, 'Not started'),
  AttendanceBoardStatus.onLeave => (AppColors.warning, 'On leave'),
  AttendanceBoardStatus.excused => (AppColors.textSecondary, 'Excused'),
  AttendanceBoardStatus.pendingReview => (AppColors.warning, 'Needs review'),
  AttendanceBoardStatus.unscheduled => (AppColors.warning, 'Unscheduled'),
};

String _two(int n) => n.toString().padLeft(2, '0');
String _hm(int minutes) {
  final m = minutes < 0 ? 0 : minutes;
  return '${_two(m ~/ 60)}h ${_two(m % 60)}m';
}
