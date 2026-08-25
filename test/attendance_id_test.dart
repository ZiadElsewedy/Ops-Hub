import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/attendance/domain/attendance_id.dart';

void main() {
  group('attendanceDayKey', () {
    test('formats as yyyyMMdd with zero padding', () {
      expect(attendanceDayKey(DateTime(2026, 7, 11)), '20260711');
      expect(attendanceDayKey(DateTime(2026, 12, 5)), '20261205');
      expect(attendanceDayKey(DateTime(2026, 1, 1)), '20260101');
    });

    test('ignores the time component', () {
      expect(attendanceDayKey(DateTime(2026, 7, 11, 23, 59)), '20260711');
    });
  });

  group('attendanceDocId', () {
    test('is deterministic: {uid}_{yyyyMMdd}_{shift}', () {
      expect(
        attendanceDocId(
            uid: 'u1', date: DateTime(2026, 7, 11), shift: ScheduleShift.morning),
        'u1_20260711_morning',
      );
      expect(
        attendanceDocId(
            uid: 'u1', date: DateTime(2026, 7, 11), shift: ScheduleShift.night),
        'u1_20260711_night',
      );
    });

    test('same (uid, day, shift) always yields the same id (idempotent key)', () {
      final a = attendanceDocId(
          uid: 'abc', date: DateTime(2026, 7, 11, 8), shift: ScheduleShift.morning);
      final b = attendanceDocId(
          uid: 'abc', date: DateTime(2026, 7, 11, 20), shift: ScheduleShift.morning);
      expect(a, b);
    });

    test('morning and night on the same day never collide', () {
      final m = attendanceDocId(
          uid: 'u', date: DateTime(2026, 7, 11), shift: ScheduleShift.morning);
      final n = attendanceDocId(
          uid: 'u', date: DateTime(2026, 7, 11), shift: ScheduleShift.night);
      expect(m == n, isFalse);
    });
  });
}
