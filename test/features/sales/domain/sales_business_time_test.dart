import 'package:drop/features/sales/domain/sales_business_time.dart';
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
    expect(calendarDaysRemainingInMonth(now), 16);
  });
}
