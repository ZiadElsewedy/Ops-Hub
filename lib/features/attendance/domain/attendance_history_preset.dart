import 'package:drop/core/enums/attendance_status_filter.dart';
import 'package:drop/features/attendance/domain/attendance_history_query.dart';

/// A curated one-tap **quick view** over the attendance ledger — the answer to a
/// question a manager (or an employee, on their own history) asks often, as a
/// single chip instead of setting a date range and status facets by hand.
///
/// Deliberately curated, not user-saved: DROP favours *signal over volume*
/// ([ADR-010](../../../docs/decisions/ADR-010-lean-over-enterprise.md)), so this
/// is a short, fixed set of the views that actually get used, not a filter-builder
/// with persistence. A preset only ever sets a **date range** and a **status set**
/// (and clears the shift facet) — it never touches the reviewer's name search, so
/// "Mohamed's late days this week" is a name search *plus* the Late-this-week
/// preset. Pure — no Flutter, no Firestore.
class AttendanceHistoryPreset {
  const AttendanceHistoryPreset({
    required this.label,
    required this.range,
    required this.statuses,
  });

  final String label;
  final AttendanceDateRange range;
  final Set<AttendanceStatusFilter> statuses;

  /// Fold this preset onto [query]: set the range + status set, clear the shift
  /// facet, and keep everything else (notably the name search). Presets never use
  /// a custom range, so any stale custom bounds are left untouched — they are
  /// ignored unless the range is `custom`.
  AttendanceHistoryQuery apply(AttendanceHistoryQuery query) => query.copyWith(
    range: range,
    statuses: statuses,
    shifts: const {},
  );

  /// Whether [query] currently shows exactly this preset — its range, its status
  /// set, and no shift facet. Any manual chip change makes the preset read as
  /// inactive, so the highlighted chip never lies.
  bool isActive(AttendanceHistoryQuery query) =>
      query.range == range &&
      query.shifts.isEmpty &&
      _sameStatuses(query.activeStatuses, statuses);

  static bool _sameStatuses(
    Set<AttendanceStatusFilter> a,
    Set<AttendanceStatusFilter> b,
  ) => a.length == b.length && a.containsAll(b);
}

/// The fixed set of quick views, most-used first. Kept short on purpose.
const List<AttendanceHistoryPreset> kAttendanceHistoryPresets = [
  AttendanceHistoryPreset(
    label: 'Problems this week',
    range: AttendanceDateRange.last7Days,
    statuses: {
      AttendanceStatusFilter.late,
      AttendanceStatusFilter.absent,
      AttendanceStatusFilter.earlyLeave,
    },
  ),
  AttendanceHistoryPreset(
    label: 'Late this week',
    range: AttendanceDateRange.last7Days,
    statuses: {AttendanceStatusFilter.late},
  ),
  AttendanceHistoryPreset(
    label: 'Absent this week',
    range: AttendanceDateRange.last7Days,
    statuses: {AttendanceStatusFilter.absent},
  ),
  AttendanceHistoryPreset(
    label: 'Overtime this month',
    range: AttendanceDateRange.thisMonth,
    statuses: {AttendanceStatusFilter.overtime},
  ),
];
