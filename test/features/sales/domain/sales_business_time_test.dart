import 'package:opshub/features/sales/domain/sales_business_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses Cairo civil dates across a UTC month boundary', () {
    // Egypt observes DST from the last Friday of April to the last Friday of
    // October, so late July is UTC+3 — midnight in Cairo is 21:00 UTC.
    expect(businessMonthKey(DateTime.utc(2026, 7, 31, 20, 30)), '202607');
    expect(businessDateKey(DateTime.utc(2026, 7, 31, 20, 30)), '20260731');
    expect(businessMonthKey(DateTime.utc(2026, 7, 31, 21, 30)), '202608');
    expect(businessDateKey(DateTime.utc(2026, 7, 31, 21, 30)), '20260801');
  });

  test('calculates elapsed and remaining calendar days from Cairo', () {
    final now = DateTime.utc(2026, 8, 15, 9);
    expect(calendarDaysInMonth(now), 31);
    expect(calendarDaysElapsed(now), 15);
    // Days AFTER today. The dashboard shows selling days INCLUDING today —
    // see `sellingDaysRemaining` in sales_calculator.dart.
    expect(calendarDaysAfterToday(now), 16);
  });

  test('submission window accepts today and prior three Cairo days only', () {
    final now = DateTime.utc(2026, 8, 5, 12);
    for (final key in ['20260805', '20260804', '20260803', '20260802']) {
      expect(isWithinSalesSubmissionWindow(key, now: now), isTrue);
    }
    expect(isWithinSalesSubmissionWindow('20260801', now: now), isFalse);
    expect(isWithinSalesSubmissionWindow('20260806', now: now), isFalse);
  });

  test('submission window uses Cairo civil day at DST boundary', () {
    // 22:30 UTC is 01:30 Cairo on the 2026 DST boundary day.
    final now = DateTime.utc(2026, 4, 23, 22, 30);
    expect(isWithinSalesSubmissionWindow('20260424', now: now), isTrue);
    expect(isWithinSalesSubmissionWindow('20260420', now: now), isFalse);
  });
}
