import 'package:opshub/core/enums/user_role.dart';
import 'package:opshub/features/cases/domain/entities/case_entity.dart';

/// Which side of the conversation the viewer is on. The case doc carries no
/// creator uid (privacy split), so this is inferred from role + routing:
///
/// - an **employee** always views their **own** case → reporter;
/// - an **admin** never files (UI-gated) → always a recipient;
/// - a **manager** is the reporter only of an **admin-routed** case they filed
///   (which reaches them solely via their own list — a branch case is
///   `visibleToManager` and they are its recipient).
bool viewerIsReporter(UserRole role, CaseEntity c) {
  if (role.isEmployee) return true;
  if (role.isManager) return !c.visibleToManager;
  return false;
}

/// Whether the viewer may drive the case status (the header control). Only a
/// recipient (admin, or the branch manager a case is routed to) can.
bool viewerCanControlStatus(UserRole role, CaseEntity c) =>
    !viewerIsReporter(role, c) && (role.isAdmin || role.isManager);
