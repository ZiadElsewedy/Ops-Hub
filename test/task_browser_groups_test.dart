import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/core/enums/task_status.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/presentation/widgets/task_browser_groups.dart';

/// The record browser's date sectioning. Pure Dart — `task_feed.dart` still owns
/// every forward-looking bucket, and this only decides where **finished** work
/// goes, because the engine's answer for that ("Done today") is a statement
/// about the live feed's active window, not about the record.
void main() {
  // A fixed Wednesday, so "earlier this week" and "last week" are unambiguous
  // against OpsHub's Sunday→Saturday schedule week.
  final now = DateTime(2026, 8, 5, 14, 0);

  TaskEntity approved(String id, DateTime at) => TaskEntity(
    id: id,
    title: id,
    status: TaskStatus.approved,
    approvedAt: at,
  );

  List<String> labels(List<TaskEntity> tasks) =>
      [for (final g in browserGroups(tasks, now)) g.label];

  test('finished work is bucketed by when it closed', () {
    final groups = browserGroups([
      approved('today', now.subtract(const Duration(hours: 2))),
      approved('yesterday', DateTime(2026, 8, 4, 9)),
      approved('sunday', DateTime(2026, 8, 2, 9)), // start of this week
      approved('lastweek', DateTime(2026, 7, 30, 9)),
      approved('ancient', DateTime(2026, 5, 1, 9)),
    ], now);

    expect(
      [for (final g in groups) g.label],
      ['Closed today', 'Yesterday', 'Earlier this week', 'Last week', 'Older'],
    );
  });

  test('a task approved weeks ago is never announced as closed today', () {
    expect(labels([approved('a', DateTime(2026, 7, 1))]), ['Older']);
  });

  test('open work keeps the engine\'s own forward-looking buckets', () {
    final groups = browserGroups([
      TaskEntity(
        id: 'late',
        title: 'late',
        status: TaskStatus.started,
        deadline: now.subtract(const Duration(days: 3)),
      ),
      TaskEntity(
        id: 'today',
        title: 'today',
        status: TaskStatus.pending,
        deadline: now.add(const Duration(hours: 2)),
      ),
      const TaskEntity(id: 'nodate', title: 'nodate'),
    ], now);

    expect(
      [for (final g in groups) g.label],
      ['Late', 'Today', 'No due date'],
    );
  });

  test('open sections always sort above record sections', () {
    final groups = browserGroups([
      approved('closed', now),
      TaskEntity(
        id: 'open',
        title: 'open',
        status: TaskStatus.pending,
        deadline: now.add(const Duration(hours: 2)),
      ),
    ], now);

    expect([for (final g in groups) g.label], ['Today', 'Closed today']);
  });

  test('a record section reads newest first', () {
    final groups = browserGroups([
      approved('older', DateTime(2026, 4, 1)),
      approved('newer', DateTime(2026, 6, 1)),
    ], now);

    expect(groups.single.label, 'Older');
    expect([for (final t in groups.single.tasks) t.id], ['newer', 'older']);
  });

  test('each terminal status is dated from its own stamp', () {
    final missed = TaskEntity(
      id: 'm',
      title: 'm',
      status: TaskStatus.missed,
      missedAt: DateTime(2026, 8, 4, 23),
    );
    final cancelled = TaskEntity(
      id: 'c',
      title: 'c',
      status: TaskStatus.cancelled,
      cancelledAt: DateTime(2026, 8, 4, 10),
    );

    expect(labels([missed, cancelled]), ['Yesterday']);
    expect(taskRecordDate(missed), DateTime(2026, 8, 4, 23));
    expect(taskRecordDate(cancelled), DateTime(2026, 8, 4, 10));
  });

  test('a record with no timestamp at all still lands somewhere', () {
    // Documents written before the lifecycle stamps existed must not vanish
    // from the list, and must not be claimed to have closed today.
    expect(
      labels([const TaskEntity(id: 'x', title: 'x', status: TaskStatus.approved)]),
      ['Older'],
    );
  });
}
