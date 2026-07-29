/// How a task's work is assigned. `individual`/`team` both populate
/// [TaskEntity.assigneeIds] — they differ in *intent*, not in shape:
/// `individual` names a single owner, `team` is an ad-hoc set of people the
/// manager hand-picks (there is no separate named-team entity). `shift` leaves
/// `assigneeIds` empty and instead targets whoever is rostered on
/// [TaskEntity.shift] for the relevant day (see `canUserAccessTask`). Stored
/// lower-case in `tasks/{id}.assignmentType`.
///
/// **The enum names are the persisted values — never rename them.** When the UI
/// wording moved from "Employee / Team" to "Individual / Group", only [label]
/// changed, so every task document already in Firestore (and the
/// `assignmentType == 'shift'` check in `firestore.rules`) keeps working with no
/// migration.
enum TaskAssignmentType {
  individual,
  team,
  shift;

  /// The string persisted in Firestore (the lower-case name).
  String get value => name;

  /// Parses the stored string; missing/unknown → [individual] (every task
  /// written before this field existed keeps working unchanged).
  static TaskAssignmentType fromString(String? raw) => switch (raw) {
        'team' => team,
        'shift' => shift,
        _ => individual,
      };

  /// The human label. "Group" (not "Team") because this is a set of people the
  /// manager picks for one task, not a standing organisational unit.
  String get label => switch (this) {
        TaskAssignmentType.individual => 'Individual',
        TaskAssignmentType.team => 'Group',
        TaskAssignmentType.shift => 'Shift',
      };
}
