import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';

/// **WHO** performed an audited action — the actor half of an audit record,
/// captured at the moment of the event (denormalized on purpose: an audit trail
/// must read correctly years later even if the user is renamed, moved branch, or
/// deleted).
///
/// A tiny immutable value object so producers pass one thing, not four loose
/// arguments. Build it from the signed-in [UserEntity] with [AuditActor.of];
/// server-driven / unattributed actions use [AuditActor.system].
class AuditActor {
  const AuditActor({
    required this.id,
    this.name,
    this.role = UserRole.employee,
    this.branchId,
  });

  /// The actor's uid. Empty only for [system]. The audit rules pin this to the
  /// authenticated caller, so it cannot be forged as another user.
  final String id;

  /// The actor's display name at event time (best-effort; may be null).
  final String? name;

  /// The actor's role at event time.
  final UserRole role;

  /// The actor's branch at event time — the default `branchId` scope for the
  /// record when a producer doesn't pass an explicit one.
  final String? branchId;

  /// Whether this is a real, attributable user (has a uid).
  bool get isAttributed => id.isNotEmpty;

  /// Captures the signed-in user as an actor. Prefers [UserEntity.displayName],
  /// falling back to the email so a record always names someone.
  factory AuditActor.of(UserEntity user) {
    final name = user.displayName?.trim();
    return AuditActor(
      id: user.uid,
      name: (name != null && name.isNotEmpty) ? name : user.email.trim(),
      role: user.role,
      branchId: user.branchId,
    );
  }

  /// A non-user actor (a scheduled job / server routine). [id] is empty so the
  /// record is clearly system-attributed.
  factory AuditActor.system({String label = 'System'}) =>
      AuditActor(id: '', name: label, role: UserRole.admin);
}
