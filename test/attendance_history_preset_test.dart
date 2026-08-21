import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/attendance_status_filter.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/attendance/domain/attendance_history_preset.dart';
import 'package:opshub/features/attendance/domain/attendance_history_query.dart';

void main() {
  const lateThisWeek = AttendanceHistoryPreset(
    label: 'Late this week',
    range: AttendanceDateRange.last7Days,
    statuses: {AttendanceStatusFilter.late},
  );

  group('apply', () {
    test('sets the range + status set and clears the shift facet', () {
      const start = AttendanceHistoryQuery(
        range: AttendanceDateRange.thisMonth,
        shifts: {ScheduleShift.night},
      );
      final out = lateThisWeek.apply(start);
      expect(out.range, AttendanceDateRange.last7Days);
      expect(out.activeStatuses, {AttendanceStatusFilter.late});
      expect(out.shifts, isEmpty);
    });

    test('keeps the reviewer name search (preset composes with a search)', () {
      const start = AttendanceHistoryQuery(text: 'Mohamed');
      expect(lateThisWeek.apply(start).text, 'Mohamed');
    });
  });

  group('isActive', () {
    test('true only when range, statuses and (empty) shifts all match', () {
      final applied = lateThisWeek.apply(const AttendanceHistoryQuery());
      expect(lateThisWeek.isActive(applied), isTrue);
    });

    test('a manual chip change deactivates the preset', () {
      final applied = lateThisWeek.apply(const AttendanceHistoryQuery());
      // Add a second status → no longer exactly "Late this week".
      final widened = applied.copyWith(
        statuses: {AttendanceStatusFilter.late, AttendanceStatusFilter.absent},
      );
      expect(lateThisWeek.isActive(widened), isFalse);
      // Add a shift facet → also inactive.
      expect(
        lateThisWeek.isActive(applied.copyWith(shifts: {ScheduleShift.morning})),
        isFalse,
      );
      // A different range → inactive.
      expect(
        lateThisWeek.isActive(
          applied.copyWith(range: AttendanceDateRange.thisMonth),
        ),
        isFalse,
      );
    });

    test('the "all" sentinel does not count as a status facet', () {
      // A query holding only `all` is "any status", so a preset that also has no
      // real status would match — but our presets always carry a real status, so
      // an all-only query is never active for them.
      const allOnly = AttendanceHistoryQuery(
        range: AttendanceDateRange.last7Days,
        statuses: {AttendanceStatusFilter.all},
      );
      expect(lateThisWeek.isActive(allOnly), isFalse);
    });
  });

  test('the curated set is short, labelled and non-empty', () {
    expect(kAttendanceHistoryPresets, isNotEmpty);
    expect(kAttendanceHistoryPresets.length, lessThanOrEqualTo(6));
    for (final p in kAttendanceHistoryPresets) {
      expect(p.label.trim(), isNotEmpty);
      expect(p.statuses, isNotEmpty);
    }
  });
}
