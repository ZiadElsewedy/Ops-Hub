import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/di/injection.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/core/widgets/list_skeleton.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/widgets/status_badge.dart';
import 'package:drop/features/attendance/domain/attendance_history_gap.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_ledger_row.dart';
import 'package:drop/features/attendance/domain/attendance_history_query.dart';
import 'package:drop/features/attendance/domain/entities/attendance_entity.dart';
import 'package:drop/features/attendance/domain/reporting/attendance_period.dart';
import 'package:drop/features/attendance/presentation/history/attendance_history_cubit.dart';
import 'package:drop/features/attendance/presentation/history/attendance_history_state.dart';
import 'package:drop/features/attendance/presentation/history/widgets/attendance_history_filters.dart';
import 'package:drop/features/attendance/presentation/history/widgets/attendance_history_summary.dart';
import 'package:drop/features/attendance/presentation/reporting/attendance_report_cubit.dart';
import 'package:drop/features/attendance/presentation/history/widgets/attendance_record_card.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:drop/features/branch/presentation/cubit/branch_state.dart';

/// The **Attendance History** ledger. Two entry points share one screen:
///
/// * [AttendanceHistoryScreen.self] — the signed-in employee's own history.
/// * [AttendanceHistoryScreen.review] — a manager/admin reviewing a branch (admin
///   gets a branch picker; a manager is pinned to their own branch). An optional
///   [initialSearch] deep-links the list pre-filtered to one employee's name, and
///   [initialStart]/[initialEnd] pin it to the period the link came from — that
///   is how a report's "By person" row opens the same person over the same days.
///
/// It owns nothing but composition: a summary strip, a composable filter bar, and
/// a list of record cards, all driven by [AttendanceHistoryCubit] over the
/// existing repository reads. Tapping a card opens the record's Details screen.
class AttendanceHistoryScreen extends StatelessWidget {
  const AttendanceHistoryScreen.self({super.key})
    : mode = AttendanceHistoryMode.self,
      initialBranchId = null,
      initialSearch = null,
      initialStart = null,
      initialEnd = null;

  const AttendanceHistoryScreen.review({
    super.key,
    this.initialBranchId,
    this.initialSearch,
    this.initialStart,
    this.initialEnd,
  }) : mode = AttendanceHistoryMode.review;

  final AttendanceHistoryMode mode;
  final String? initialBranchId;
  final String? initialSearch;
  final DateTime? initialStart;
  final DateTime? initialEnd;

  @override
  Widget build(BuildContext context) {
    final user = context.currentUser;
    final isReview = mode == AttendanceHistoryMode.review;
    // Manager reviews their own branch; an admin may pass a branch (deep-link) or
    // falls back to their own, then auto-selects the first branch once the list
    // loads (handled in the view).
    final branchId = isReview ? (initialBranchId ?? user?.branchId) : null;

    return MultiBlocProvider(
      providers: [
        BlocProvider<AttendanceHistoryCubit>(
          create: (_) => AppDependencies.createAttendanceHistoryCubit(
            mode: mode,
            userId: user?.uid,
            branchId: branchId,
            initialSearch: initialSearch,
            initialStart: initialStart,
            initialEnd: initialEnd,
          )..load(),
        ),
        BlocProvider<AttendanceReportCubit>(
          create: (_) => AppDependencies.createAttendanceReportCubit(),
        ),
      ],
      child: _HistoryView(mode: mode),
    );
  }
}

class _HistoryView extends StatefulWidget {
  const _HistoryView({required this.mode});
  final AttendanceHistoryMode mode;

  @override
  State<_HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<_HistoryView> {
  bool get _isReview => widget.mode == AttendanceHistoryMode.review;

  @override
  void initState() {
    super.initState();
    if (_isReview) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapReview());
    }
  }

  /// Ensure the branch directory is loaded, then — if no branch is selected yet
  /// (an admin with no deep-linked branch) — adopt the first one. Awaiting
  /// `loadIfNeeded` covers both the "loads now" and the "already loaded" cases,
  /// where a `BlocListener` alone would miss the latter (no state change fires).
  Future<void> _bootstrapReview() async {
    final branchCubit = context.read<BranchCubit>();
    final historyCubit = context.read<AttendanceHistoryCubit>();
    await branchCubit.loadIfNeeded();
    if (!mounted) return;
    if (historyCubit.branchId != null && historyCubit.branchId!.isNotEmpty) {
      return;
    }
    final branches = branchCubit.state.maybeWhen(
      loaded: (b, _) => b,
      orElse: () => const <BranchEntity>[],
    );
    if (branches.isNotEmpty) historyCubit.selectBranch(branches.first.id);
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: _isReview ? 'Attendance history' : 'My attendance',
      subtitle: _isReview ? 'Your branch' : 'Your record',
      body: BlocBuilder<AttendanceHistoryCubit, AttendanceHistoryState>(
        builder: (context, state) => state.maybeMap(
          loaded: (s) => _Loaded(
            isReview: _isReview,
            userId: context.currentUser?.uid,
            records: s.records,
            query: s.query,
            branchId: s.branchId,
          ),
          error: (e) => _CenterMessage(message: e.message),
          orElse: () => const ListSkeleton(),
        ),
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({
    required this.isReview,
    required this.userId,
    required this.records,
    required this.query,
    required this.branchId,
  });

  final bool isReview;
  final String? userId;
  final List<AttendanceEntity> records;
  final AttendanceHistoryQuery query;
  final String? branchId;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AttendanceHistoryCubit>();

    // A plain ListView (the pattern every other DROP list screen uses) — the
    // header widgets first, then the record cards or a calm empty message.
    return RefreshIndicator(
      onRefresh: cubit.refresh,
      color: AppColors.primary,
      backgroundColor: AppColors.darkSurfaceElevated,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        children: [
          if (isReview) ...[
            _BranchPicker(selectedId: branchId),
            const SizedBox(height: AppSpacing.md),
          ],
          AttendanceHistorySummary(
            isReview: isReview,
            userId: userId,
            branchId: branchId,
            window: _reportWindow(query.resolveRange(DateTime.now())),
          ),
          const SizedBox(height: AppSpacing.lg),
          AttendanceHistoryFilters(
            query: query,
            showSearch: isReview,
            onRange: (range, {start, end}) =>
                cubit.setRange(range, customStart: start, customEnd: end),
            onStatus: cubit.setStatus,
            onToggleShift: cubit.toggleShift,
            onSearch: cubit.setSearch,
          ),
          const SizedBox(height: AppSpacing.lg),
          // Rostered shifts with no record (absences are never materialized —
          // spec R13). Without these the list contradicts the summary strip
          // directly above it, which counts them.
          ...() {
            final gaps = attendanceHistoryGaps(
              ledger: context.watch<AttendanceReportCubit>().state.rows,
              query: query,
            );
            if (records.isEmpty && gaps.isEmpty) {
              return [_EmptyMessage(hasFacets: query.hasFacets)];
            }
            return _interleave(
              records: records,
              gaps: gaps,
              isReview: isReview,
              context: context,
            );
          }(),
        ],
      ),
    );
  }
}

