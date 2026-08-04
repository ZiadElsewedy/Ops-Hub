import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/di/injection.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/responsive/breakpoints.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/app_snackbar.dart';
import 'package:drop/core/widgets/glass_container.dart';
import 'package:drop/core/widgets/premium_button.dart';
import 'package:drop/core/widgets/app_error_state.dart';
import 'package:drop/features/attendance/domain/attendance_board.dart';
import 'package:drop/features/attendance/domain/attendance_id.dart';
import 'package:drop/features/attendance/domain/daily_review.dart';
import 'package:drop/features/attendance/presentation/cubit/attendance_admin_cubit.dart';
import 'package:drop/features/attendance/presentation/cubit/attendance_admin_state.dart';
import 'package:drop/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:drop/features/auth/presentation/cubit/auth_state.dart';
import 'package:drop/features/attendance/presentation/widgets/attendance_manager_actions.dart';
import 'package:drop/core/widgets/skeleton.dart';

/// **Daily Review** — where a manager settles yesterday in about two minutes.
///
/// The layer the weekly report was doing badly. Without it every exception in a
/// week surfaces at once, seven days late, inside a reporting surface with no
/// action on it. With it, Weekly gets to be a summary of days already settled —
/// which is why Phase 1 could take eight sections down to five.
///
/// Three zones, fixed order, no configuration:
/// 1. **Needs you** — the only zone with verbs. Ordered by cost of being wrong.
/// 2. **The day** — four facts, one line. Confirmation, not analysis.
/// 3. **Everyone** — collapsed. The full roster, opened deliberately.
///
/// Reads the roster × records board, not the reporting ledger: this is an
/// operational surface, and the ledger is the *reporting* truth for closed
/// periods. Every write goes through the same `AttendanceAdminCubit` paths the
/// live board uses — no new decision semantics (`ATTENDANCE_SPEC` R11/R12/R14).
class AttendanceDailyReviewScreen extends StatelessWidget {
  const AttendanceDailyReviewScreen({
    super.key,
    required this.branchId,
    required this.dayKey,
    this.cubit,
  });

  final String branchId;
  final String dayKey;
  final AttendanceAdminCubit? cubit;

  @override
  Widget build(BuildContext context) {
    final date = parseAttendanceDayKey(dayKey);
    final view = _DailyReviewView(branchId: branchId, date: date);
    final provided = cubit;
    if (provided != null) {
      return BlocProvider<AttendanceAdminCubit>.value(
        value: provided,
        child: view,
      );
    }
    return BlocProvider<AttendanceAdminCubit>(
      create: (_) => AppDependencies.createAttendanceDailyReviewCubit(),
      child: view,
    );
  }
}

class _DailyReviewView extends StatefulWidget {
  const _DailyReviewView({required this.branchId, required this.date});

  final String branchId;
  final DateTime? date;

  @override
  State<_DailyReviewView> createState() => _DailyReviewViewState();
}

class _DailyReviewViewState extends State<_DailyReviewView> {
  /// Spent only **once the load is actually dispatched**. Flipping it before the
  /// preconditions are checked would burn the one-shot on a pass that bailed
  /// out, and the board would sit on its spinner for the rest of the screen's
  /// life.
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeStart();
  }

  /// Idempotent, and called from both entry points below.
  ///
  /// `context.currentUser` reads `AuthCubit` **without** subscribing, so a null
  /// user here does not re-trigger `didChangeDependencies` on its own — the
  /// `BlocListener` in [build] is what covers the session arriving late. Between
  /// them: already signed in (the normal case) starts here, and a session that
  /// resolves after this screen mounts starts there.
  void _maybeStart() {
    if (_started) return;
    final date = widget.date;
    final user = context.currentUser;
    // A null date is a malformed deep link — [build] renders an explicit panel
    // for it and there is nothing to load.
    if (date == null || user == null) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AttendanceAdminCubit>().load(
        user,
        branchId: widget.branchId,
        businessDate: date,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final date = widget.date;
    return BlocListener<AuthCubit, AuthState>(
      // The session arriving after this screen mounted — a deep link opened
      // before auth finished restoring. Without this the load would never be
      // attempted again (see [_maybeStart]).
      listenWhen: (prev, next) =>
          next.maybeWhen(authenticated: (_) => true, orElse: () => false) &&
          !prev.maybeWhen(authenticated: (_) => true, orElse: () => false),
      listener: (context, _) => _maybeStart(),
      child: AdaptiveScaffold(
        title: 'Daily review',
        subtitle: date == null ? null : AppDateFormatter.weekdayDayMonth(date),
        compactDesktopHeader: true,
        body: ListView(
          key: const PageStorageKey('attendance-daily-review'),
          padding: EdgeInsets.fromLTRB(
            AppSpacing.pagePadding,
            AppSpacing.lg,
            AppSpacing.pagePadding,
            context.isDesktop ? AppSpacing.xxxl : AppSpacing.xxxl * 2,
          ),
          children: [
            if (date == null)
              const AppProblemPanel(
                title: 'That day link is not valid',
                message:
                    'Open Daily review from a day row on the weekly report.',
                icon: Icons.link_off_rounded,
              )
            else
              _DailyReviewBody(branchId: widget.branchId, date: date),
          ],
        ),
      ),
    );
  }
}

