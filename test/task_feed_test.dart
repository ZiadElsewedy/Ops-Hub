import 'package:flutter_test/flutter_test.dart';
import 'package:drop/core/enums/schedule_shift.dart';
import 'package:drop/core/enums/task_assignment_type.dart';
import 'package:drop/core/enums/task_priority.dart';
import 'package:drop/core/enums/task_status.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/domain/task_feed.dart';

/// The global task feed engine (P2): active-set base + filters + presets +
/// search + sort + grouping — all pure and total.
void main() {
  final now = DateTime(2026, 7, 3, 10); // Fri 3 Jul, 10:00

  UserEntity user(String uid, String name) => UserEntity(
    uid: uid,
    email: '$uid@x.co',
    authProvider: 'password',
    displayName: name,
  );

  TaskEntity task(
    String id, {
    TaskStatus status = TaskStatus.pending,
    TaskPriority priority = TaskPriority.normal,
    String? branchId,
    List<String> assignees = const [],
    ScheduleShift? shift,
    TaskAssignmentType type = TaskAssignmentType.individual,
    DateTime? deadline,
    DateTime? startsAt,
    DateTime? approvedAt,
    DateTime? createdAt,
    String title = 'Task',
    String? description,
  }) => TaskEntity(
    id: id,
    title: title,
    description: description,
    status: status,
    priority: priority,
    branchId: branchId,
    assigneeIds: assignees,
    shift: shift,
    assignmentType: type,
    deadline: deadline,
    startsAt: startsAt,
    approvedAt: approvedAt,
    createdAt: createdAt,
  );

  final directory = {'u1': user('u1', 'Ziad'), 'u2': user('u2', 'Richard')};
  final branchNames = {'b1': 'Arkan', 'b2': 'Maadi'};

  group('active-set base', () {
    test('drops closed historical work from the active feed', () {
      final tasks = [
        task(
          'old',
          status: TaskStatus.approved,
          approvedAt: DateTime(2026, 6, 1),
        ),
        task('today', status: TaskStatus.approved, approvedAt: now),
        task(
          'missed',
          status: TaskStatus.missed,
          deadline: now.subtract(const Duration(hours: 1)),
        ),
        task('open'),
      ];
      final ids = applyFeed(
        tasks,
        const TaskFeedFilter(),
        now,
      ).map((t) => t.id);
      expect(ids, containsAll(['today', 'open']));
      expect(ids, isNot(contains('old')));
      expect(ids, isNot(contains('missed')));
    });

    test('keeps pending work scheduled for a future start', () {
      final ids = applyFeed(
        [
          task(
            'upcoming',
            startsAt: now.add(const Duration(hours: 1)),
            deadline: now.add(const Duration(hours: 4)),
          ),
        ],
        const TaskFeedFilter(),
        now,
      ).map((t) => t.id);

      expect(ids, ['upcoming']);
    });
  });

  group('scope filters compose (AND)', () {
    final tasks = [
      task('a', branchId: 'b1', assignees: ['u1'], priority: TaskPriority.high),
      task('b', branchId: 'b2', assignees: ['u2']),
      task('c', branchId: 'b1', assignees: ['u2'], shift: ScheduleShift.night),
    ];

    test('branch', () {
      final ids = applyFeed(
        tasks,
        const TaskFeedFilter(branchId: 'b1'),
        now,
      ).map((t) => t.id);
      expect(ids, ['a', 'c']);
    });
    test('assignee', () {
      final ids = applyFeed(
        tasks,
        const TaskFeedFilter(assigneeUid: 'u2'),
        now,
      ).map((t) => t.id);
      expect(ids, ['b', 'c']);
    });
    test('branch + priority together', () {
      final ids = applyFeed(
        tasks,
        const TaskFeedFilter(branchId: 'b1', priority: TaskPriority.high),
        now,
      ).map((t) => t.id);
      expect(ids, ['a']);
    });
    test('shift', () {
      final ids = applyFeed(
        tasks,
        const TaskFeedFilter(shift: ScheduleShift.night),
        now,
      ).map((t) => t.id);
      expect(ids, ['c']);
    });
  });

  group('presets', () {
    final tasks = [
      task('overdue', deadline: DateTime(2026, 6, 30)),
      task(
        'missed',
        status: TaskStatus.missed,
        deadline: DateTime(2026, 6, 30),
      ),
      task('review', status: TaskStatus.waitingReview),
      task('today', deadline: DateTime(2026, 7, 3, 15)),
      task('unassigned'),
      task('assigned', assignees: ['u1']),
      task(
        'shiftTask',
        type: TaskAssignmentType.shift,
        shift: ScheduleShift.morning,
      ),
    ];

    test('overdue → only late, non-terminal tasks', () {
      final ids = applyFeed(
        tasks,
        const TaskFeedFilter(preset: FeedPreset.overdue),
        now,
      ).map((t) => t.id);
      expect(ids, ['overdue']);
    });
    test('needsReview → waitingReview only', () {
      final ids = applyFeed(
        tasks,
        const TaskFeedFilter(preset: FeedPreset.needsReview),
        now,
      ).map((t) => t.id);
      expect(ids, ['review']);
    });
    test('dueToday → deadline is today', () {
      final ids = applyFeed(
        tasks,
        const TaskFeedFilter(preset: FeedPreset.dueToday),
        now,
      ).map((t) => t.id);
      expect(ids, ['today']);
    });
    test('unassigned → no assignee, excludes shift tasks', () {
      final ids = applyFeed(
        tasks,
        const TaskFeedFilter(preset: FeedPreset.unassigned),
        now,
      ).map((t) => t.id).toList();
      expect(ids, containsAll(['overdue', 'review', 'today', 'unassigned']));
      expect(ids, isNot(contains('assigned')));
      expect(ids, isNot(contains('shiftTask')));
    });
  });

  group('search', () {
    final tasks = [
      task('a', title: 'Open the shop', branchId: 'b1'),
      task('b', title: 'Clean boxes', assignees: ['u2'], branchId: 'b2'),
      task('c', title: 'Restock', description: 'display wall'),
    ];
    List<String> search(String q) => applyFeed(
      tasks,
      TaskFeedFilter(query: q),
      now,
      directory: directory,
      branchNames: branchNames,
    ).map((t) => t.id).toList();

    test('matches title', () => expect(search('shop'), ['a']));
    test('matches description', () => expect(search('wall'), ['c']));
    test('matches branch name', () => expect(search('maadi'), ['b']));
    test('matches assignee name', () => expect(search('richard'), ['b']));
    test('is case-insensitive', () => expect(search('OPEN'), ['a']));
  });

  group('sort', () {
    test('dueDate — earliest first, no-date last', () {
      final tasks = [
        task('c', deadline: DateTime(2026, 7, 10)),
        task('none'),
        task('a', deadline: DateTime(2026, 7, 4)),
      ];
      final ids = applyFeed(
        tasks,
        const TaskFeedFilter(sort: FeedSort.dueDate),
        now,
      ).map((t) => t.id);
      expect(ids, ['a', 'c', 'none']);
    });

    test('priority — high first', () {
      final tasks = [
        task('low', priority: TaskPriority.low),
        task('high', priority: TaskPriority.high),
        task('normal'),
      ];
      final ids = applyFeed(
        tasks,
        const TaskFeedFilter(sort: FeedSort.priority),
        now,
      ).map((t) => t.id);
      expect(ids, ['high', 'normal', 'low']);
    });

    test('newest — latest createdAt first', () {
      final tasks = [
        task('old', createdAt: DateTime(2026, 6, 1)),
        task('new', createdAt: DateTime(2026, 7, 1)),
      ];
      final ids = applyFeed(
        tasks,
        const TaskFeedFilter(sort: FeedSort.newest),
        now,
      ).map((t) => t.id);
      expect(ids, ['new', 'old']);
    });

    test('smart queue — overdue+high, review, overdue, today, normal', () {
      final tasks = [
        task('normal'),
        task('today', deadline: DateTime(2026, 7, 3, 18)),
        task('overdue', deadline: DateTime(2026, 6, 30)),
        task('review', status: TaskStatus.waitingReview),
        task(
          'overdueHigh',
          deadline: DateTime(2026, 6, 30),
          priority: TaskPriority.high,
        ),
      ];
      final ids = applyFeed(
        tasks,
        const TaskFeedFilter(sort: FeedSort.smart),
        now,
      ).map((t) => t.id);
      expect(ids, ['overdueHigh', 'review', 'overdue', 'today', 'normal']);
    });

    test('due-date is the default sort (Smart Queue is opt-in)', () {
      expect(const TaskFeedFilter().sort, FeedSort.dueDate);
    });
  });

  group('smartRank', () {
    test('assigns the documented tiers', () {
      expect(
        smartRank(
          task(
            'a',
            deadline: DateTime(2026, 6, 1),
            priority: TaskPriority.high,
          ),
          now,
        ),
        0,
      );
      expect(smartRank(task('b', status: TaskStatus.waitingReview), now), 1);
      expect(smartRank(task('c', deadline: DateTime(2026, 6, 1)), now), 2);
      expect(smartRank(task('d', deadline: DateTime(2026, 7, 3, 20)), now), 3);
      expect(smartRank(task('e'), now), 4);
    });
  });

  group('grouping', () {
    test(
      'dueTime buckets are ordered Overdue → Today → Week → Later → Done',
      () {
        final tasks = [
          task('done', status: TaskStatus.approved, approvedAt: now),
          task('later', deadline: DateTime(2026, 7, 20)),
          task('overdue', deadline: DateTime(2026, 6, 30)),
          task('today', deadline: DateTime(2026, 7, 3, 18)),
          task('week', deadline: DateTime(2026, 7, 6)),
        ];
        final filtered = applyFeed(tasks, const TaskFeedFilter(), now);
        final labels = groupFeed(
          filtered,
          FeedGrouping.dueTime,
          now,
        ).map((g) => g.label);
        expect(labels, [
          'Late',
          'Today',
          'This week',
          'Later',
          'Done today',
        ]);
      },
    );

    test('branch grouping uses resolved names', () {
      final tasks = [task('a', branchId: 'b1'), task('b', branchId: 'b2')];
      final groups = groupFeed(
        applyFeed(tasks, const TaskFeedFilter(), now),
        FeedGrouping.branch,
        now,
        branchNames: branchNames,
      );
      expect(groups.map((g) => g.label), ['Arkan', 'Maadi']);
    });

    test('employee grouping folds assignee / shift / unassigned', () {
      final tasks = [
        task('a', assignees: ['u1']),
        task(
          'shift',
          type: TaskAssignmentType.shift,
          shift: ScheduleShift.morning,
        ),
        task('none'),
      ];
      final groups = groupFeed(
        applyFeed(tasks, const TaskFeedFilter(), now),
        FeedGrouping.employee,
        now,
        directory: directory,
      );
      final labels = groups.map((g) => g.label).toList();
      expect(labels.first, 'Ziad'); // assigned employees sort first
      expect(labels, containsAll(['Morning shift', 'Unassigned']));
    });
  });

  group('TaskFeedFilter', () {
    test('togglePreset sets then clears', () {
      const base = TaskFeedFilter();
      final on = base.togglePreset(FeedPreset.overdue);
      expect(on.preset, FeedPreset.overdue);
      expect(on.togglePreset(FeedPreset.overdue).preset, isNull);
    });
    test('copyWith can clear a nullable field', () {
      const f = TaskFeedFilter(branchId: 'b1');
      expect(f.copyWith(branchId: null).branchId, isNull);
      expect(f.copyWith(sort: FeedSort.newest).branchId, 'b1'); // untouched
    });
    test('hasActiveFilters reflects any set filter', () {
      expect(const TaskFeedFilter().hasActiveFilters, isFalse);
      expect(const TaskFeedFilter(query: '  ').hasActiveFilters, isFalse);
      expect(
        const TaskFeedFilter(preset: FeedPreset.overdue).hasActiveFilters,
        isTrue,
      );
    });
  });
}