AttendancePeriodWindow _reportWindow(DateWindow window) =>
    AttendancePeriodWindow(startDate: window.start, endDate: window.end);

/// One chronological list, newest first, from two sources that will never be
/// one collection: written records and rostered shifts that produced none.
List<Widget> _interleave({
  required List<AttendanceEntity> records,
  required List<AttendanceHistoryGap> gaps,
  required bool isReview,
  required BuildContext context,
}) {
  final entries = <({DateTime date, Widget child})>[
    for (final r in records)
      (
        date: r.date,
        child: AttendanceRecordCard(
          record: r,
          showEmployee: isReview,
          onTap: () =>
              context.push(RouteNames.attendanceRecord(r.id), extra: r),
        ),
      ),
    for (final g in gaps)
      (date: g.date, child: _GapCard(gap: g, showEmployee: isReview)),
  ]..sort((a, b) => b.date.compareTo(a.date));

  return [
    for (final e in entries)
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: e.child,
      ),
  ];
}

/// A rostered shift with nothing recorded against it.
///
/// Deliberately quieter than a record card and **not tappable**: there is no
/// record to open, and a dead tap target teaches a manager the screen is broken.
/// It states the fact and where the fix lives.
class _GapCard extends StatelessWidget {
  const _GapCard({required this.gap, required this.showEmployee});

  final AttendanceHistoryGap gap;
  final bool showEmployee;

  @override
  Widget build(BuildContext context) {
    final absent = gap.outcome == AttendanceLedgerOutcome.absent;
    final tone = absent ? AppColors.error : AppColors.textSecondary;
    final name = (gap.userName ?? '').trim();

    return GlassContainer(
      elevated: false,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 34,
            decoration: BoxDecoration(
              color: tone,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  showEmployee && name.isNotEmpty
                      ? name
                      : AppDateFormatter.weekdayDayMonth(gap.date),
                  style: AppTypography.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  showEmployee && name.isNotEmpty
                      ? '${AppDateFormatter.weekdayDayMonth(gap.date)} · '
                            '${gap.shift.label}'
                      : gap.shift.label,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          StatusBadge(label: gap.label, color: tone, compact: true),
        ],
      ),
    );
  }
}

/// A calm inline empty state for the ledger — distinguishes "no matches for these
/// filters" from "nothing recorded this period".
class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({required this.hasFacets});
  final bool hasFacets;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: [
          const Icon(
            Icons.event_busy_outlined,
            size: 40,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            hasFacets ? 'No matches' : 'Nothing here',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            hasFacets
                ? 'No attendance matches these filters. Try widening the date '
                      'range or clearing a filter.'
                : 'No attendance was recorded for this period.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Admin branch selector for the review ledger — a quiet dropdown fed by the
/// app-wide [BranchCubit] directory. Hidden for a single-branch estate or a
/// manager (who is pinned to their own branch).
class _BranchPicker extends StatelessWidget {
  const _BranchPicker({required this.selectedId});
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    if (!context.isAdmin) return const SizedBox.shrink();
    return BlocBuilder<BranchCubit, BranchState>(
      builder: (context, state) {
        final branches = state.maybeWhen(
          loaded: (b, _) => b,
          orElse: () => const <BranchEntity>[],
        );
        if (branches.length < 2) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: AppColors.darkSurfaceElevated,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: branches.any((b) => b.id == selectedId)
                  ? selectedId
                  : null,
              isExpanded: true,
              isDense: true,
              borderRadius: AppRadius.lgAll,
              dropdownColor: AppColors.darkSurfaceElevated,
              hint: const Text(
                'Select a branch',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 14),
              ),
              icon: const Icon(
                Icons.expand_more_rounded,
                color: AppColors.textSecondary,
              ),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              onChanged: (v) {
                if (v != null) {
                  context.read<AttendanceHistoryCubit>().selectBranch(v);
                }
              },
              items: [
                for (final b in branches)
                  DropdownMenuItem(value: b.id, child: Text(b.name)),
              ],
            ),
          ),
        );
      },
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