class _DailyReviewBody extends StatelessWidget {
  const _DailyReviewBody({required this.branchId, required this.date});

  final String branchId;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final user = context.currentUser;
    if ((user?.role ?? UserRole.employee).isManager &&
        user?.branchId != branchId) {
      return const AppProblemPanel(
        title: 'Daily review unavailable',
        message: 'This manager account cannot review another branch.',
        icon: Icons.lock_outline_rounded,
      );
    }

    return BlocConsumer<AttendanceAdminCubit, AttendanceAdminState>(
      listenWhen: (prev, next) =>
          next.maybeMap(error: (_) => true, orElse: () => false),
      listener: (context, state) {
        state.maybeMap(
          error: (e) => AppSnackbar.error(context, e.message),
          orElse: () {},
        );
      },
      builder: (context, state) => state.maybeMap(
        loaded: (s) => _Loaded(date: date, board: s.board),
        error: (e) => AppProblemPanel(
          title: 'Daily review unavailable',
          message: e.message,
          icon: Icons.error_outline_rounded,
          tone: AppColors.error,
        ),
        orElse: () => const _LoadingPanel(),
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.date, required this.board});

  final DateTime date;
  final AttendanceBoard board;

  @override
  Widget build(BuildContext context) {
    final review = DailyReview.fromBoard(board);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DayHeader(date: date, review: review),
        const SizedBox(height: AppSpacing.xl),
        if (review.items.isNotEmpty) ...[
          _NeedsYou(items: review.items),
          const SizedBox(height: AppSpacing.xl),
        ],
        _TheDay(review: review),
        const SizedBox(height: AppSpacing.xl),
        _Everyone(rows: board.rows),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.date, required this.review});

  final DateTime date;
  final DailyReview review;

  @override
  Widget build(BuildContext context) {
    final count = review.items.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppDateFormatter.weekdayDayMonth(date),
          style: AppTypography.h2,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          // The most common state, and the fastest to read. A clean day is the
          // expectation, not an achievement — anything more than one line of
          // confirmation teaches the manager to skim, and a manager who skims a
          // clean day will skim a dirty one.
          count == 0
              ? 'Nothing needs you.'
              : '$count ${count == 1 ? 'thing needs' : 'things need'} you.',
          style: AppTypography.bodySmall.copyWith(
            color: count == 0 ? AppColors.textTertiary : AppColors.warning,
          ),
        ),
      ],
    );
  }
}

/// Zone 1 — the only zone with verbs.
class _NeedsYou extends StatelessWidget {
  const _NeedsYou({required this.items});

