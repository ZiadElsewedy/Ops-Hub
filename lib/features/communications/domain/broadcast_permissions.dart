import 'package:opshub/core/enums/broadcast_audience.dart';
import 'package:opshub/core/enums/user_role.dart';

/// Who may send what — the **recipient-resolution permission matrix** for the
/// Communications Center, as a pure, deterministic domain rule.
///
/// This is the **client-side guard** (defense-in-depth + UI affordance): it
/// decides which audiences a role may pick and validates a send before the
/// callable `sendBroadcast` Cloud Function is invoked. The function re-enforces
/// the identical matrix server-side (the authoritative check), so a tampered
/// client can never bypass it.
///
/// Matrix (mirrors the function + `firestore.rules`):
/// - **admin** → [BroadcastAudience.allBranches] · [BroadcastAudience.branch]
///   (any branch) · [BroadcastAudience.user] (any user).
/// - **manager** → [BroadcastAudience.branch] (their **own** branch only) ·
///   [BroadcastAudience.user] (a user **inside their own branch** only).
/// - **employee** → nothing.
class BroadcastPermissions {
  const BroadcastPermissions._();

  /// Whether [role] is allowed to send to [audience] at all.
  static bool canSend(UserRole role, BroadcastAudience audience) {
    switch (role) {
      case UserRole.admin:
        return true;
      case UserRole.manager:
        return audience == BroadcastAudience.branch ||
            audience == BroadcastAudience.user ||
            audience == BroadcastAudience.custom;
      case UserRole.employee:
        return false;
    }
  }

  /// The user-**selectable** audiences for [role], in display order. `custom`
  /// (multi-recipient) is **derived** by the composer (a multi-pick under the
  /// individual picker), not a separate chip, so it is excluded here.
  static const List<BroadcastAudience> _selectable = [
    BroadcastAudience.allBranches,
    BroadcastAudience.branch,
    BroadcastAudience.user,
  ];

  static List<BroadcastAudience> allowedAudiences(UserRole role) =>
      _selectable.where((a) => canSend(role, a)).toList();

  /// Whether [role] may send any broadcast at all.
  static bool canBroadcast(UserRole role) => allowedAudiences(role).isNotEmpty;

  /// Validates a concrete send request from a sender with [role] / [senderBranchId]
  /// to [audience], for an optional [targetBranchId] (the branch being targeted)
  /// and [targetUserBranchId] (the branch of an individual recipient). Returns
  /// `null` when the request is allowed, or a user-facing reason when it is not.
  ///
  /// Branch identity is compared the same way the function does: a manager is
  /// bound to `senderBranchId`; an admin is unrestricted.
  static String? validate({
    required UserRole role,
    required BroadcastAudience audience,
    String? senderBranchId,
    String? targetBranchId,
    String? targetUserBranchId,
  }) {
    if (!canSend(role, audience)) {
      return role == UserRole.employee
          ? 'You do not have permission to send broadcasts.'
          : 'You can only message your own branch or a user inside it.';
    }
    if (role == UserRole.manager) {
      final own = (senderBranchId ?? '').trim();
      if (own.isEmpty) return 'Your account has no branch assigned yet.';
      if (audience == BroadcastAudience.branch &&
          (targetBranchId ?? '').trim() != own) {
        return 'Managers can only broadcast to their own branch.';
      }
      if (audience == BroadcastAudience.user &&
          (targetUserBranchId ?? '').trim() != own) {
        return 'Managers can only message users inside their own branch.';
      }
      // `custom` recipients are picked from the manager's own branch in the
      // composer; the function re-validates every recipient's branch server-side.
    }
    return null;
  }
}
