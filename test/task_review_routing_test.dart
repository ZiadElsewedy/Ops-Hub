import 'package:drop/core/enums/task_status.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/domain/repositories/auth_repository.dart';
import 'package:drop/features/task/domain/entities/task_entity.dart';
import 'package:drop/features/task/domain/task_review_routing.dart';
import 'package:drop/features/task/domain/usecases/resolve_task_reviewers.dart';
import 'package:flutter_test/flutter_test.dart';

/// Who is told a task is waiting for review.
///
/// `taskSubmitted` used to route to `task.createdBy` alone, which is **silence**
/// whenever that account is deactivated, deleted, demoted, or has moved branch.
/// A generated shift task makes it routine rather than exotic: it inherits the
/// TEMPLATE's `createdBy`, so a template set up by someone who has since left
/// produces a task every day whose submission notifies a dead account.
void main() {
  UserEntity user(
    String uid, {
    UserRole role = UserRole.manager,
    String? branchId = 'branchA',
    bool isActive = true,
  }) =>
      UserEntity(
        uid: uid,
        email: '$uid@drop.test',
        authProvider: 'password',
        role: role,
        branchId: branchId,
        isActive: isActive,
      );

  TaskEntity task({String? branchId = 'branchA', String? createdBy = 'mgrA'}) =>
      TaskEntity(
        id: 't1',
        title: 'Restock the cold case',
        status: TaskStatus.waitingReview,
        branchId: branchId,
        assigneeIds: const ['emp1'],
        createdBy: createdBy,
      );

  // Admins are provisioned BRANCHLESS — the role is global (PROJECT_CONTEXT §8).
  final admin = user('admin1', role: UserRole.admin, branchId: null);
  final otherAdmin = user('admin2', role: UserRole.admin, branchId: null);
  final managerA = user('mgrA');
  final managerA2 = user('mgrA2');
  final managerB = user('mgrB', branchId: 'branchB');
  final employeeA = user('emp1', role: UserRole.employee);

  group('canReviewTask mirrors the tasks update rule', () {
    test('an admin reviews any branch, including a branchless task', () {
      expect(canReviewTask(admin, 'branchA'), isTrue);
      expect(canReviewTask(admin, 'branchB'), isTrue);
      expect(canReviewTask(admin, null), isTrue);
    });

    test('a manager reviews only their own branch', () {
      expect(canReviewTask(managerA, 'branchA'), isTrue);
      expect(canReviewTask(managerA, 'branchB'), isFalse);
      // A branchless task has no branch for a manager to match.
      expect(canReviewTask(managerA, null), isFalse);
      expect(canReviewTask(managerA, ''), isFalse);
    });

    test('an employee never reviews — review stays manager/admin', () {
      expect(canReviewTask(employeeA, 'branchA'), isFalse);
    });

    test('a deactivated account never reviews, whatever the role', () {
      expect(canReviewTask(user('x', isActive: false), 'branchA'), isFalse);
      expect(
        canReviewTask(
          user('y', role: UserRole.admin, branchId: null, isActive: false),
          'branchA',
        ),
        isFalse,
      );
    });
  });

  group('tier 1 — the creator, when they can still review', () {
    test('a live branch manager creator is the only recipient', () {
      // The overwhelmingly common case must be unchanged: no extra noise.
      expect(
        taskReviewRecipients(
          task: task(),
          creator: managerA,
          branchMembers: [managerA, managerA2, employeeA],
        ),
        ['mgrA'],
      );
    });

    test('a live admin creator is the only recipient', () {
      // The path the reachability fix unblocked — it must not now fan out.
      expect(
        taskReviewRecipients(
          task: task(createdBy: 'admin1'),
          creator: admin,
          branchMembers: [managerA, employeeA],
        ),
        ['admin1'],
      );
    });
  });

  group('tier 2 — the branch managers, when the creator cannot', () {
    test('a DEACTIVATED creator falls through to the branch managers', () {
      expect(
        taskReviewRecipients(
          task: task(),
          creator: user('mgrA', isActive: false),
          branchMembers: [
            user('mgrA', isActive: false),
            managerA2,
            employeeA,
          ],
        ),
        ['mgrA2'],
      );
    });

    test('a DELETED creator (null lookup) falls through', () {
      expect(
        taskReviewRecipients(
          task: task(),
          creator: null,
          branchMembers: [managerA2, employeeA],
        ),
        ['mgrA2'],
      );
    });

    test('a creator DEMOTED to employee falls through', () {
      // Rules would refuse their approval, so notifying them tells the one
      // person who cannot act and nobody who can.
      expect(
        taskReviewRecipients(
          task: task(),
          creator: user('mgrA', role: UserRole.employee),
          branchMembers: [user('mgrA', role: UserRole.employee), managerA2],
        ),
        ['mgrA2'],
      );
    });

    test('a creator who MOVED BRANCH falls through', () {
      expect(
        taskReviewRecipients(
          task: task(),
          creator: user('mgrA', branchId: 'branchB'),
          branchMembers: [managerA2],
        ),
        ['mgrA2'],
      );
    });

    test('a task with no creator at all falls through', () {
      expect(
        taskReviewRecipients(
          task: task(createdBy: null),
          creator: null,
          branchMembers: [managerA2],
        ),
        ['mgrA2'],
      );
    });

    test('every live branch manager is told, deactivated ones are not', () {
      expect(
        taskReviewRecipients(
          task: task(),
          creator: null,
          branchMembers: [
            managerA,
            managerA2,
            user('mgrA3', isActive: false),
            employeeA,
          ],
        ),
        ['mgrA', 'mgrA2'],
      );
    });

    test('a manager from another branch in the list is ignored', () {
      // Defensive: the directory read is branch-scoped, but a stale or widened
      // read must not leak a task to a branch that cannot act on it.
      expect(
        taskReviewRecipients(
          task: task(),
          creator: null,
          branchMembers: [managerB, managerA2],
        ),
        ['mgrA2'],
      );
    });

    test('an admin sitting in the branch list does NOT satisfy tier 2', () {
      // Tier 3 is the only door for admins, so the escalation stays explicit
      // and an admin is not silently treated as a branch manager.
      expect(
        taskReviewRecipients(
          task: task(),
          creator: null,
          branchMembers: [user('admin3', role: UserRole.admin), employeeA],
        ),
        isEmpty,
      );
    });
  });

  group('tier 3 — admins, only when the branch has nobody', () {
    test('escalates when there is no live branch manager', () {
      expect(
        taskReviewRecipients(
          task: task(),
          creator: null,
          branchMembers: [employeeA, user('mgrA', isActive: false)],
          admins: [admin, otherAdmin, employeeA],
        ),
        ['admin1', 'admin2'],
      );
    });

    test('a deactivated admin is not escalated to', () {
      expect(
        taskReviewRecipients(
          task: task(),
          creator: null,
          branchMembers: const [],
          admins: [user('admin9', role: UserRole.admin, isActive: false)],
        ),
        isEmpty,
      );
    });

    test('admins are NOT used while a branch manager can act', () {
      // The escalation must stay a last resort — mirroring the server's
      // `salesRecipients(managersOnly: true, adminsFallback: true)`.
      expect(
        taskReviewRecipients(
          task: task(),
          creator: null,
          branchMembers: [managerA2],
          admins: [admin, otherAdmin],
        ),
        ['mgrA2'],
      );
    });

    test('nobody anywhere yields an empty list, never an error', () {
      expect(
        taskReviewRecipients(
          task: task(),
          creator: null,
          branchMembers: const [],
          admins: const [],
        ),
        isEmpty,
      );
    });
  });

  group('a branchless task', () {
    test('cannot reach tier 2 and escalates straight to admins', () {
      // No branch means no branch manager can match, so the only reviewer is a
      // global one.
      expect(
        taskReviewRecipients(
          task: task(branchId: null),
          creator: null,
          branchMembers: [managerA, managerA2],
          admins: [admin],
        ),
        ['admin1'],
      );
    });
  });

  group('duplicates', () {
    test('one person is never sent two copies', () {
      expect(
        taskReviewRecipients(
          task: task(),
          creator: null,
          branchMembers: [managerA2, managerA2],
        ),
        ['mgrA2'],
      );
      expect(
        taskReviewRecipients(
          task: task(),
          creator: null,
          branchMembers: const [],
          admins: [admin, admin, otherAdmin],
        ),
        ['admin1', 'admin2'],
      );
    });
  });

  group('ResolveTaskReviewers keeps the common path cheap', () {
    test('a manager creator costs ONE branch read and no org-wide read',
        () async {
      final repo = _FakeAuthRepository(
        byBranch: {
          'branchA': [managerA, managerA2, employeeA],
        },
      );
      final resolve = ResolveTaskReviewers(repo);

      expect(await resolve(task()), ['mgrA']);
      expect(repo.branchReads, ['branchA']);
      // The creator was already in the branch list — no targeted read.
      expect(repo.userReads, isEmpty);
      // Tier 1 resolved — no unfiltered read.
      expect(repo.allUsersReads, 0);
    });

    test('an admin creator costs one targeted read, still no org-wide read',
        () async {
      // Admins are branchless, so they can never appear in a branch query.
      final repo = _FakeAuthRepository(
        byBranch: {
          'branchA': [managerA2, employeeA],
        },
        users: {'admin1': admin},
      );
      final resolve = ResolveTaskReviewers(repo);

      expect(await resolve(task(createdBy: 'admin1')), ['admin1']);
      expect(repo.userReads, ['admin1']);
      expect(repo.allUsersReads, 0);
    });

    test('the org-wide read happens ONLY when the branch has nobody', () async {
      final repo = _FakeAuthRepository(
        byBranch: {
          'branchA': [employeeA],
        },
        users: {'mgrA': user('mgrA', isActive: false)},
        all: [admin, managerA2, employeeA],
      );
      final resolve = ResolveTaskReviewers(repo);

      expect(await resolve(task()), ['admin1']);
      expect(repo.allUsersReads, 1);
    });

    test('a failing directory read degrades to no recipients, never throws',
        () async {
      final repo = _FakeAuthRepository(byBranch: {}, failBranchRead: true);
      final resolve = ResolveTaskReviewers(repo);
      expect(await resolve(task()), isEmpty);
    });

    test('a failing creator lookup still reaches the branch managers', () async {
      // The targeted read is the fragile one (a deleted doc, a transient
      // error); it must not take the whole ladder down with it.
      final repo = _FakeAuthRepository(
        byBranch: {
          'branchA': [managerA2],
        },
        failUserRead: true,
      );
      final resolve = ResolveTaskReviewers(repo);
      expect(await resolve(task(createdBy: 'admin1')), ['mgrA2']);
    });
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    this.byBranch = const {},
    this.users = const {},
    this.all = const [],
    this.failBranchRead = false,
    this.failUserRead = false,
  });

  final Map<String, List<UserEntity>> byBranch;
  final Map<String, UserEntity> users;
  final List<UserEntity> all;
  final bool failBranchRead;
  final bool failUserRead;

  final List<String> branchReads = [];
  final List<String> userReads = [];
  int allUsersReads = 0;

  @override
  Future<List<UserEntity>> getUsersByBranch(String branchId) async {
    branchReads.add(branchId);
    if (failBranchRead) throw StateError('offline');
    return byBranch[branchId] ?? const [];
  }

  @override
  Future<UserEntity?> getUser(String uid) async {
    userReads.add(uid);
    if (failUserRead) throw StateError('offline');
    return users[uid];
  }

  @override
  Future<List<UserEntity>> getAllUsers() async {
    allUsersReads++;
    return all;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
