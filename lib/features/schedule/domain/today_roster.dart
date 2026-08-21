/// Who is on shift on a given day — the pure derivation behind the "on shift
/// today" peek (a fast, read-only answer to *who is in*, as opposed to opening
/// the weekly grid to edit it).
///
/// No Flutter, no Firestore: it joins a [WeeklyScheduleEntity]'s assignments
/// with the branch's member list so the roster can be unit-tested without a
/// widget tree, and so the sheet renders exactly what this returns.
library;

import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/schedule/domain/entities/weekly_schedule_entity.dart';
import 'package:opshub/features/schedule/domain/shift_hours.dart';

/// One shift's roster for the day: its hours and the people on it, resolved to
/// real users and sorted by display name.
class ShiftRoster {
  const ShiftRoster({
    required this.shift,
    required this.hours,
    required this.people,
  });

  final ScheduleShift shift;
  final ShiftHours hours;
  final List<UserEntity> people;

  bool get isEmpty => people.isEmpty;
}

/// The whole day's cover.
class TodayRoster {
  const TodayRoster({
    required this.shifts,
    required this.teamSize,
    required this.unresolved,
  });

  /// One entry per shift, in [ScheduleShift.values] order — **including empty
  /// shifts**, because "nobody is on nights" is the single most important thing
  /// this view can tell a manager. The UI decides how to draw an empty one.
  final List<ShiftRoster> shifts;

  /// The branch's member count, so cover reads as "N of M".
  final int teamSize;

  /// Assigned uids that no longer resolve to a branch member (someone moved
  /// branch or was deactivated while still on the roster). Surfaced rather than
  /// silently dropped: it is the only reason this view's headcount could
  /// disagree with a count derived straight from the assignment lists.
  final int unresolved;

  /// Distinct people actually on shift today.
  int get onShift => {
    for (final s in shifts)
      for (final p in s.people) p.uid,
  }.length;

  bool get isEmpty => shifts.every((s) => s.isEmpty);
}

/// Derive [day]'s roster for a branch from its [schedule] and [members].
///
/// A null [schedule] (no week published yet) yields every shift empty rather
/// than an error — an unpublished week is a real, readable state.
TodayRoster todayRoster({
  required WeeklyScheduleEntity? schedule,
  required List<UserEntity> members,
  ScheduleDay? day,
}) {
  final today = day ?? ScheduleDay.today();
  final byUid = {for (final m in members) m.uid: m};

  var unresolved = 0;
  final shifts = <ShiftRoster>[];
  for (final shift in ScheduleShift.values) {
    final uids = schedule?.employeesFor(today, shift) ?? const <String>[];
    final people = <UserEntity>[];
    for (final uid in uids) {
      final user = byUid[uid];
      if (user == null) {
        unresolved++;
      } else {
        people.add(user);
      }
    }
    people.sort(
      (a, b) => _label(a).toLowerCase().compareTo(_label(b).toLowerCase()),
    );
    shifts.add(
      ShiftRoster(
        shift: shift,
        hours:
            schedule?.hoursFor(today, shift) ??
            ShiftHours.standard(today, shift),
        people: people,
      ),
    );
  }

  return TodayRoster(
    shifts: shifts,
    teamSize: members.length,
    unresolved: unresolved,
  );
}

String _label(UserEntity u) =>
    (u.displayName != null && u.displayName!.trim().isNotEmpty)
    ? u.displayName!.trim()
    : u.email;
