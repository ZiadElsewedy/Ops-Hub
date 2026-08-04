import 'package:flutter/material.dart';
import 'package:drop/core/enums/leave_type.dart';
import 'package:drop/core/enums/schedule_day.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/widgets/branch_avatar.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:drop/features/schedule/domain/schedule_week.dart';
import 'package:drop/features/schedule/presentation/widgets/schedule_helpers.dart';

/// The **printable final schedule** (Schedule V2 · Pillar 4) — a premium,
/// read-only, export-ready roster styled like a modern spreadsheet (Apple
/// Numbers / Notion tables) in DROP's monochrome language.
///
/// This is **not** an editor: no drag/drop, no inspector, no health, no
/// analytics, no builder controls. One employee per row, one day per column, a
/// single scannable token per cell (`M` · `N` · `OFF` · `LEAVE` · `VAC`).
/// Typography and whitespace carry the hierarchy — employee names lead, shift
/// tokens are the scan target. Presentation only: it reads the existing schedule
/// models and derives nothing new.
///
/// Designed at a fixed [width] (a landscape document) with a natural height that
/// grows with the roster, so it exports cleanly to PNG / print / PDF at a
/// consistent proportion regardless of screen.
class FinalScheduleSheet extends StatelessWidget {
  const FinalScheduleSheet({
    super.key,
    required this.schedule,
    required this.members,
    required this.branch,
    this.managerName,
    this.generatedAt,
    this.width = 1600,
  });

  final WeeklyScheduleEntity schedule;
  final List<UserEntity> members;
  final BranchEntity? branch;

  /// The branch manager's name for the document header (null → omitted).
  final String? managerName;

  /// When the sheet was produced (null → now).
  final DateTime? generatedAt;

  /// The fixed logical width of the landscape document.
  final double width;

  static const _paper = Color(0xFF0B0B0D);
  static const _hairline = Color(0x14FFFFFF);
  static const _zebra = Color(0x05FFFFFF);
  static const _employeeFlex = 26;
  static const _dayFlex = 11;

