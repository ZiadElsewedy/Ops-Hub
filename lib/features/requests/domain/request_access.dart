import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/requests/domain/entities/request_entity.dart';

/// Pure role/branch access predicates for a single request — the single source
/// the detail UI + cubit consult so a button is never offered that the Firestore
/// rule would reject. Kept Flutter-free so it is unit-testable.

/// The viewer filed this request.
bool viewerIsRequester(UserEntity user, RequestEntity request) =>
    request.requesterId == user.uid;

/// Whether the viewer is a manager of the request's own branch (an admin is
/// global, so branch never matters for them).
bool _isOwnBranchManager(UserEntity user, RequestEntity request) =>
    user.role.isManager &&
    (user.branchId != null) &&
    user.branchId == request.branchId;

/// Whether the viewer can even see / participate in this request — the requester,
/// an admin (global), or an own-branch manager. Mirrors the `requests` read rule.
bool canAccessRequest(UserEntity user, RequestEntity request) =>
    viewerIsRequester(user, request) ||
    user.role.isAdmin ||
    _isOwnBranchManager(user, request);

/// Whether the viewer can DECIDE this request (approve / reject) — any admin
/// (global) or the request's own-branch manager. Mirrors the `requests` update
/// gate.
bool canDecideRequest(UserEntity user, RequestEntity request) =>
    user.role.isAdmin || _isOwnBranchManager(user, request);

/// Whether the viewer may post a comment — anyone with access, while the request
/// is still active (a decided request is a read-only record).
bool canCommentOnRequest(UserEntity user, RequestEntity request) =>
    request.isActive && canAccessRequest(user, request);

/// Whether the viewer may REOPEN a decided request (send it back to Pending) —
/// admin only, and only once a decision exists. The escape hatch for a decision
/// made by mistake or that needs another look.
bool canReopenRequest(UserEntity user, RequestEntity request) =>
    user.role.isAdmin && request.isTerminal;

/// Whether the viewer may (soft-)delete a request — admin only. The doc is kept
/// as a record; the inbox just stops showing it.
bool canDeleteRequest(UserEntity user) => user.role.isAdmin;
