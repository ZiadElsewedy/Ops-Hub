/// The single source of truth for turning a [DateTime] into a user-visible
/// string in DROP. Every screen formats human dates through this class, so the
/// app speaks one date language and a formatting change is a one-file edit
/// (it replaces the ~20 copy-pasted month arrays + AM/PM math that used to live
/// in feature widgets).
///
/// Pure Dart — no Flutter, no `intl`. DROP's dates are English, monochrome and
/// deliberately lightweight; each method documents the **exact** string it
/// produces, and only the styles the app actually shows are exposed here.
///
/// Out of scope (intentionally not routed through here — see
/// `docs/design/PERFORMANCE.md`): 24-hour shift-window times
/// (`ShiftHours.format`), machine `yyyy-MM-dd` keys/filenames/persisted values,
/// and elapsed-[Duration] labels (video length, "Waiting 3d", "Synced 3m ago").
class AppDateFormatter {
  const AppDateFormatter._();

  static const _monthsShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const _weekdaysLong = [
    'Monday', 'Tuesday', 'Wednesday', //
    'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];

  static String _mon(int month) => _monthsShort[month - 1];

  /// Wall-clock time, 12-hour with an AM/PM suffix — e.g. `4:32 PM`, `12:05 AM`.
  static String time(DateTime dt) {
    final h12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$h12:$min $period';
  }

  /// Wall-clock time, **24-hour zero-padded** — e.g. `08:30`, `16:30`, `00:05`.
  /// Use this wherever the value sits next to a shift window, which
  /// `ShiftHours.format` renders in the same 24-hour form (`08:30 – 16:30`); a
  /// 12-hour reading beside it looks like a different clock.
  static String time24(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  /// Day + abbreviated month — e.g. `6 Jul`.
  static String dayMonth(DateTime dt) => '${dt.day} ${_mon(dt.month)}';

  /// Day + abbreviated month + year — e.g. `6 Jul 2026`.
  static String dayMonthYear(DateTime dt) =>
      '${dt.day} ${_mon(dt.month)} ${dt.year}';

  /// Abbreviated month + year — e.g. `Jul 2026`. Used where a whole calendar
  /// month is the subject (the monthly attendance report period).
  static String monthYear(DateTime dt) => '${_mon(dt.month)} ${dt.year}';

  /// Abbreviated month + day + year — e.g. `Jul 6, 2026`.
  static String monthDayYear(DateTime dt) =>
      '${_mon(dt.month)} ${dt.day}, ${dt.year}';

  /// Full date + wall-clock time — e.g. `20 Jun 2026 • 4:32 PM`.
  static String dayMonthYearTime(DateTime dt) =>
      '${dayMonthYear(dt)} • ${time(dt)}';

  /// Long weekday + day + abbreviated month — e.g. `Monday, 6 Jul`.
  static String weekdayDayMonth(DateTime dt) =>
      '${_weekdaysLong[dt.weekday - 1]}, ${dayMonth(dt)}';

  /// A local execution time with a manager-friendly relative day prefix:
  /// `Today • 8:30 AM`, `Tomorrow • 4:30 PM`, then an absolute weekday/date.
  /// [now] is injectable so automation summaries and their tests stay
  /// deterministic while every caller shares the same wording.
  static String relativeDayTime(DateTime dt, {DateTime? now}) {
    final value = dt.toLocal();
    final current = (now ?? DateTime.now()).toLocal();
    final today = DateTime(current.year, current.month, current.day);
    final day = DateTime(value.year, value.month, value.day);
    final dateLabel = day == today
        ? 'Today'
        : day == today.add(const Duration(days: 1))
        ? 'Tomorrow'
        : value.year == current.year
        ? weekdayDayMonth(value)
        : dayMonthYear(value);
    return '$dateLabel • ${time(value)}';
  }

  /// Numeric day/month/year with no zero-padding — e.g. `8/7/2026`.
  static String numeric(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';

  /// Compact age relative to [now] (defaults to `DateTime.now()`), falling back
  /// to an absolute [dayMonth] once a week old:
  /// `Just now` → `5m ago` → `3h ago` → `2d ago` → `6 Jul`.
  static String relative(DateTime dt, {DateTime? now}) {
    final diff = (now ?? DateTime.now()).difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return dayMonth(dt);
  }

  /// The same age as [relative], stripped for a **right-aligned meta slot**
  /// (a notification row's time corner): `now` → `5m` → `3h` → `2d` → `6 Jul`.
  /// The "ago" is implied by the column, so it is dropped — the shorter string
  /// keeps the title from being squeezed on a narrow phone.
  static String relativeShort(DateTime dt, {DateTime? now}) {
    final diff = (now ?? DateTime.now()).difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return dayMonth(dt);
  }
}
