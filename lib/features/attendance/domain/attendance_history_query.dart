import 'package:drop/core/enums/attendance_status.dart';
import 'package:drop/core/enums/attendance_status_filter.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/features/attendance/domain/attendance_id.dart';
import 'package:drop/features/attendance/domain/entities/attendance_entity.dart';

/// The date window a history view is scoped to. `custom` carries an explicit
/// start/end; the presets are resolved against `now` in [AttendanceHistoryQuery].
enum AttendanceDateRange {
  today,
  yesterday,
  last7Days,
  last30Days,
  thisWeek,
  thisMonth,
  lastMonth,
  custom;

  String get label => switch (this) {
    AttendanceDateRange.today => 'Today',
    AttendanceDateRange.yesterday => 'Yesterday',
    AttendanceDateRange.last7Days => 'Last 7 days',
    AttendanceDateRange.last30Days => 'Last 30 days',
    AttendanceDateRange.thisWeek => 'This week',
    AttendanceDateRange.thisMonth => 'This month',
    AttendanceDateRange.lastMonth => 'Last month',
    AttendanceDateRange.custom => 'Custom',
  };
}

/// An inclusive day window `[start, end]` (local calendar days). `start` is that
/// day's midnight; `end` is the last instant of its day.
typedef DateWindow = ({DateTime start, DateTime end});

/// A **pure, composable** description of what the Attendance History ledger
/// should show — a date window plus status / shift / name facets. No Flutter, no
/// Firestore, so it is unit-tested directly and reused unchanged by both the
/// employee self-history and the manager/admin branch-review surfaces.
///
/// The screen owns *where the records come from* (the employee's own history vs.
/// a branch range); this owns *which of them survive* and *how to bound a server
/// range query* ([startKey] / [endKey]). Facets are additive — an empty
/// [shifts] means "any shift", [AttendanceStatusFilter.all] means "any status",
/// an empty [text] means "any name".
class AttendanceHistoryQuery {
  final AttendanceDateRange range;

  /// Explicit bounds for [AttendanceDateRange.custom] (ignored otherwise). When
  /// custom is selected but a bound is missing, the resolver falls back to the
  /// current month so the UI never queries an unbounded window.
  final DateTime? customStart;
  final DateTime? customEnd;

  /// Selected status facets, combined with **OR**: a record survives if it
  /// matches *any* selected filter (so "Late" + "Absent" shows both). Empty — or
  /// a set containing [AttendanceStatusFilter.all] — means "any status".
  final Set<AttendanceStatusFilter> statuses;

  /// Empty = every shift. Otherwise the record's [ScheduleShift] must be in the set.
  final Set<ScheduleShift> shifts;

  /// Case-insensitive substring match against the record's denormalized
  /// `userName` (the reviewer's employee search). Empty = every employee.
  final String text;

  const AttendanceHistoryQuery({
    this.range = AttendanceDateRange.thisMonth,
    this.customStart,
    this.customEnd,
    this.statuses = const <AttendanceStatusFilter>{},
    this.shifts = const <ScheduleShift>{},
    this.text = '',
  });

  AttendanceHistoryQuery copyWith({
    AttendanceDateRange? range,
    DateTime? customStart,
    DateTime? customEnd,
    Set<AttendanceStatusFilter>? statuses,
    Set<ScheduleShift>? shifts,
    String? text,
  }) => AttendanceHistoryQuery(
    range: range ?? this.range,
    customStart: customStart ?? this.customStart,
    customEnd: customEnd ?? this.customEnd,
    statuses: statuses ?? this.statuses,
    shifts: shifts ?? this.shifts,
    text: text ?? this.text,
  );

  /// The **effective** status facets — an empty set or one holding
  /// [AttendanceStatusFilter.all] both mean "any status", collapsed to empty.
  Set<AttendanceStatusFilter> get activeStatuses =>
      statuses.where((s) => s != AttendanceStatusFilter.all).toSet();

  /// True when nothing narrows the ledger — used to pick an "all clear" vs. a
  /// "no matches" empty state.
  bool get hasFacets =>
      activeStatuses.isNotEmpty ||
      shifts.isNotEmpty ||
      text.trim().isNotEmpty;

