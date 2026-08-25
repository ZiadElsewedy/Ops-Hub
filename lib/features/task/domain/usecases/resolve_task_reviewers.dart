import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/auth/domain/repositories/auth_repository.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/domain/task_review_routing.dart';

/// Resolves **who to tell that a task is waiting for review**, feeding the pure
/// [taskReviewRecipients] ladder with the directory reads it needs.
///
/// The decision lives in `task_review_routing.dart`; this class exists only to
/// fetch its inputs, and deliberately fetches them in the order that keeps the
/// common path cheap:
///
///  - the **branch directory** is read once (a manager creator is already in it,
///    so the usual case costs exactly one query);
///  - the **creator** is looked up individually only when the branch list does
///    not contain them — which in practice means an **admin** creator, since
///    admins are provisioned branchless and can never appear in a branch query;
///  - the **org-wide read** for tier 3 happens only when tiers 1 and 2 both come
///    up empty, i.e. a branch with no manager who can act. That is rare, and
///    paying an unfiltered read for it is better than losing the work.
///
/// Never throws: a directory read that fails degrades to the best answer the
/// data allowed, because a notification must never break the submission that
/// triggered it.
class ResolveTaskReviewers {
  final AuthRepository _repository;
  const ResolveTaskReviewers(this._repository);

  Future<List<String>> call(TaskEntity task) async {
    try {
      final branchId = (task.branchId ?? '').trim();
      final members = branchId.isEmpty
          ? const <UserEntity>[]
          : await _repository.getUsersByBranch(branchId);

      final creator = await _creator(task.createdBy, members);

      // First pass without the org-wide read — tiers 1 and 2 only.
      final resolved = taskReviewRecipients(
        task: task,
        creator: creator,
        branchMembers: members,
      );
      if (resolved.isNotEmpty) return resolved;

      // Nobody in the branch can review it. Escalate.
      final everyone = await _repository.getAllUsers();
      return taskReviewRecipients(
        task: task,
        creator: creator,
        branchMembers: members,
        admins: everyone,
      );
    } catch (_) {
      // Best-effort: an empty list is "no recipients", which the notification
      // producer already treats as valid rather than as a failure.
      return const [];
    }
  }

  /// [uid]'s user document — from [members] when the branch directory already
  /// carries it, otherwise one targeted read. Null when there is no creator to
  /// look up, or the account has been hard-deleted.
  Future<UserEntity?> _creator(String? uid, List<UserEntity> members) async {
    final id = (uid ?? '').trim();
    if (id.isEmpty) return null;
    for (final u in members) {
      if (u.uid == id) return u;
    }
    try {
      return await _repository.getUser(id);
    } catch (_) {
      return null;
    }
  }
}
