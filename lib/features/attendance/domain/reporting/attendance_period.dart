import 'package:opshub/features/attendance/domain/attendance_id.dart';
import 'package:opshub/features/schedule/domain/schedule_week.dart';

/// The reporting period shape. These values are pure-domain classifications for
/// the future reporting ledger; this task does not persist them.
enum AttendancePeriodType {
  daily,
  weekly,
  monthly,
  payPeriod;

  String get label => switch (this) {
        AttendancePeriodType.daily => 'Daily',
        AttendancePeriodType.weekly => 'Weekly',
        AttendancePeriodType.monthly => 'Monthly',
        AttendancePeriodType.payPeriod => 'Pay period',
      };
}

/// The lifecycle of a reporting period. These values are pure-domain
/// classifications for the future reporting ledger; this task does not persist
/// them.
// `AttendancePeriodStatus` (open → ready → locked → exported → restated) lived
// here for ADR-017's period lifecycle. It never had a reader in `lib/`, and
// ADR-019 dropped period locking outright — a week is now *reviewed*, which is
// an assertion rather than an enforced state. Removed rather than left dead.

/// Inclusive business-date window for attendance reports.
///
/// This pure domain layer is timezone-agnostic on purpose. It does not resolve
/// `Africa/Cairo`, offsets, or DST. Business dates are derived from the roster:
/// the weekly schedule's `weekStart` plus `ScheduleDay.index`, with shift
/// instants resolved from `ShiftHours` by `ShiftWindow`. When this logic is
/// mirrored server-side for persisted reporting rows, the Cloud Function layer
/// owns Cairo business-day resolution and stores the resolved metadata.
class AttendancePeriodWindow {
  AttendancePeriodWindow({
    required DateTime startDate,
    required DateTime endDate,
  })  : startDate = _startOfDay(startDate),
        endDate = _endOfDay(endDate);

  final DateTime startDate;
  final DateTime endDate;

  int get dayCount {
    final start = _startOfDay(startDate);
    final end = _startOfDay(endDate);
    return end.difference(start).inDays + 1;
  }

  bool contains(DateTime date) {
    return !date.isBefore(startDate) && !date.isAfter(endDate);
  }

  @override
  bool operator ==(Object other) =>
      other is AttendancePeriodWindow &&
      other.startDate == startDate &&
      other.endDate == endDate;

  @override
  int get hashCode => Object.hash(startDate, endDate);

  @override
  String toString() =>
      'AttendancePeriodWindow(start: $startDate, end: $endDate)';
}

AttendancePeriodWindow dailyWindow(DateTime date) =>
    AttendancePeriodWindow(startDate: date, endDate: date);

AttendancePeriodWindow weeklyWindow(DateTime anchor) {
  final start = ScheduleWeek.startOf(anchor);
  return AttendancePeriodWindow(
    startDate: start,
    endDate: start.add(const Duration(days: 6)),
  );
}

AttendancePeriodWindow monthlyWindow(int year, int month) =>
    AttendancePeriodWindow(
      startDate: DateTime(year, month),
      endDate: DateTime(year, month + 1, 0),
    );

/// Deterministic reporting-period id. Retries write the same id instead of
/// creating duplicate period facts.
String attendancePeriodId({
  required AttendancePeriodType type,
  required String scopeKey,
  required AttendancePeriodWindow window,
  int version = 1,
}) {
  final startKey = attendanceDayKey(window.startDate);
  final endKey = attendanceDayKey(window.endDate);
  return '${scopeKey}_${type.name}_${startKey}_${endKey}_v$version';
}

DateTime _startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime _endOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
