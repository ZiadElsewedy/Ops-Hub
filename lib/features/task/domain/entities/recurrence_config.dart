import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:drop/core/enums/recurrence_frequency.dart';

part 'recurrence_config.freezed.dart';

/// How a task repeats. Attached to a [TaskEntity] when the manager sets it to
/// recur automatically. When a recurring task is approved, the [TaskCubit]
/// creates the next instance using [nextOccurrence].
@freezed
class RecurrenceConfig with _$RecurrenceConfig {
  const RecurrenceConfig._();

  const factory RecurrenceConfig({
    required RecurrenceFrequency frequency,

    /// How many units between occurrences (e.g. interval=2 + daily = every 2 days).
    @Default(1) int interval,

    /// Target weekday for weekly recurrence: DateTime.monday = 1 … DateTime.sunday = 7.
    @Default(1) int weekday,

    /// Hour of day the task should start (24h, default 9 = 9 AM).
    @Default(9) int hour,
    @Default(0) int minute,
  }) = _RecurrenceConfig;

  /// Returns the next deadline after [from] based on this recurrence rule.
  DateTime nextOccurrence(DateTime from) {
    final base = DateTime(from.year, from.month, from.day, hour, minute);
    switch (frequency) {
      case RecurrenceFrequency.none:
        return from;
      case RecurrenceFrequency.daily:
        return DateTime(
          base.year,
          base.month,
          base.day + interval,
          hour,
          minute,
        );
      case RecurrenceFrequency.weekly:
        var candidate = DateTime(
          base.year,
          base.month,
          base.day + 1,
          hour,
          minute,
        );
        for (var i = 0; i < 7; i++) {
          if (candidate.weekday == weekday) break;
          candidate = DateTime(
            candidate.year,
            candidate.month,
            candidate.day + 1,
            hour,
            minute,
          );
        }
        return candidate;
      case RecurrenceFrequency.monthly:
        var month = from.month + interval;
        var year = from.year;
        while (month > 12) {
          month -= 12;
          year++;
        }
        final day = from.day.clamp(1, _daysInMonth(year, month));
        return DateTime(year, month, day, hour, minute);
    }
  }

  static int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;
}
