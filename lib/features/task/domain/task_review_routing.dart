import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';

/// **Who is told that a task is waiting for review.** Pure, so the rule is
/// unit-tested and cannot drift from the access model it mirrors.
///
/// `taskSubmitted` used to route to `task.createdBy` and nothing else, which
/// has two failure modes that both end in **silence**: a task sits in
/// `waitingReview` and no live reviewer is told.
///
///  - **the creator is gone** — deactivated (`isActive: false`) or hard-deleted.
///    `sendNotification` skips an absent recipient without raising, so the
///    submission simply notified nobody.
///  - **the creator can no longer review it** — a manager demoted to employee,
///    or moved to another branch. `firestore.rules` would refuse their approval,
///    so notifying them is worse than useless: it tells the one person who
///    *cannot* act, and nobody who can.
///
/// A generated shift task makes this routine rather than exotic: it inherits the
/// **template's** `createdBy` (see `task_origin.dart` — which is exactly why
/// that file warns `createdBy` cannot answer "who made this"). A template set up
/// a year ago by someone who has since left produces a task every single day
/// whose submission notifies a dead account.

/// Whether [user] may actually decide the review of a task owned by [branchId].
///
/// Mirrors the `tasks` update rule in `firestore.rules` and the server's own
/// `requireSalesManager` — **active**, and either a global admin or a manager of
/// *this* branch. If this predicate and the rule ever disagree, the rule wins
/// and this is the bug.
bool canReviewTask(UserEntity user, String? branchId) {
  if (!user.isActive) return false;
  if (user.role.isAdmin) return true;
  if (!user.role.isManager) return false;
  final branch = (branchId ?? '').trim();
  return branch.isNotEmpty && user.branchId == branch;
}

/// The uids to notify that [task] has been submitted for review, in the order
/// the ladder is tried. Returns an empty list when nobody can be found — the
/// caller treats that as "no recipients", never as an error.
///
/// **The ladder** — deliberately the same shape as the server's
/// `salesRecipients(branchId, {managersOnly: true, adminsFallback: true})`,
/// which already answers this question for branch-scoped review routing. Two
/// analogous decisions must not use two different escalation rules.
///
/// 1. **The creator**, when they can still review it. Unchanged for the
///    overwhelmingly common case (a manager reviewing a task they raised in
///    their own branch), so this fixes the broken paths without adding noise to
///    the working one.
/// 2. **The branch's active managers** — the people the access model says own
///    this branch's work. This is the actual fallback.
/// 3. **Active admins**, only when the branch has no manager who can act. A
///    branch between managers must not silently swallow submitted work.
///
/// [branchMembers] is the branch directory (unfiltered — filtering happens
/// here). [admins] may be empty on a first pass; when the result is empty and
/// [admins] was empty, the caller re-runs with the admin list. That two-pass
/// shape keeps the org-wide read off the common path while leaving the whole
/// ladder in one tested place.
List<String> taskReviewRecipients({
  required TaskEntity task,
  required UserEntity? creator,
  required List<UserEntity> branchMembers,
  List<UserEntity> admins = const [],
}) {
  final branchId = task.branchId;

  // 1 — the creator, if they are still a reviewer for this branch.
  if (creator != null && canReviewTask(creator, branchId)) {
    return [creator.uid];
  }

  // 2 — the branch's active managers. `canReviewTask` already requires the
  // branch match, so an admin who happens to carry a stale branchId cannot
  // sneak in here; tier 3 is the only door for admins.
  final managers = [
    for (final u in branchMembers)
      if (u.role.isManager && canReviewTask(u, branchId)) u.uid,
  ];
  if (managers.isNotEmpty) return _distinct(managers);

  // 3 — active admins, as a last resort.
  return _distinct([
    for (final u in admins)
      if (u.role.isAdmin && u.isActive) u.uid,
  ]);
}

/// Order-preserving de-duplication — a directory can legitimately serve the same
/// uid twice (a member list overlapping the admin list on a re-read), and one
/// person must never be sent two copies of the same notification.
List<String> _distinct(List<String> uids) {
  final seen = <String>{};
  return [
    for (final uid in uids)
      if (uid.trim().isNotEmpty && seen.add(uid)) uid,
  ];
}
