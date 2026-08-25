import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/features/attendance/domain/reporting/attendance_period.dart';

void main() {
  group('AttendancePeriodWindow', () {
    test('weekly window starts Sunday and spans 7 days', () {
      final window = weeklyWindow(DateTime(2026, 7, 30));

      expect(window.startDate, DateTime(2026, 7, 26));
      expect(window.endDate, DateTime(2026, 8, 1, 23, 59, 59, 999));
      expect(window.dayCount, 7);
      expect(window.contains(DateTime(2026, 7, 26, 12)), isTrue);
      expect(window.contains(DateTime(2026, 8, 2)), isFalse);
    });

    test('monthly window covers a 31-day month', () {
      final window = monthlyWindow(2026, 7);

      expect(window.startDate, DateTime(2026, 7));
      expect(window.endDate, DateTime(2026, 7, 31, 23, 59, 59, 999));
      expect(window.dayCount, 31);
    });

    test('monthly window covers February', () {
      final window = monthlyWindow(2026, 2);

      expect(window.startDate, DateTime(2026, 2));
      expect(window.endDate, DateTime(2026, 2, 28, 23, 59, 59, 999));
      expect(window.dayCount, 28);
    });

    test('period ids are deterministic and versioned', () {
      final window = weeklyWindow(DateTime(2026, 7, 30));
      final id1 = attendancePeriodId(
        type: AttendancePeriodType.weekly,
        scopeKey: 'branch-a',
        window: window,
      );
      final id2 = attendancePeriodId(
        type: AttendancePeriodType.weekly,
        scopeKey: 'branch-a',
        window: window,
      );
      final id3 = attendancePeriodId(
        type: AttendancePeriodType.weekly,
        scopeKey: 'branch-a',
        window: window,
        version: 2,
      );

      expect(id1, 'branch-a_weekly_20260726_20260801_v1');
      expect(id2, id1);
      expect(id3, isNot(id1));
    });
  });
}
