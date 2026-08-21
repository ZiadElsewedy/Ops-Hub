import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:opshub/features/schedule/presentation/widgets/schedule_helpers.dart';

/// One (day, shift) slot in the weekly grid.
typedef SlotKey = (ScheduleDay, ScheduleShift);

/// The clickable insight categories on the schedule's insight strip. Each is a
/// **fact** derived from the roster — never a staffing target or quota (a
/// settled product rejection): an empty shift is information for the admin's
/// judgment, not a flagged fault.
enum ScheduleInsightKind { open, onePerson, doubleBooked, shortRest, leaveClash }

/// Facts derived from the week's roster, computed once per build by
/// [computeScheduleInsights] and consumed by the insight strip (counts), the
/// grid (cell highlighting + per-chip cues) and the week-summary line.
class ScheduleInsights {
  const ScheduleInsights({
    required this.openSlots,
    required this.onePersonSlots,
    required this.conflictSlots,
    required this.doubleBookedByDay,
    required this.shortRestSlots,
    required this.shortRestByDay,
    required this.leaveClashSlots,
    required this.leaveClashByDay,
    required this.morningAssignments,
    required this.nightAssignments,
    required this.leaveEntries,
    required this.scheduledPeople,
  });

  /// Slots with no (resolvable) assignee.
  final Set<SlotKey> openSlots;

  /// Slots covered by exactly one person.
  final Set<SlotKey> onePersonSlots;

  /// Both slots of any day that has at least one double-booked person.
  final Set<SlotKey> conflictSlots;

  /// Per day: the people assigned to BOTH shifts of that day — the one real
  /// conflict the current one-slot-per-shift model can express.
  final Map<ScheduleDay, Set<String>> doubleBookedByDay;

  /// The night slot + next-day morning slot of every short-rest pair.
  final Set<SlotKey> shortRestSlots;

  /// Per day: people on this day's **morning** who worked the previous
  /// night — a night ends 23:00 (00:00 on weekends) and the next morning
  /// starts 08:30, so the turnaround is short (Schedule 5.0).
  final Map<ScheduleDay, Set<String>> shortRestByDay;

  /// Slots where someone is assigned on a day they're marked on leave.
  final Set<SlotKey> leaveClashSlots;

  /// Per day: people assigned to a shift while marked on leave that day.
  final Map<ScheduleDay, Set<String>> leaveClashByDay;

  /// Week totals (valid assignments only) for the compact week summary.
  final int morningAssignments;
  final int nightAssignments;

  /// Total leave entries this week (current branch members only).
  final int leaveEntries;

  /// Distinct people assigned anywhere this week.
  final int scheduledPeople;

  int get openCount => openSlots.length;
  int get onePersonCount => onePersonSlots.length;
  int get doubleBookedCount =>
      doubleBookedByDay.values.fold(0, (sum, uids) => sum + uids.length);
  int get shortRestCount =>
      shortRestByDay.values.fold(0, (sum, uids) => sum + uids.length);
  int get leaveClashCount =>
      leaveClashByDay.values.fold(0, (sum, uids) => sum + uids.length);

  /// Nothing worth flagging — the strip collapses to a quiet all-clear line.
  bool get allClear =>
      openCount == 0 &&
      onePersonCount == 0 &&
      doubleBookedCount == 0 &&
      shortRestCount == 0 &&
      leaveClashCount == 0;

  bool isDoubleBooked(ScheduleDay day, String uid) =>
      doubleBookedByDay[day]?.contains(uid) ?? false;

  Set<SlotKey> slotsFor(ScheduleInsightKind kind) => switch (kind) {
        ScheduleInsightKind.open => openSlots,
        ScheduleInsightKind.onePerson => onePersonSlots,
        ScheduleInsightKind.doubleBooked => conflictSlots,
        ScheduleInsightKind.shortRest => shortRestSlots,
        ScheduleInsightKind.leaveClash => leaveClashSlots,
      };
}

