import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/features/task/presentation/activity_format.dart';

/// The one place the "finished late" phrase is composed — every per-task
/// lateness call site (task card, task details, Done tab, Operations) renders
/// through [formatLateness], so this is the only place the wording is tested.
void main() {
  test('drops the minute unit once whole hours are present', () {
    expect(formatLateness(const Duration(hours: 3)), '3h late');
  });

  test('shows minutes alongside hours when both are non-zero', () {
    expect(
      formatLateness(const Duration(hours: 3, minutes: 12)),
      '3h 12m late',
    );
  });

  test('minutes-only for anything under an hour', () {
    expect(formatLateness(const Duration(minutes: 45)), '45m late');
  });

  test('drops the hour unit once whole days are present', () {
    expect(formatLateness(const Duration(days: 2)), '2d late');
  });

  test('shows hours alongside days when both are non-zero', () {
    expect(
      formatLateness(const Duration(days: 2, hours: 4)),
      '2d 4h late',
    );
  });

  test('never drops below 1m even for a sub-minute overshoot', () {
    expect(formatLateness(const Duration(seconds: 30)), '1m late');
  });
}
