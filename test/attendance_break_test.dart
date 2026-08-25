import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/features/attendance/domain/attendance_break.dart';

void main() {
  final base = DateTime(2026, 7, 11, 10);

  group('AttendanceBreak.minutes', () {
    test('closed break measures end - start', () {
      final b = AttendanceBreak(start: base, end: base.add(const Duration(minutes: 30)));
      expect(b.isOpen, isFalse);
      expect(b.minutes(DateTime(2026, 7, 11, 15)), 30);
    });

    test('open break measures to now', () {
      final b = AttendanceBreak(start: base);
      expect(b.isOpen, isTrue);
      expect(b.minutes(base.add(const Duration(minutes: 20))), 20);
    });

    test('never negative', () {
      final b = AttendanceBreak(start: base, end: base.subtract(const Duration(minutes: 5)));
      expect(b.minutes(base), 0);
    });

    test('closeAt closes an open break', () {
      final closed = AttendanceBreak(start: base).closeAt(base.add(const Duration(minutes: 15)));
      expect(closed.isOpen, isFalse);
      expect(closed.minutes(base), 15);
    });
  });

  group('totalBreakMinutes / openBreak', () {
    test('sums closed + open breaks to now', () {
      final now = DateTime(2026, 7, 11, 13);
      final breaks = [
        AttendanceBreak(start: DateTime(2026, 7, 11, 10), end: DateTime(2026, 7, 11, 10, 30)),
        AttendanceBreak(start: DateTime(2026, 7, 11, 12, 45)), // open, 15m to 13:00
      ];
      expect(totalBreakMinutes(breaks, now), 45);
    });

    test('openBreak finds the running one, else null', () {
      final open = AttendanceBreak(start: base);
      expect(openBreak([open]), open);
      expect(
        openBreak([AttendanceBreak(start: base, end: base.add(const Duration(minutes: 5)))]),
        isNull,
      );
      expect(openBreak(const []), isNull);
    });
  });

  test('value equality', () {
    expect(
      AttendanceBreak(start: base, end: base.add(const Duration(minutes: 10))),
      AttendanceBreak(start: base, end: base.add(const Duration(minutes: 10))),
    );
  });
}
