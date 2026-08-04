import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/presentation/pages/my_tasks_screen.dart';

/// My Tasks is four segments — **Active · Late · Missed · Done** — and the whole
/// point of the split is that a task lands in exactly one of them. These tests
/// pin the two tabs that were carved out (Late, Missed) and the boundary each
/// one shares with Done.
///
/// The vocabulary under test is TASKS.md's: **Late** is *open* work past its
/// deadline (still actionable, still yours), **Missed** is the server's terminal
/// verdict on work that closed unfinished. They are different readings of
/// different tasks, never two names for one.
void main() {
  final now = DateTime.now();
  final past = now.subtract(const Duration(hours: 3));
  final future = now.add(const Duration(hours: 3));

  TaskEntity task(
    String id, {
    required TaskStatus status,
    DateTime? deadline,
  }) => TaskEntity(
    id: id,
    title: id,
    status: status,
    branchId: 'branch1',
    deadline: deadline,
  );

  group('lateTasks — open work past its deadline', () {
    test('picks up pending and started tasks whose deadline has passed', () {
      final all = [
        task('pending-late', status: TaskStatus.pending, deadline: past),
        task('started-late', status: TaskStatus.started, deadline: past),
      ];
      expect(lateTasks(all).map((t) => t.id), ['pending-late', 'started-late']);
    });

    test('ignores work that is not yet due, or has no deadline at all', () {
      final all = [
        task('future', status: TaskStatus.pending, deadline: future),
        task('undated', status: TaskStatus.started),
      ];
      expect(lateTasks(all), isEmpty);
    });

    test('excludes rejected rework — it keeps its "Needs attention" home', () {
      final all = [task('rework', status: TaskStatus.rejected, deadline: past)];
      expect(lateTasks(all), isEmpty);
    });

    test('excludes submitted work — the ball is with the reviewer', () {
      final all = [
        task('sent', status: TaskStatus.waitingReview, deadline: past),
        task('done-by-me', status: TaskStatus.completed, deadline: past),
      ];
      expect(lateTasks(all), isEmpty);
    });

    test('excludes every closed task, however overdue its deadline was', () {
      final all = [
        task('approved', status: TaskStatus.approved, deadline: past),
        task('missed', status: TaskStatus.missed, deadline: past),
        task('cancelled', status: TaskStatus.cancelled, deadline: past),
      ];
      expect(lateTasks(all), isEmpty);
    });

    test('every late task carries a deadline, so the tab can sort on it', () {
      final all = [
        task('a', status: TaskStatus.pending, deadline: past),
        task('b', status: TaskStatus.started),
      ];
      expect(lateTasks(all).every((t) => t.deadline != null), isTrue);
    });
  });

  group('missedTasks — closed and unfinished', () {
    test('is the status, never a derived overdue reading', () {
      final all = [
        task('recorded', status: TaskStatus.missed, deadline: past),
        // Overdue but still open: this is Late, and Late is not Missed.
        task('just-late', status: TaskStatus.pending, deadline: past),
      ];
      expect(missedTasks(all).map((t) => t.id), ['recorded']);
    });

    test('never absorbs a cancelled task', () {
      final all = [task('called-off', status: TaskStatus.cancelled)];
      expect(missedTasks(all), isEmpty);
    });
  });

  group('finishedTasks — the Done tab', () {
    test('keeps approved and cancelled together', () {
      final all = [
        task('ok', status: TaskStatus.approved),
        task('called-off', status: TaskStatus.cancelled),
      ];
      expect(finishedTasks(all).map((t) => t.id), ['ok', 'called-off']);
    });

    test('no longer carries missed work — that moved to its own tab', () {
      final all = [
        task('ok', status: TaskStatus.approved),
        task('gone', status: TaskStatus.missed),
      ];
      expect(finishedTasks(all).map((t) => t.id), ['ok']);
      expect(missedTasks(all).map((t) => t.id), ['gone']);
    });

    test('holds no open work', () {
      final all = [
        task('open', status: TaskStatus.pending),
        task('running', status: TaskStatus.started),
        task('sent', status: TaskStatus.waitingReview),
        task('rework', status: TaskStatus.rejected),
      ];
      expect(finishedTasks(all), isEmpty);
    });
  });

  group('the all-clear state', () {
    test('says caught up only when nothing is late', () {
      final copy = allClearCopy(0);
      expect(copy.behind, isFalse);
      expect(copy.headline, "You're all caught up");
      expect(copy.body, contains('Enjoy your shift'));
    });

    test('never congratulates an employee sitting on late work', () {
      final copy = allClearCopy(2);
      expect(copy.behind, isTrue);
      expect(copy.headline, isNot(contains('caught up')));
      expect(copy.headline, 'Nothing new — but you are behind');
      expect(copy.body, '2 tasks passed their deadline and still need doing.');
    });

    test('reads naturally for a single late task', () {
      expect(
        allClearCopy(1).body,
        '1 task passed its deadline and still needs doing.',
      );
    });
  });

  test('Late · Missed · Done never show the same task twice', () {
    final all = [
      task('open-late', status: TaskStatus.pending, deadline: past),
      task('running-late', status: TaskStatus.started, deadline: past),
      task('rework', status: TaskStatus.rejected, deadline: past),
      task('upcoming', status: TaskStatus.pending, deadline: future),
      task('sent', status: TaskStatus.waitingReview, deadline: past),
      task('approved', status: TaskStatus.approved, deadline: past),
      task('missed', status: TaskStatus.missed, deadline: past),
      task('cancelled', status: TaskStatus.cancelled, deadline: past),
    ];

    final ids = [
      for (final t in lateTasks(all)) t.id,
      for (final t in missedTasks(all)) t.id,
      for (final t in finishedTasks(all)) t.id,
    ];

    expect(ids.toSet().length, ids.length, reason: 'a task appears in one tab');
    // The two tasks the three tabs deliberately leave to Active.
    expect(
      all.map((t) => t.id).toSet().difference(ids.toSet()),
      {'rework', 'upcoming', 'sent'},
    );
  });
}
