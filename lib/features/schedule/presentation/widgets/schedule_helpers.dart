import 'package:opshub/core/enums/schedule_day.dart';
import 'package:opshub/core/enums/schedule_shift.dart';
import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/schedule/domain/entities/weekly_schedule_entity.dart';

/// Best display name for a user — their display name, falling back to email.
String userDisplayName(UserEntity u) =>
    (u.displayName != null && u.displayName!.isNotEmpty)
        ? u.displayName!
        : u.email;

/// Human-readable role label for employee rows / sheets.
String roleLabel(UserRole role) => switch (role) {
      UserRole.admin => 'Admin',
      UserRole.manager => 'Store Manager',
      UserRole.employee => 'Employee',
    };

/// Resolves a uid to a display name from a list of branch [members].
String nameForUid(String uid, List<UserEntity> members) {
  final u = userForUid(uid, members);
  return u == null ? 'Unknown' : userDisplayName(u);
}

/// Compact name for dense surfaces (schedule cells): first name + last initial
/// (e.g. `Ahmed M.`), falling back to the email local-part when there's no
/// display name. Keeps shift cells readable without wrapping.
String shortName(UserEntity u) {
  final full = userDisplayName(u).trim();
  final base = full.contains('@') ? full.split('@').first : full;
  final parts = base.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return base;
  if (parts.length == 1) return parts.first;
  return '${parts.first} ${parts[1][0]}.';
}

/// Resolves a uid to its [UserEntity] from a list of branch [members], or null.
UserEntity? userForUid(String uid, List<UserEntity> members) {
  for (final m in members) {
    if (m.uid == uid) return m;
  }
  return null;
}

/// True when [uid] is assigned to a slot but no longer belongs to the branch —
/// a **broken/orphaned reference** (the employee was moved to another branch,
/// removed, or their account is gone, while the schedule slot still holds their
/// uid). These must be surfaced explicitly and resolved, never masked as a name.
bool isOrphanAssignment(String uid, List<UserEntity> members) =>
    userForUid(uid, members) == null;

/// A short, readable fragment of a uid for surfacing a broken reference
/// (e.g. `a1b2c3…`), so an admin can identify the stale entry.
String shortUid(String uid) =>
    uid.length <= 6 ? uid : '${uid.substring(0, 6)}…';

/// The assigned uids that still resolve to a current branch member — the slot's
/// **real** coverage (orphaned references excluded).
List<String> validAssignments(List<String> uids, List<UserEntity> members) =>
    [for (final uid in uids) if (!isOrphanAssignment(uid, members)) uid];

/// The assigned uids that no longer resolve to a branch member — broken/orphaned
/// references to surface and resolve (never counted as coverage).
List<String> orphanAssignments(List<String> uids, List<UserEntity> members) =>
    [for (final uid in uids) if (isOrphanAssignment(uid, members)) uid];

/// The employees actually **on the schedule** for [schedule]'s week — anyone
/// assigned to at least one morning/night slot across the seven days — sorted by
/// display name.
///
/// This is the roster the Final view (and its PNG/PDF exports) publish: a
/// "who's working this week" sheet, **not** a directory of every branch member.
/// The editor still shows the whole team (you assign from everyone); the printed
/// output shows only the people who ended up on it. Orphaned assignments (uids
/// no longer in [members]) are dropped, exactly as everywhere else coverage is
/// counted — a stale uid is a broken reference to resolve in the editor, never a
/// phantom row on the published sheet.
List<UserEntity> scheduledRoster(
  WeeklyScheduleEntity schedule,
  List<UserEntity> members,
) {
  final scheduled = <String>{
    for (final day in ScheduleDay.values)
      for (final shift in ScheduleShift.values)
        ...schedule.employeesFor(day, shift),
  };
  return [
    for (final m in members)
      if (scheduled.contains(m.uid)) m,
  ]..sort((a, b) => userDisplayName(a)
      .toLowerCase()
      .compareTo(userDisplayName(b).toLowerCase()));
}
