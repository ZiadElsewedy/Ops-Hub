import 'package:flutter/material.dart';
import 'package:drop/core/enums/attendance_status_filter.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/widgets/app_search_field.dart';
import 'package:drop/features/attendance/domain/attendance_history_preset.dart';
import 'package:drop/features/attendance/domain/attendance_history_query.dart';

/// The **composable** filter bar for the Attendance History ledger: a curated
/// quick-view row, a date-range selector, a status facet, a shift facet, and
/// (reviewer only) an employee-name search. Purely presentational — every change
/// is reported up via a callback and the cubit owns the [AttendanceHistoryQuery].
/// Monochrome: a selected chip fills white, the rest stay quiet surfaces.
class AttendanceHistoryFilters extends StatelessWidget {
  const AttendanceHistoryFilters({
    super.key,
    required this.query,
    required this.onRange,
    required this.onStatus,
    required this.onToggleShift,
    this.onSearch,
    this.onPreset,
    this.showSearch = false,
  });

  final AttendanceHistoryQuery query;
  final void Function(
    AttendanceDateRange range, {
    DateTime? start,
    DateTime? end,
  })
  onRange;
  final ValueChanged<AttendanceStatusFilter> onStatus;
  final ValueChanged<ScheduleShift> onToggleShift;

  /// Reviewer employee-name search (review mode only).
  final ValueChanged<String>? onSearch;

  /// Apply a curated quick view. When null, the quick-view row is hidden.
  final ValueChanged<AttendanceHistoryPreset>? onPreset;
  final bool showSearch;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onPreset != null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              'Quick views',
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
          _ChipRow(
            children: [
              for (final preset in kAttendanceHistoryPresets)
                _Chip(
                  label: preset.label,
                  selected: preset.isActive(query),
                  onTap: () => onPreset!(preset),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (showSearch && onSearch != null) ...[
          _EmployeeSearch(initialText: query.text, onChanged: onSearch!),
          const SizedBox(height: AppSpacing.md),
        ],
        _ChipRow(
          children: [
            for (final r in const [
              AttendanceDateRange.today,
              AttendanceDateRange.yesterday,
              AttendanceDateRange.last7Days,
              AttendanceDateRange.last30Days,
              AttendanceDateRange.thisMonth,
              AttendanceDateRange.lastMonth,
              AttendanceDateRange.custom,
            ])
              _Chip(
                label: _rangeLabel(r),
                selected: query.range == r,
                onTap: () => r == AttendanceDateRange.custom
                    ? _pickCustom(context)
                    : onRange(r),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _ChipRow(
          children: [
            for (final s in AttendanceStatusFilter.values)
              _Chip(
                // Multi-select: "All" lights up only when nothing is chosen; any
                // specific facet lights up when it's in the OR set.
                label: s.label,
                selected: s == AttendanceStatusFilter.all
                    ? query.activeStatuses.isEmpty
                    : query.activeStatuses.contains(s),
                onTap: () => onStatus(s),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _ChipRow(
          children: [
            for (final s in ScheduleShift.values)
              _Chip(
                label: s.label,
                selected: query.shifts.contains(s),
                onTap: () => onToggleShift(s),
              ),
          ],
        ),
      ],
    );
  }

  String _rangeLabel(AttendanceDateRange r) {
    if (r == AttendanceDateRange.custom &&
        query.range == AttendanceDateRange.custom &&
        query.customStart != null &&
        query.customEnd != null) {
      return '${AppDateFormatter.dayMonth(query.customStart!)} – '
          '${AppDateFormatter.dayMonth(query.customEnd!)}';
    }
    return r.label;
  }

  Future<void> _pickCustom(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: (query.customStart != null && query.customEnd != null)
          ? DateTimeRange(start: query.customStart!, end: query.customEnd!)
          : null,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            onPrimary: AppColors.onPrimary,
            surface: AppColors.darkSurface,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      onRange(AttendanceDateRange.custom, start: picked.start, end: picked.end);
    }
  }
}

/// The employee-name search, seeded from the query it is filtering.
///
/// Arriving from a report row pre-filters the ledger to one person; without the
/// name *in the box* the list would look mysteriously short with an empty search
/// field and no obvious way back. Seeding a caller-owned controller also gives
/// the shared field's clear button something real to clear.
class _EmployeeSearch extends StatefulWidget {
  const _EmployeeSearch({required this.initialText, required this.onChanged});

  final String initialText;
  final ValueChanged<String> onChanged;

  @override
  State<_EmployeeSearch> createState() => _EmployeeSearchState();
}

class _EmployeeSearchState extends State<_EmployeeSearch> {
  // Seeded once: after the first frame the field is the source of truth for its
  // own text, so re-seeding on rebuild would fight the person typing.
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppSearchField(
    hint: 'Search employee',
    controller: _controller,
    onChanged: widget.onChanged,
  );
}

/// A horizontally-scrolling row of filter chips (so the 7 status facets never
/// overflow a phone).
class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? AppColors.primary : AppColors.darkSurfaceElevated,
        borderRadius: AppRadius.fullAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.fullAll,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              borderRadius: AppRadius.fullAll,
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.darkBorder,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.onPrimary : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
