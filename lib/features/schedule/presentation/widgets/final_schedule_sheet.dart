import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/widgets/branch_avatar.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:drop/features/schedule/domain/reporting/final_schedule_grid.dart';
import 'package:drop/features/schedule/domain/schedule_week.dart';

/// The **printable final schedule** (Schedule V2 · Pillar 5) — a premium,
/// read-only, export-ready roster styled like a modern spreadsheet in DROP's
/// monochrome language.
///
/// Owner-directed layout (2026-08-05): **shifts down the side, days across the
/// top, people named inside each cell** — the shape a manager already keeps in a
/// spreadsheet. Three rows carry the week: **Morning · Night · Off**, each day a
/// column, each cell the list of names on that slot. Not an editor: no
/// drag/drop, inspector, health or analytics. Content comes from the single
/// pure [buildFinalScheduleGrid], so this sheet, the PDF and the Excel export
/// never disagree.
///
/// Designed at a fixed [width] (a landscape document) with a natural height that
/// grows with the busiest column, so it exports cleanly to PNG / print / PDF at
/// a consistent proportion regardless of screen.
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
  static const _shiftFlex = 15;
  static const _dayFlex = 12;

  @override
  Widget build(BuildContext context) {
    final gen = generatedAt ?? DateTime.now();
    final grid = buildFinalScheduleGrid(schedule, members);

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
          _table(grid),
          const SizedBox(height: 26),
          _legend(grid),
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
  Widget _table(FinalScheduleGrid grid) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: _hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _headerRow(grid),
          if (grid.isEmpty)
            _emptyRow()
          else ...[
            _shiftRow(
              grid,
              label: 'Morning',
              hours: grid.morningHours.format(),
              cellsOf: (d) => d.morning,
            ),
            _shiftRow(
              grid,
              label: 'Night',
              hours: _nightHoursLabel(grid),
              cellsOf: (d) => d.night,
              zebra: true,
            ),
            if (grid.hasOff)
              _shiftRow(
                grid,
                label: 'Off',
                hours: null,
                muted: true,
                cellsOf: (d) => [
                  for (final p in d.off)
                    p.tag.isEmpty ? p.name : '${p.name} (${p.tag})',
                ],
              ),
          ],
          if (grid.hasNotes) _notesRow(grid),
        ],
      ),
    );
  }

  Widget _headerRow(FinalScheduleGrid grid) {
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
              flex: _shiftFlex,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('SHIFT', style: _colHeadStyle),
              ),
            ),
            for (final d in grid.days)
              _cell(
                flex: _dayFlex,
                divided: true,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(d.day.shortLabel.toUpperCase(), style: _colHeadStyle),
                    const SizedBox(height: 2),
                    Text(
                      '${d.date.day}',
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

  /// One shift row: a label + hours on the left, then the people on that slot
  /// named inside each day cell. Height grows with the busiest column.
  Widget _shiftRow(
    FinalScheduleGrid grid, {
    required String label,
    required String? hours,
    required List<String> Function(FinalScheduleDay) cellsOf,
    bool zebra = false,
    bool muted = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: zebra ? _zebra : null,
        border: const Border(top: BorderSide(color: _hairline)),
      ),
      constraints: const BoxConstraints(minHeight: 64),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _cell(
              flex: _shiftFlex,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: AppTypography.label.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          if (hours != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              hours,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textTertiary,
                                height: 1.3,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            for (final d in grid.days)
              _cell(
                flex: _dayFlex,
                divided: true,
                child: _namesCell(cellsOf(d), muted: muted),
              ),
          ],
        ),
      ),
    );
  }

  /// The people in a single (shift, day) cell — one name per line, centred. An
  /// empty cell reads as a quiet dash so the grid stays legible.
  Widget _namesCell(List<String> names, {required bool muted}) {
    if (names.isEmpty) {
      return Center(
        child: Text(
          '—',
          style: AppTypography.body.copyWith(color: AppColors.textTertiary),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < names.length; i++) ...[
            if (i > 0) const SizedBox(height: 5),
            Text(
              names[i],
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: muted
                  ? AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 12.5,
                    )
                  : AppTypography.label.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      height: 1.2,
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _notesRow(FinalScheduleGrid grid) {
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
              flex: _shiftFlex,
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text('NOTES', style: _colHeadStyle),
                ),
              ),
            ),
            for (final d in grid.days)
              _cell(
                flex: _dayFlex,
                divided: true,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      d.notes.join(' · '),
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

  /// The Night hours label — weekday hours, plus the weekend range when the
  /// operational weekend runs later.
  String _nightHoursLabel(FinalScheduleGrid grid) => grid.weekendNightDiffers
      ? '${grid.nightHours.format()}\nWknd ${grid.weekendNightHours.format()}'
      : grid.nightHours.format();

  // ── Legend ─────────────────────────────────────────────────────
  Widget _legend(FinalScheduleGrid grid) {
    return Wrap(
      spacing: 22,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _LegendItem('Morning', grid.morningHours.format()),
        _LegendItem('Night', _nightHoursLabel(grid).replaceAll('\n', ' · ')),
        if (grid.hasOff) const _LegendItem('Off', 'Marked off / on leave'),
        const _LegendItem('(V)', 'On vacation'),
        const _LegendItem('(L)', 'On leave'),
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

/// A legend entry — a label chip next to its meaning.
class _LegendItem extends StatelessWidget {
  const _LegendItem(this.label, this.meaning);

  final String label;
  final String meaning;

  @override
  Widget build(BuildContext context) {
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
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.4,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Text(
          meaning,
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