  /// Whether [r] matches the selected status facets (OR across the set; empty =
  /// any). The single source both the record list and the gap list consult.
  bool matchesStatuses(AttendanceEntity r) {
    final active = activeStatuses;
    return active.isEmpty ||
        active.any((f) => matchesAttendanceStatusFilter(f, r));
  }

  /// Resolve the date [range] to an inclusive `[start, end]` day window against
  /// [now]. Weeks start Monday; month presets span the whole calendar month.
  DateWindow resolveRange(DateTime now) {
    switch (range) {
      case AttendanceDateRange.today:
        final day = _startOfDay(now);
        return (start: day, end: _endOfDay(day));
      case AttendanceDateRange.yesterday:
        final day = _startOfDay(now).subtract(const Duration(days: 1));
        return (start: day, end: _endOfDay(day));
      case AttendanceDateRange.last7Days:
        final end = _startOfDay(now);
        return (
          start: end.subtract(const Duration(days: 6)),
          end: _endOfDay(end),
        );
      case AttendanceDateRange.last30Days:
        final end = _startOfDay(now);
        return (
          start: end.subtract(const Duration(days: 29)),
          end: _endOfDay(end),
        );
      case AttendanceDateRange.thisWeek:
        final monday = _startOfDay(
          now,
        ).subtract(Duration(days: now.weekday - 1));
        return (
          start: monday,
          end: _endOfDay(monday.add(const Duration(days: 6))),
        );
      case AttendanceDateRange.thisMonth:
        return _monthWindow(now.year, now.month);
      case AttendanceDateRange.lastMonth:
        final m = now.month == 1 ? 12 : now.month - 1;
        final y = now.month == 1 ? now.year - 1 : now.year;
        return _monthWindow(y, m);
      case AttendanceDateRange.custom:
        final start = customStart ?? _monthWindow(now.year, now.month).start;
        final end = customEnd ?? now;
        // Tolerate reversed bounds so a half-picked custom range never inverts.
        final lo = start.isAfter(end) ? end : start;
        final hi = start.isAfter(end) ? start : end;
        return (start: _startOfDay(lo), end: _endOfDay(hi));
    }
  }

  /// The `yyyyMMdd` lower bound for a `watchBranchRange` server query.
  String startKey(DateTime now) => attendanceDayKey(resolveRange(now).start);

  /// The `yyyyMMdd` upper bound for a `watchBranchRange` server query.
  String endKey(DateTime now) => attendanceDayKey(resolveRange(now).end);

  /// Apply every facet to [records] and return the survivors, newest day first.
  /// Soft-deleted records are always dropped.
  List<AttendanceEntity> apply(
    List<AttendanceEntity> records, {
    required DateTime now,
  }) {
    final window = resolveRange(now);
    final needle = attendanceSearchNormalize(text);
    final out = <AttendanceEntity>[
      for (final r in records)
        if (!r.isDeleted &&
            !r.date.isBefore(window.start) &&
            !r.date.isAfter(window.end) &&
            (shifts.isEmpty || shifts.contains(r.shift)) &&
            matchesStatuses(r) &&
            (needle.isEmpty ||
                attendanceSearchNormalize(r.userName ?? '').contains(needle)))
          r,
    ];
    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }

  static DateWindow _monthWindow(int year, int month) {
    final start = DateTime(year, month, 1);
    // Day 0 of the next month is the last day of this one.
    final lastDay = DateTime(year, month + 1, 0);
    return (start: start, end: _endOfDay(lastDay));
  }

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
}

