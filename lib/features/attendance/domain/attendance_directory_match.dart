import 'package:opshub/features/attendance/domain/attendance_history_query.dart';

/// One person in the branch directory, reduced to what the reviewer search needs.
/// The cubit maps a `UserEntity` to this so the pure resolver (and the state that
/// carries it) never depends on the auth feature.
class AttendanceDirectoryEntry {
  const AttendanceDirectoryEntry({required this.userId, required this.name});

  final String userId;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is AttendanceDirectoryEntry &&
      other.userId == userId &&
      other.name == name;

  @override
  int get hashCode => Object.hash(userId, name);

  @override
  String toString() => 'AttendanceDirectoryEntry($userId, "$name")';
}

/// A branch employee the reviewer searched for who has **no attendance surface**
/// in the current window — neither a record nor a rostered-absence gap. Rendered
/// as its own quiet "no attendance this period" row so the search resolves against
/// the whole directory, not only the days that happened to produce a document.
class AttendanceDirectoryMatch {
  const AttendanceDirectoryMatch({required this.userId, required this.name});

  final String userId;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is AttendanceDirectoryMatch &&
      other.userId == userId &&
      other.name == name;

  @override
  int get hashCode => Object.hash(userId, name);

  @override
  String toString() => 'AttendanceDirectoryMatch($userId, "$name")';
}

/// Branch employees the reviewer's **name search** names who are not already
/// represented in the window by a record or a gap — the "window-independent" half
/// of the search: an employee with no shift and no punch this period is otherwise
/// invisible, so "Mohamed's attendance for July" reads as *no matches* even when
/// Mohamed is a real, active teammate.
///
/// Deliberately gated on a **non-empty** search term: with no term this would
/// list every teammate who happened not to work the window, burying the actual
/// records. Uses the same `attendanceSearchNormalize` fold as the record/gap
/// search (case-, diacritic- and hamza-insensitive), so all three halves of the
/// list agree on what a name matches. Pure — no Flutter, no Firestore.
List<AttendanceDirectoryMatch> attendanceDirectoryOnlyMatches({
  required List<AttendanceDirectoryEntry> directory,
  required AttendanceHistoryQuery query,
  required Set<String> presentUids,
}) {
  final needle = attendanceSearchNormalize(query.text);
  if (needle.isEmpty) return const [];

  final out = <AttendanceDirectoryMatch>[];
  final seen = <String>{};
  for (final person in directory) {
    if (presentUids.contains(person.userId)) continue;
    if (!seen.add(person.userId)) continue; // de-dupe a doubled directory
    if (!attendanceSearchNormalize(person.name).contains(needle)) continue;
    out.add(
      AttendanceDirectoryMatch(userId: person.userId, name: person.name),
    );
  }
  out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return out;
}
