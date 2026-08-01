/// Deterministic identity for an attendance record. Pure, framework-free.
///
/// A record's document id is **derived** from (user, calendar date, shift), not
/// random: `"{uid}_{yyyyMMdd}_{shift}"`. This is the whole offline-safety story —
/// no bespoke sync engine needed:
///   * a clock-in is an idempotent `set(..., merge)` on a *known* id, so a
///     double-tap, a retry, or an offline replay overwrites the same doc instead
///     of minting a duplicate;
///   * "today's record" is a direct `doc(id).get()/snapshots()` — no query, no
///     composite index, exactly one document read.
///
/// A person can (rarely) work both the morning and night slot on the same day;
/// keying on the shift keeps those as two distinct, non-colliding records.
library;

import 'package:drop/core/enums/schedule_shift.dart';

/// The date key `yyyyMMdd` for [date] (local calendar day of the shift). Stored
/// on the record as `dayKey` so the branch live board can query one bounded day
/// (`where('branchId'==).where('dayKey'==)`).
String attendanceDayKey(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y$m$d';
}

/// The calendar date a `yyyyMMdd` [key] names, or `null` if it is not one.
///
/// The inverse of [attendanceDayKey], for surfaces that take a day key from a
/// route. Rejects a malformed length, non-numeric parts, and dates the calendar
/// normalizes away (`20260231`) — a route parameter is user input.
DateTime? parseAttendanceDayKey(String key) {
  if (key.length != 8) return null;
  final year = int.tryParse(key.substring(0, 4));
  final month = int.tryParse(key.substring(4, 6));
  final day = int.tryParse(key.substring(6, 8));
  if (year == null || month == null || day == null) return null;
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

/// The deterministic document id for [uid]'s [shift] on [date].
String attendanceDocId({
  required String uid,
  required DateTime date,
  required ScheduleShift shift,
}) =>
    '${uid}_${attendanceDayKey(date)}_${shift.value}';

/// Which shift band an **unscheduled** clock-in belongs to ([ADR-018]).
///
/// The record id is `{uid}_{yyyyMMdd}_{shift}` (T1), so an unscheduled shift
/// still needs one of the two bands. It is chosen from the clock, using the
/// same boundary as `ScheduleShift.timeRange`'s defaults (night starts 15:00).
///
/// Deliberately *not* a third enum value: `ScheduleShift` is persisted, and
/// widening it to carry "unscheduled" would put a scheduling concept into a
/// vocabulary the roster owns. What makes a shift unscheduled is the absence of
/// a scheduled window on the record, not its band.
///
/// A collision is a feature: if the roster later adds that person to that band
/// on that day, it resolves to the same record rather than a duplicate.
ScheduleShift unscheduledShiftFor(DateTime now) =>
    now.hour < 15 ? ScheduleShift.morning : ScheduleShift.night;
