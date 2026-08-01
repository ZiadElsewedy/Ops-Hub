/// Kind of task. [daily] tasks recur every day (open store, count cash, close
/// store, …); [special] tasks are one-off assignments (inventory, product
/// arrangement, section review, emergency, …). Stored as a string in
/// `tasks/{taskId}.type`.
enum TaskType {
  daily,
  special;

  String get value => name;

  /// Human-readable label for display — **never** confuse with [value], the
  /// persisted wire string written to `tasks/{taskId}.type`.
  String get label => switch (this) {
    TaskType.daily => 'Daily',
    TaskType.special => 'Special',
  };

  bool get isDaily => this == TaskType.daily;
  bool get isSpecial => this == TaskType.special;

  /// Parses the stored string; unknown/missing → [daily].
  static TaskType fromString(String? raw) {
    switch (raw) {
      case 'special':
        return TaskType.special;
      case 'daily':
      default:
        return TaskType.daily;
    }
  }
}
