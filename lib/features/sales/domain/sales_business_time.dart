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
