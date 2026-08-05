/// DROP's pinned business timezone for sales accounting keys.
const salesBusinessTimeZone = 'Africa/Cairo';

/// Converts an instant to Cairo civil time without a timezone package. Egypt's
/// current DST rule is used: DST starts at 00:00 on the last Friday in April
/// and ends at 00:00 on the last Friday in October (UTC+3 while active).
/// V1 accepts only [salesBusinessTimeZone].
DateTime cairoCivilTime(
  DateTime value, {
  String timeZone = salesBusinessTimeZone,
}) {
  if (timeZone != salesBusinessTimeZone) {
    throw ArgumentError.value(
      timeZone,
      'timeZone',
      'Only Africa/Cairo is supported.',
    );
  }
  final utc = value.toUtc();
  final standard = utc.add(const Duration(hours: 2));
  final start = _lastWeekdayOfMonth(standard.year, 4, DateTime.friday);
  final end = _lastWeekdayOfMonth(standard.year, 10, DateTime.friday);
  final civilDate = DateTime(standard.year, standard.month, standard.day);
  final isDst = !civilDate.isBefore(start) && civilDate.isBefore(end);
  return utc.add(Duration(hours: isDst ? 3 : 2));
}

String businessMonthKey(
  DateTime now, {
  String timeZone = salesBusinessTimeZone,
}) {
  final cairo = cairoCivilTime(now, timeZone: timeZone);
  return '${cairo.year.toString().padLeft(4, '0')}${cairo.month.toString().padLeft(2, '0')}';
}

String businessDateKey(
  DateTime now, {
  String timeZone = salesBusinessTimeZone,
}) {
  final cairo = cairoCivilTime(now, timeZone: timeZone);
  return '${cairo.year.toString().padLeft(4, '0')}${cairo.month.toString().padLeft(2, '0')}${cairo.day.toString().padLeft(2, '0')}';
}

/// True when [dateKey] is today or one of the previous three Cairo civil days.
/// This is a client guardrail: Firestore rules cannot derive Cairo's date from
/// request time; manager approval remains the authoritative financial control.
bool isWithinSalesSubmissionWindow(String dateKey, {required DateTime now}) {
  if (!RegExp(r'^\d{8}$').hasMatch(dateKey)) return false;
  final target = DateTime.utc(int.parse(dateKey.substring(0, 4)), int.parse(dateKey.substring(4, 6)), int.parse(dateKey.substring(6, 8)));
  if (businessDateKey(target) != dateKey) return false;
  final today = businessDateKey(now);
  final todayUtc = DateTime.utc(int.parse(today.substring(0, 4)), int.parse(today.substring(4, 6)), int.parse(today.substring(6, 8)));
  final delta = todayUtc.difference(target).inDays;
  return delta >= 0 && delta <= 3;
}

int calendarDaysInMonth(
  DateTime now, {
  String timeZone = salesBusinessTimeZone,
}) {
  final cairo = cairoCivilTime(now, timeZone: timeZone);
  return DateTime(cairo.year, cairo.month + 1, 0).day;
}

int calendarDaysElapsed(
  DateTime now, {
  String timeZone = salesBusinessTimeZone,
}) => cairoCivilTime(now, timeZone: timeZone).day;

int calendarDaysRemainingInMonth(
  DateTime now, {
  String timeZone = salesBusinessTimeZone,
}) =>
    calendarDaysInMonth(now, timeZone: timeZone) -
    calendarDaysElapsed(now, timeZone: timeZone);

DateTime _lastWeekdayOfMonth(int year, int month, int weekday) {
  var date = DateTime(year, month + 1, 0);
  while (date.weekday != weekday) {
    date = date.subtract(const Duration(days: 1));
  }
  return date;
}