  @override
  Widget build(BuildContext context) {
    final gen = generatedAt ?? DateTime.now();
    // Only the people actually on the schedule this week — the published sheet
    // is a "who's working" roster, not the whole branch directory.
    final roster = scheduledRoster(schedule, members);
    final hasNotes =
        ScheduleDay.values.any((d) => schedule.noteFor(d) != null);

    return Container(
      width: width,
      color: _paper,
      padding: const EdgeInsets.fromLTRB(56, 48, 56, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(gen),
          const SizedBox(height: 26),
          _table(roster, hasNotes),
          const SizedBox(height: 26),
          _legend(),
          const SizedBox(height: 22),
          _footer(gen),
        ],
      ),
    );
  }

  // ── Document header ────────────────────────────────────────────
  Widget _header(DateTime gen) {
    final branchName = branch?.name ?? 'Branch';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BranchAvatar(
          logoUrl: branch?.logoUrl,
          name: branchName,
          size: 54,
          radius: 15,
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'DROP',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                branchName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.h1.copyWith(letterSpacing: -0.4),
              ),
              const SizedBox(height: 2),
              Text(
                'Weekly staff schedule',
                style: AppTypography.body.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        _metaBlock(gen),
      ],
    );
  }

  Widget _metaBlock(DateTime gen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        _metaRow('WEEK OF', ScheduleWeek.rangeLabel(schedule.weekStart),
            emphasise: true),
        const SizedBox(height: 10),
        _metaRow('GENERATED', AppDateFormatter.dayMonthYear(gen)),
        if (managerName != null && managerName!.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          _metaRow('MANAGER', managerName!.trim()),
        ],
      ],
    );
  }

  Widget _metaRow(String label, String value, {bool emphasise = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: emphasise
              ? AppTypography.h3.copyWith(letterSpacing: -0.2)
              : AppTypography.label.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  // ── The table ──────────────────────────────────────────────────
  Widget _table(List<UserEntity> roster, bool hasNotes) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: _hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _headerRow(),
          if (roster.isEmpty)
            _emptyRow()
          else
            for (var i = 0; i < roster.length; i++)
              _employeeRow(roster[i], zebra: i.isOdd),
          if (hasNotes) _notesRow(),
        ],
      ),
    );
  }

  Widget _headerRow() {
    return Container(
      decoration: const BoxDecoration(
        color: _zebra,
        border: Border(bottom: BorderSide(color: _hairline)),
      ),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            _cell(
              flex: _employeeFlex,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('EMPLOYEE', style: _colHeadStyle),
              ),
            ),
            for (final day in ScheduleDay.values)
              _cell(
                flex: _dayFlex,
                divided: true,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(day.shortLabel.toUpperCase(), style: _colHeadStyle),
                    const SizedBox(height: 2),
                    Text(
                      '${schedule.weekStart.add(Duration(days: day.index)).day}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _employeeRow(UserEntity member, {required bool zebra}) {
    final position = member.position?.trim();
    return Container(
      decoration: BoxDecoration(
        color: zebra ? _zebra : null,
        border: const Border(top: BorderSide(color: _hairline)),
      ),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            _cell(
              flex: _employeeFlex,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      userDisplayName(member),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    if (position != null && position.isNotEmpty)
                      Text(
                        position,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textTertiary),
                      ),
                  ],
                ),
              ),
            ),
            for (final day in ScheduleDay.values)
              _cell(
                flex: _dayFlex,
                divided: true,
                child: _token(_cellFor(member.uid, day)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _notesRow() {
    return Container(
      decoration: const BoxDecoration(
        color: _zebra,
        border: Border(top: BorderSide(color: _hairline)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _cell(
              flex: _employeeFlex,
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text('NOTES', style: _colHeadStyle),
                ),
              ),
            ),
            for (final day in ScheduleDay.values)
              _cell(
                flex: _dayFlex,
                divided: true,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      (schedule.noteLinesFor(day)).join(' · '),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _emptyRow() {
    return SizedBox(
      height: 72,
      child: Center(
        child: Text(
          'No one is scheduled this week.',
          style: AppTypography.body.copyWith(color: AppColors.textTertiary),
        ),
      ),
    );
  }

  Widget _cell({
    required int flex,
    required Widget child,
    bool divided = false,
  }) {
    return Expanded(
      flex: flex,
      child: DecoratedBox(
        decoration: divided
            ? const BoxDecoration(
                border: Border(left: BorderSide(color: _hairline)))
            : const BoxDecoration(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: child,
        ),
      ),
    );
  }

  // ── Cell token ─────────────────────────────────────────────────
  _Token _cellFor(String uid, ScheduleDay day) {
    final shifts = schedule.shiftsFor(uid, day);
    if (shifts.isNotEmpty) {
      if (shifts.length >= 2) return const _Token(_TokenKind.shift, 'M/N');
      return _Token(_TokenKind.shift,
          shifts.first == ScheduleShift.morning ? 'M' : 'N');
    }
    final leave = schedule.leaveTypeOf(uid, day);
    return switch (leave) {
      LeaveType.annual => const _Token(_TokenKind.vacation, 'VAC'),
      LeaveType.sick || LeaveType.pending => const _Token(_TokenKind.leave, 'LEAVE'),
      _ => const _Token(_TokenKind.off, 'OFF'),
    };
  }

  Widget _token(_Token token) {
    final (color, weight, size, spacing) = switch (token.kind) {
      _TokenKind.shift => (AppColors.textPrimary, FontWeight.w700, 15.0, 0.0),
      _TokenKind.vacation => (AppColors.textSecondary, FontWeight.w700, 11.0, 0.6),
      _TokenKind.leave => (AppColors.textSecondary, FontWeight.w700, 11.0, 0.6),
      _TokenKind.off => (AppColors.textTertiary, FontWeight.w500, 11.0, 0.4),
    };
    return Center(
      child: Text(
        token.label,
        style: TextStyle(
          fontFamily: AppTypography.fontFamily,
          color: color,
          fontWeight: weight,
          fontSize: size,
          letterSpacing: spacing,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  // ── Legend ─────────────────────────────────────────────────────
  Widget _legend() {
    return Wrap(
      spacing: 22,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: const [
        _LegendItem(_Token(_TokenKind.shift, 'M'), 'Morning'),
        _LegendItem(_Token(_TokenKind.shift, 'N'), 'Night'),
        _LegendItem(_Token(_TokenKind.off, 'OFF'), 'Off'),
        _LegendItem(_Token(_TokenKind.leave, 'LEAVE'), 'Leave'),
        _LegendItem(_Token(_TokenKind.vacation, 'VAC'), 'Vacation'),
      ],
    );
  }

  // ── Footer ─────────────────────────────────────────────────────
  Widget _footer(DateTime gen) {
    return Row(
      children: [
        Text(
          'DROP  ·  OPERATIONS',
          style: AppTypography.caption.copyWith(
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const Spacer(),
        Text(
          'Read-only schedule · generated ${AppDateFormatter.dayMonthYear(gen)}',
          style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
        ),
      ],
    );
  }

  static final TextStyle _colHeadStyle = AppTypography.caption.copyWith(
    color: AppColors.textTertiary,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
  );
}

enum _TokenKind { shift, vacation, leave, off }

class _Token {
  const _Token(this.kind, this.label);
  final _TokenKind kind;
  final String label;
}

/// A legend swatch — the token as it appears in a cell, next to its meaning.
class _LegendItem extends StatelessWidget {
  const _LegendItem(this.token, this.label);

  final _Token token;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isShift = token.kind == _TokenKind.shift;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(minWidth: 34),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0x08FFFFFF),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0x14FFFFFF)),
          ),
          child: Text(
            token.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              color: isShift ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: isShift ? 13 : 10,
              letterSpacing: 0.4,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Text(
          label,
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
