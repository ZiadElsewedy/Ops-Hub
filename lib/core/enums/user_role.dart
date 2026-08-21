/// The three OpsHub access roles. Every user has exactly one role, which drives
/// post-login navigation, route guards (see `createRouter`) and the data-access
/// model enforced by Firestore security rules.
///
/// Access model:
/// - [admin] — global. Not restricted by `branchId`; can do everything a
///   [manager] can, across all branches (admin ⊇ manager).
/// - [manager] — belongs to exactly one branch; limited to data where
///   `resource.branchId == manager.branchId`.
/// - [employee] — limited to their own assigned data and profile.
///
/// New users always start as [employee]; promotion to [manager]/[admin] is a
/// privileged action performed by an admin (out of band / a future phase) and
/// can never be self-assigned — enforced by Firestore security rules.
enum UserRole {
  admin,
  manager,
  employee;

  /// The string persisted in Firestore (`users/{uid}.role`).
  String get value => name;

  bool get isAdmin => this == UserRole.admin;
  bool get isManager => this == UserRole.manager;
  bool get isEmployee => this == UserRole.employee;

  /// Whether this role has global (non-branch-scoped) access. Admin only.
  bool get isGlobal => this == UserRole.admin;

  /// Parses the stored Firestore string, defaulting to [employee] for unknown
  /// or missing values so a malformed document can never escalate privileges.
  static UserRole fromString(String? raw) {
    switch (raw) {
      case 'admin':
        return UserRole.admin;
      case 'manager':
        return UserRole.manager;
      case 'employee':
      default:
        return UserRole.employee;
    }
  }
}