  final List<DailyReviewItem> items;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      highlight: true,
      accent: AppColors.warning,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Needs you', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(
                height: 1,
                color: AppColors.darkBorder,
                margin: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              ),
            _ReviewRow(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.item});

  final DailyReviewItem item;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AttendanceAdminCubit>();
    final row = item.row;
    final record = row.record;

    // Never a severity label — no "blocking", no "exception class". The order
    // communicates priority; a taxonomy does not need to be shown to be used.
    final actions = <Widget>[
      if (item.kind == DailyReviewKind.missingClockOut && record != null)
        PremiumButton(
          label: 'Set the time',
          icon: Icons.schedule_rounded,
          style: PremiumButtonStyle.filled,
          onPressed: () => resolveShiftDirectly(context, cubit, record),
        ),
      if (item.kind == DailyReviewKind.unscheduledWork && record != null) ...[
        PremiumButton(
          label: 'Approve',
          icon: Icons.check_rounded,
          style: PremiumButtonStyle.filled,
          onPressed: () => resolveShiftDirectly(
            context,
            cubit,
            record,
            title: 'Approve unscheduled shift',
            subtitle: 'Confirm the hours ${row.name} actually worked. Once '
                'approved the time counts.',
            submitLabel: 'Approve',
            appliedMessage: 'Unscheduled shift approved.',
          ),
        ),
        // Same single write path as an excused absence — zero worked minutes
        // with a mandatory reason — but a manager rejecting an unrecognised
        // punch is not "excusing" anything, so it must not say so.
        PremiumButton(
          label: 'Reject',
          icon: Icons.block_rounded,
          style: PremiumButtonStyle.tonal,
          onPressed: () => excuseAttendanceAbsence(
            context,
            cubit,
            row,
            title: 'Reject unscheduled shift',
            subtitle: 'Zero the hours and say why. ${row.name} sees the '
                'reason.',
            submitLabel: 'Reject',
            appliedMessage: 'Unscheduled shift rejected.',
          ),
        ),
      ],
      if (item.kind == DailyReviewKind.noShow) ...[
        PremiumButton(
          label: 'They worked',
          icon: Icons.add_task_rounded,
          style: PremiumButtonStyle.filled,
          onPressed: () => addAttendanceRecord(context, cubit, row),
        ),
        PremiumButton(
          label: 'Excuse',
          icon: Icons.event_available_outlined,
          style: PremiumButtonStyle.tonal,
          onPressed: () => excuseAttendanceAbsence(context, cubit, row),
        ),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A person's name and a plain fact — never a record id, never a code.
        Text(item.headline, style: AppTypography.labelLarge),
        const SizedBox(height: 2),
        Text(
          item.detail,
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: actions,
          ),
        ],
      ],
    );
  }
}

/// Zone 2 — four facts, one line. Confirmation, not analysis.
class _TheDay extends StatelessWidget {
  const _TheDay({required this.review});

  final DailyReview review;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The day',
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(review.summaryLine, style: AppTypography.h3),
          if (review.lateArrivals > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${review.lateArrivals} late '
              '${review.lateArrivals == 1 ? 'arrival' : 'arrivals'}',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Zone 3 — collapsed by default, opened deliberately, never in the way.
class _Everyone extends StatefulWidget {
  const _Everyone({required this.rows});

  final List<AttendanceBoardRow> rows;

  @override
  State<_Everyone> createState() => _EveryoneState();
}

class _EveryoneState extends State<_Everyone> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    if (rows.isEmpty) {
      return GlassContainer(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          'Nobody was scheduled on this day.',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }
    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: AppRadius.mdAll,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _open
                          ? 'Everyone'
                          : 'Show all ${rows.length} '
                                '${rows.length == 1 ? 'shift' : 'shifts'}',
                      style: AppTypography.h3,
                    ),
                  ),
                  Icon(
                    _open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_open) ...[
            const SizedBox(height: AppSpacing.md),
            for (final row in rows) _EveryoneRow(row: row),
          ],
        ],
      ),
    );
  }
}

class _EveryoneRow extends StatelessWidget {
  const _EveryoneRow({required this.row});

  final AttendanceBoardRow row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              row.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            dailyOutcomeLabel(row),
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    // Skeleton over spinner: the panel keeps the shape of what is arriving.
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        children: [
          Skeleton(height: 84, borderRadius: AppRadius.cardAll),
          SizedBox(height: AppSpacing.md),
          Skeleton(height: 84, borderRadius: AppRadius.cardAll),
          SizedBox(height: AppSpacing.md),
          Skeleton(height: 84, borderRadius: AppRadius.cardAll),
        ],
      ),
    );
  }
}

