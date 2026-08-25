import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/attendance_status.dart';
import 'package:opshub/core/enums/attendance_status_filter.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/attendance/domain/attendance_history_query.dart';
import 'package:opshub/features/attendance/domain/entities/attendance_entity.dart';

AttendanceEntity _rec({
  required DateTime date,
  String? userName,
  ScheduleShift shift = ScheduleShift.morning,
  AttendanceStatus status = AttendanceStatus.completed,
  int late = 0,
  int overtime = 0,
  DateTime? deletedAt,
}) => AttendanceEntity(
  id: '${date.toIso8601String()}_${shift.name}',
  userId: 'u1',
  userName: userName,
  shift: shift,
  date: date,
  status: status,
  lateMinutes: late,
  overtimeMinutes: overtime,
  deletedAt: deletedAt,
);

void main() {
  // A fixed "now": Friday, 17 July 2026.
  final now = DateTime(2026, 7, 17, 10, 30);

  group('resolveRange', () {
    test(
      'last 7 days is a rolling inclusive window across a month boundary',
      () {
        const q = AttendanceHistoryQuery(range: AttendanceDateRange.last7Days);
        final window = q.resolveRange(DateTime(2026, 3, 3, 14));
        expect(window.start, DateTime(2026, 2, 25));
        expect(window.end, DateTime(2026, 3, 3, 23, 59, 59, 999));
      },
    );

    test(
      'last 30 days is a rolling inclusive window across a month boundary',
      () {
        const q = AttendanceHistoryQuery(range: AttendanceDateRange.last30Days);
        final window = q.resolveRange(DateTime(2026, 3, 3, 14));
        expect(window.start, DateTime(2026, 2, 2));
        expect(window.end, DateTime(2026, 3, 3, 23, 59, 59, 999));
      },
    );
    test('thisMonth spans the whole calendar month', () {
      const q = AttendanceHistoryQuery(range: AttendanceDateRange.thisMonth);
      final w = q.resolveRange(now);
      expect(w.start, DateTime(2026, 7, 1));
      expect(w.end, DateTime(2026, 7, 31, 23, 59, 59, 999));
    });

    test('lastMonth spans the previous calendar month', () {
      const q = AttendanceHistoryQuery(range: AttendanceDateRange.lastMonth);
      final w = q.resolveRange(now);
      expect(w.start, DateTime(2026, 6, 1));
      expect(w.end, DateTime(2026, 6, 30, 23, 59, 59, 999));
    });

    test('lastMonth wraps the year in January', () {
      const q = AttendanceHistoryQuery(range: AttendanceDateRange.lastMonth);
      final w = q.resolveRange(DateTime(2026, 1, 12));
      expect(w.start, DateTime(2025, 12, 1));
      expect(w.end, DateTime(2025, 12, 31, 23, 59, 59, 999));
    });

    test('thisWeek starts Monday and covers 7 days including now', () {
      const q = AttendanceHistoryQuery(range: AttendanceDateRange.thisWeek);
      final w = q.resolveRange(now);
      expect(w.start.weekday, DateTime.monday);
      expect(w.end.difference(w.start).inDays, 6);
      expect(w.start.isAfter(now), isFalse);
      expect(w.end.isAfter(now), isTrue);
    });

    test('custom uses the given bounds and tolerates reversed order', () {
      final q = AttendanceHistoryQuery(
        range: AttendanceDateRange.custom,
        customStart: DateTime(2026, 5, 20),
        customEnd: DateTime(2026, 5, 10),
      );
      final w = q.resolveRange(now);
      expect(w.start, DateTime(2026, 5, 10));
      expect(w.end, DateTime(2026, 5, 20, 23, 59, 59, 999));
    });
  });

  group('startKey / endKey', () {
    test('bound a branch range query as yyyyMMdd', () {
      const q = AttendanceHistoryQuery(range: AttendanceDateRange.thisMonth);
      expect(q.startKey(now), '20260701');
      expect(q.endKey(now), '20260731');
    });
  });

  group('apply', () {
    test('keeps only records inside the date window', () {
      const q = AttendanceHistoryQuery(range: AttendanceDateRange.thisMonth);
      final records = [
        _rec(date: DateTime(2026, 7, 5)),
        _rec(date: DateTime(2026, 6, 20)), // last month → out
        _rec(date: DateTime(2026, 7, 31)), // last day → in
      ];
      final out = q.apply(records, now: now);
      expect(out.length, 2);
      expect(out.every((r) => r.date.month == 7), isTrue);
    });

    test('drops soft-deleted records', () {
      const q = AttendanceHistoryQuery(range: AttendanceDateRange.thisMonth);
      final out = q.apply([
        _rec(date: DateTime(2026, 7, 5)),
        _rec(date: DateTime(2026, 7, 6), deletedAt: DateTime(2026, 7, 7)),
      ], now: now);
      expect(out.length, 1);
    });

    test('sorts newest day first', () {
      const q = AttendanceHistoryQuery(range: AttendanceDateRange.thisMonth);
      final out = q.apply([
        _rec(date: DateTime(2026, 7, 3)),
        _rec(date: DateTime(2026, 7, 15)),
        _rec(date: DateTime(2026, 7, 9)),
      ], now: now);
      expect(out.map((r) => r.date.day).toList(), [15, 9, 3]);
    });

    test('composes status + shift + name facets', () {
      final q =
          const AttendanceHistoryQuery(
            range: AttendanceDateRange.thisMonth,
          ).copyWith(
            statuses: {AttendanceStatusFilter.late},
            shifts: {ScheduleShift.night},
            text: 'ali',
          );
      final records = [
        // Matches all three facets.
        _rec(
          date: DateTime(2026, 7, 4),
          userName: 'Alice',
          shift: ScheduleShift.night,
          late: 10,
        ),
        // Wrong shift.
        _rec(
          date: DateTime(2026, 7, 5),
          userName: 'Alice',
          shift: ScheduleShift.morning,
          late: 10,
        ),
        // Not late.
        _rec(
          date: DateTime(2026, 7, 6),
          userName: 'Alice',
          shift: ScheduleShift.night,
        ),
        // Wrong name.
        _rec(
          date: DateTime(2026, 7, 7),
          userName: 'Bob',
          shift: ScheduleShift.night,
          late: 10,
        ),
      ];
      final out = q.apply(records, now: now);
      expect(out.length, 1);
      expect(out.single.userName, 'Alice');
    });

    test('name match is case-insensitive and empty text matches all', () {
      final base = const AttendanceHistoryQuery(
        range: AttendanceDateRange.thisMonth,
      );
      final records = [
        _rec(date: DateTime(2026, 7, 4), userName: 'Alice'),
        _rec(date: DateTime(2026, 7, 5), userName: 'bob'),
      ];
      expect(base.apply(records, now: now).length, 2);
      expect(base.copyWith(text: 'ALI').apply(records, now: now).length, 1);
    });
  });

  test('hasFacets reflects any narrowing beyond the date range', () {
    const base = AttendanceHistoryQuery();
    expect(base.hasFacets, isFalse);
    expect(
      base.copyWith(statuses: {AttendanceStatusFilter.late}).hasFacets,
      isTrue,
    );
    // The "all" sentinel is not a narrowing facet.
    expect(
      base.copyWith(statuses: {AttendanceStatusFilter.all}).hasFacets,
      isFalse,
    );
    expect(base.copyWith(shifts: {ScheduleShift.night}).hasFacets, isTrue);
    expect(base.copyWith(text: 'a').hasFacets, isTrue);
  });

  group('today / yesterday presets', () {
    test('today is the single current calendar day', () {
      const q = AttendanceHistoryQuery(range: AttendanceDateRange.today);
      final w = q.resolveRange(now);
      expect(w.start, DateTime(2026, 7, 17));
      expect(w.end, DateTime(2026, 7, 17, 23, 59, 59, 999));
    });

    test('yesterday is the previous calendar day, across a month boundary', () {
      const q = AttendanceHistoryQuery(range: AttendanceDateRange.yesterday);
      final w = q.resolveRange(DateTime(2026, 8, 1, 9));
      expect(w.start, DateTime(2026, 7, 31));
      expect(w.end, DateTime(2026, 7, 31, 23, 59, 59, 999));
    });
  });

  group('multi-select status (OR across the set)', () {
    test('shows records matching ANY selected status', () {
      final q = const AttendanceHistoryQuery(
        range: AttendanceDateRange.thisMonth,
      ).copyWith(
        statuses: {AttendanceStatusFilter.late, AttendanceStatusFilter.absent},
      );
      final records = [
        _rec(date: DateTime(2026, 7, 4), late: 10), // late
        _rec(date: DateTime(2026, 7, 5), status: AttendanceStatus.absent),
        _rec(date: DateTime(2026, 7, 6)), // on time, completed → out
      ];
      final out = q.apply(records, now: now);
      expect(out.length, 2);
    });

    test('an empty (or all-only) set matches every status', () {
      final base = const AttendanceHistoryQuery(
        range: AttendanceDateRange.thisMonth,
      );
      final records = [
        _rec(date: DateTime(2026, 7, 4), late: 10),
        _rec(date: DateTime(2026, 7, 5), status: AttendanceStatus.absent),
      ];
      expect(base.apply(records, now: now).length, 2);
      expect(
        base
            .copyWith(statuses: {AttendanceStatusFilter.all})
            .apply(records, now: now)
            .length,
        2,
      );
    });
  });

  group('Arabic- and diacritic-insensitive name search', () {
    test('tashkeel and hamza forms match the bare name', () {
      final records = [
        _rec(date: DateTime(2026, 7, 4), userName: 'مُحَمَّد'), // with harakat
        _rec(date: DateTime(2026, 7, 5), userName: 'أحمد'), // hamza on alef
      ];
      final base = const AttendanceHistoryQuery(
        range: AttendanceDateRange.thisMonth,
      );
      // Typed without diacritics / hamza.
      expect(base.copyWith(text: 'محمد').apply(records, now: now).length, 1);
      expect(base.copyWith(text: 'احمد').apply(records, now: now).length, 1);
    });

    test('Latin accents fold to their base letter', () {
      final records = [_rec(date: DateTime(2026, 7, 4), userName: 'José')];
      final base = const AttendanceHistoryQuery(
        range: AttendanceDateRange.thisMonth,
      );
      expect(base.copyWith(text: 'jose').apply(records, now: now).length, 1);
    });
  });

  group('attendanceSearchNormalize', () {
    test('folds case, tashkeel, alef-maksura and ta-marbuta', () {
      expect(attendanceSearchNormalize('مُحَمَّد'), 'محمد');
      expect(attendanceSearchNormalize(' مركز '), 'مركز');
      expect(attendanceSearchNormalize('فاطمة'), 'فاطمه'); // ة → ه
      expect(attendanceSearchNormalize('JOSÉ'), 'jose');
      expect(attendanceSearchNormalize('a   b'), 'a b'); // whitespace collapse
    });
  });
}