/// Whether [r] matches the [filter] — the single predicate behind the status
/// chips. Pure and entity-aware (hence in the domain, not on the core enum).
bool matchesAttendanceStatusFilter(
  AttendanceStatusFilter filter,
  AttendanceEntity r,
) {
  switch (filter) {
    case AttendanceStatusFilter.all:
      return true;
    case AttendanceStatusFilter.onTime:
      // Showed up (or is on shift) and wasn't late.
      return r.status.isPresent && !r.isLate;
    case AttendanceStatusFilter.late:
      return r.isLate;
    case AttendanceStatusFilter.absent:
      return r.status.isAbsence;
    case AttendanceStatusFilter.excused:
      return r.isExcused;
    case AttendanceStatusFilter.leave:
      return r.status == AttendanceStatus.onLeave;
    case AttendanceStatusFilter.earlyLeave:
      return r.hasEarlyLeave;
    case AttendanceStatusFilter.overtime:
      return r.hasOvertime;
  }
}

/// Fold a name (or a search term) to a form where an Arabic or English name
/// matches the way a person expects when they type it — the reviewer employee
/// search runs the *same* fold over both the needle and each record's
/// `userName`, so it is case-, diacritic- and hamza-insensitive.
///
/// Pure and dependency-free. Applied to both sides of a `contains`, so it is the
/// single definition of "these two names are the same for search".
///
///  * **Case + whitespace** — lower-cased, trimmed, internal runs of whitespace
///    collapsed to one space (a double space between names never hides a match).
///  * **Arabic diacritics** — the tashkeel harakat (`U+064B–U+0652`), the
///    superscript alef (`U+0670`) and the tatweel elongation (`U+0640`) are
///    dropped: `مُحَمَّد` matches `محمد`.
///  * **Arabic letter forms** — the alef variants (`أ إ آ ٱ`) fold to bare alef,
///    `ى` to `ي`, `ة` to `ه`, and the hamza-carriers `ؤ`/`ئ` to `و`/`ي`, so a
///    name typed without its hamza still matches.
///  * **Latin diacritics** — the common accented Latin letters fold to their base
///    (`José` matches `jose`).
String attendanceSearchNormalize(String input) {
  final lowered = input.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lowered.runes) {
    // Drop Arabic tashkeel (harakat), the superscript alef and the tatweel.
    if ((rune >= 0x064B && rune <= 0x0652) || rune == 0x0670 || rune == 0x0640) {
      continue;
    }
    final mapped = _searchFold[rune];
    buffer.writeCharCode(mapped ?? rune);
  }
  // Collapse internal whitespace and trim the ends.
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Codepoint → base-letter folds applied by [attendanceSearchNormalize].
const Map<int, int> _searchFold = {
  // ── Arabic letter forms ──
  0x0623: 0x0627, // أ  hamza-on-alef  → ا
  0x0625: 0x0627, // إ  hamza-under-alef → ا
  0x0622: 0x0627, // آ  alef-madda    → ا
  0x0671: 0x0627, // ٱ  alef-wasla    → ا
  0x0649: 0x064A, // ى  alef-maksura  → ي
  0x0629: 0x0647, // ة  ta-marbuta    → ه
  0x0624: 0x0648, // ؤ  hamza-on-waw  → و
  0x0626: 0x064A, // ئ  hamza-on-ya   → ي
  // ── Common Latin diacritics → base letter ──
  0x00E0: 0x61, 0x00E1: 0x61, 0x00E2: 0x61, 0x00E3: 0x61, 0x00E4: 0x61,
  0x00E5: 0x61, // à á â ã ä å → a
  0x00E7: 0x63, // ç → c
  0x00E8: 0x65, 0x00E9: 0x65, 0x00EA: 0x65, 0x00EB: 0x65, // è é ê ë → e
  0x00EC: 0x69, 0x00ED: 0x69, 0x00EE: 0x69, 0x00EF: 0x69, // ì í î ï → i
  0x00F1: 0x6E, // ñ → n
  0x00F2: 0x6F, 0x00F3: 0x6F, 0x00F4: 0x6F, 0x00F5: 0x6F, 0x00F6: 0x6F,
  0x00F8: 0x6F, // ò ó ô õ ö ø → o
  0x00F9: 0x75, 0x00FA: 0x75, 0x00FB: 0x75, 0x00FC: 0x75, // ù ú û ü → u
  0x00FD: 0x79, 0x00FF: 0x79, // ý ÿ → y
};
