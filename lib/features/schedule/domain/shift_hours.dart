import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';

/// The concrete clock hours of one shift slot, as **minutes past the slot day's
/// midnight**. [endMinutes] may exceed 1440 for an **overnight** shift — a night
/// that ends 00:30 the next day is `1470`, one that ends 01:00 is `1500`. This
/// is the single source of truth for *"does this shift cross midnight, and until
/// when"*, replacing the old hardcoded `weekend → 00:30` rule.
///
/// Values are configurable per (day, shift): the standing baseline is
/// [ShiftHours.standard], and a week can override any slot
/// (`WeeklyScheduleEntity.shiftHours`) so business changes — weekend lateness,
/// Ramadan, holidays, special events — are data, not code.
class ShiftHours {
  final int startMinutes;
  final int endMinutes;

  const ShiftHours(this.startMinutes, this.endMinutes)
      : assert(endMinutes > startMinutes,
            'a shift must end after it starts (end may exceed 1440 overnight)');

  /// Build from wall-clock hours/minutes; pass [endNextDay] for an overnight
  /// end (e.g. `ShiftHours.hm(16, 30, 1, 0, endNextDay: true)` = 16:30 → 01:00).
  factory ShiftHours.hm(int startH, int startM, int endH, int endM,
          {bool endNextDay = false}) =>
      ShiftHours(startH * 60 + startM,
          (endNextDay ? 1440 : 0) + endH * 60 + endM);

  /// True when the shift runs past midnight (end at/after 24:00).
  bool get crossesMidnight => endMinutes >= 1440;

  int get durationMinutes => endMinutes - startMinutes;

  String get startLabel => _hhmm(startMinutes);

  /// The end wall-clock label — wraps past midnight (`1500 → "01:00"`).
  String get endLabel => _hhmm(endMinutes % 1440);

  /// `"16:30 – 01:00"` (pass `separator: '→'` for the employee arrow form).
  String format({String separator = '–'}) => '$startLabel $separator $endLabel';

  /// The standing baseline for a (day, shift) when a week sets no override —
  /// the current business hours. **Editable per day** via the schedule's day
  /// sheet; this is only the fallback, never a hard rule. This is the single
  /// source of truth for the default schedule configuration: attendance derives
  /// every scheduled instant from here (through `WeeklyScheduleEntity.hoursFor`
  /// + `ShiftWindow`), so changing a value here changes attendance too.
  ///
  /// Morning 08:30–16:30 every day; weekday night 15:00–23:00; the operational
  /// weekend (Thu/Fri/Sat, [ScheduleDay.isWeekend]) night 16:00–00:00 (ends at
  /// midnight — [endMinutes] `1440`). A manager can, e.g., set Saturday's close
  /// to 01:00 without a code change.
  static ShiftHours standard(ScheduleDay day, ScheduleShift shift) {
    if (shift == ScheduleShift.morning) return const ShiftHours(510, 990);
    return day.isWeekend
        ? const ShiftHours(960, 1440) // 16:00 → 00:00 (midnight, next day)
        : const ShiftHours(900, 1380); // 15:00 → 23:00
  }

  ShiftHours copyWith({int? startMinutes, int? endMinutes}) =>
      ShiftHours(startMinutes ?? this.startMinutes, endMinutes ?? this.endMinutes);

  /// Persisted form `{start, end}` (minutes past midnight; end may exceed 1440).
  Map<String, int> toMap() => {'start': startMinutes, 'end': endMinutes};

  /// Parses `{start, end}`; returns null on any malformed/out-of-range value so
  /// a bad entry can never invent nonsensical hours (falls back to standard).
  static ShiftHours? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final s = (raw['start'] as num?)?.toInt();
    final e = (raw['end'] as num?)?.toInt();
    if (s == null || e == null) return null;
    if (s < 0 || s >= 1440 || e <= s || e > 1440 + 720) return null;
    return ShiftHours(s, e);
  }

  static String _hhmm(int minutesOfDay) {
    final h = (minutesOfDay ~/ 60) % 24;
    final m = minutesOfDay % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  @override
  bool operator ==(Object other) =>
      other is ShiftHours &&
      other.startMinutes == startMinutes &&
      other.endMinutes == endMinutes;

  @override
  int get hashCode => Object.hash(startMinutes, endMinutes);

  @override
  String toString() => 'ShiftHours($startLabel–$endLabel)';
}
