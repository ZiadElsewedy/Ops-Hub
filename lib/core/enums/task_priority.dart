/// Task priority, stored as a string in `tasks/{taskId}.priority`.
enum TaskPriority {
  low,
  normal,
  high;

  String get value => name;

  /// Human-readable label for display — **never** confuse with [value], the
  /// persisted wire string written to `tasks/{taskId}.priority`.
  String get label => switch (this) {
    TaskPriority.low => 'Low',
    TaskPriority.normal => 'Normal',
    TaskPriority.high => 'High',
  };

  bool get isLow => this == TaskPriority.low;
  bool get isNormal => this == TaskPriority.normal;
  bool get isHigh => this == TaskPriority.high;

  /// Parses the stored string; unknown/missing → [normal].
  static TaskPriority fromString(String? raw) {
    switch (raw) {
      case 'low':
        return TaskPriority.low;
      case 'high':
        return TaskPriority.high;
      case 'normal':
      default:
        return TaskPriority.normal;
    }
  }
}
