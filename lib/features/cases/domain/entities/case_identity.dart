import 'package:opshub/core/enums/case_privacy.dart';

/// The reporter's identity for one case — stored in the **private** subdoc
/// `cases/{caseId}/reporter/identity`, readable ONLY by the reporter and an
/// admin (never a branch manager). Kept off the manager-readable case doc so a
/// confidential sender can't be resolved from the case itself (Firestore reads
/// are whole-document). Mirrors the compensation-subdoc pattern
/// (`users/{uid}/private/compensation`).
///
/// A plain immutable value object (not freezed) — it never rides on a cubit
/// state, only crosses the data boundary on create + admin reveal.
class CaseIdentity {
  const CaseIdentity({
    required this.caseId,
    required this.createdByUserId,
    this.createdByName,
    this.privacy = CasePrivacy.normal,
    this.branchId,
    this.createdAt,
  });

  /// The parent case id (denormalized so the owner's collectionGroup query on
  /// `reporter` can resolve the case without walking the path).
  final String caseId;

  /// uid of whoever filed the case.
  final String createdByUserId;

  /// Denormalized display name (best-effort) — the admin reveal + the owner's
  /// own "My Cases" list read it from here.
  final String? createdByName;

  final CasePrivacy privacy;
  final String? branchId;
  final DateTime? createdAt;
}