/// Derives the week's staffing facts from the schedule already in memory.
/// Orphaned (unresolvable) assignments never count as coverage — consistent
/// with [validAssignments] everywhere else. When a shift [filter] is active,
/// open / one-person facts consider only the visible shift; double-booking,
/// short rest and leave clashes are inherently cross-shift/day-level so they
/// are always computed over both.
///
/// [previousSaturdayNight] — who worked the **previous week's** Saturday
/// night (from that week's doc, loaded by the cubit) — catches the most
/// common turnaround of all: Saturday night (ends at/after midnight) → Sunday morning.
ScheduleInsights computeScheduleInsights(
  WeeklyScheduleEntity schedule,
  List<UserEntity> members, {
  ScheduleShift? filter,
  Set<String> previousSaturdayNight = const {},
}) {
  final open = <SlotKey>{};
  final onePerson = <SlotKey>{};
  final conflictSlots = <SlotKey>{};
  final doubleBookedByDay = <ScheduleDay, Set<String>>{};
  final shortRestSlots = <SlotKey>{};
  final shortRestByDay = <ScheduleDay, Set<String>>{};
  final leaveClashSlots = <SlotKey>{};
  final leaveClashByDay = <ScheduleDay, Set<String>>{};
  final scheduled = <String>{};
  var morningTotal = 0;
  var nightTotal = 0;
  var leaveTotal = 0;

  final memberUids = {for (final m in members) m.uid};
  // Seeded with last week's Saturday-night crew so Sunday morning is checked
  // too; orphan uids in the seed are harmless (the intersection with this
  // week's *valid* morning crew filters them out).
  Set<String>? previousNight =
      previousSaturdayNight.isEmpty ? null : previousSaturdayNight;

  for (final day in ScheduleDay.values) {
    final morning = validAssignments(
        schedule.employeesFor(day, ScheduleShift.morning), members).toSet();
    final night = validAssignments(
        schedule.employeesFor(day, ScheduleShift.night), members).toSet();
    morningTotal += morning.length;
    nightTotal += night.length;
    scheduled.addAll(morning);
    scheduled.addAll(night);

    final both = morning.intersection(night);
    if (both.isNotEmpty) {
      doubleBookedByDay[day] = both;
      conflictSlots.add((day, ScheduleShift.morning));
      conflictSlots.add((day, ScheduleShift.night));
    }

    // Short rest: last night's crew opening this morning. For Sunday the
    // "last night" lives in the previous week's doc ([previousSaturdayNight])
    // — its night slot isn't on this grid, so only the morning highlights.
    if (previousNight != null) {
      final tired = morning.intersection(previousNight);
      if (tired.isNotEmpty) {
        shortRestByDay[day] = tired;
        shortRestSlots.add((day, ScheduleShift.morning));
        if (day.index > 0) {
          shortRestSlots.add((
            ScheduleDay.values[day.index - 1],
            ScheduleShift.night,
          ));
        }
      }
    }
    previousNight = night;

    // Leave: count entries for current members; flag anyone assigned while
    // marked away for the day.
    final leaveToday = schedule.leaveOn(day);
    for (final entry in leaveToday.entries) {
      if (!memberUids.contains(entry.key)) continue;
      leaveTotal++;
      final clashShifts = [
        if (morning.contains(entry.key)) ScheduleShift.morning,
        if (night.contains(entry.key)) ScheduleShift.night,
      ];
      if (clashShifts.isNotEmpty) {
        (leaveClashByDay[day] ??= {}).add(entry.key);
        for (final s in clashShifts) {
          leaveClashSlots.add((day, s));
        }
      }
    }

    for (final shift in ScheduleShift.values) {
      if (filter != null && shift != filter) continue;
      final count =
          (shift == ScheduleShift.morning ? morning : night).length;
      if (count == 0) {
        open.add((day, shift));
      } else if (count == 1) {
        onePerson.add((day, shift));
      }
    }
  }

  return ScheduleInsights(
    openSlots: open,
    onePersonSlots: onePerson,
    conflictSlots: conflictSlots,
    doubleBookedByDay: doubleBookedByDay,
    shortRestSlots: shortRestSlots,
    shortRestByDay: shortRestByDay,
    leaveClashSlots: leaveClashSlots,
    leaveClashByDay: leaveClashByDay,
    morningAssignments: morningTotal,
    nightAssignments: nightTotal,
    leaveEntries: leaveTotal,
    scheduledPeople: scheduled.length,
  );
}
