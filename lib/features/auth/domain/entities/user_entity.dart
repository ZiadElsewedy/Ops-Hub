import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:opshub/core/enums/user_role.dart';

part 'user_entity.freezed.dart';

@freezed
class UserEntity with _$UserEntity {
  const UserEntity._();

  const factory UserEntity({
    required String uid,
    required String email,
    required String authProvider,
    String? displayName,
    String? photoUrl,
    String? phoneNumber,
    /// Home / mailing address. Optional contact detail an admin can fill in or
    /// edit at any time (also collected during profile onboarding).
    String? address,
    /// Emergency contact (name/phone). Optional contact detail an admin can fill
    /// in or edit at any time (also collected during profile onboarding).
    String? emergencyContact,
    @Default(false) bool isEmailVerified,
    DateTime? createdAt,
    // ─── Roles & foundation (Phase 1) ───────────────────────────
    /// Access role; drives navigation + route guards. Defaults to [UserRole.employee].
    @Default(UserRole.employee) UserRole role,
    /// Store branch the user belongs to. Assigned by an admin; null until then.
    String? branchId,
    /// Soft-disable flag: an admin can deactivate a user without deletion. This is
    /// the SINGLE access gate — a deactivated account is blocked at login.
    @Default(true) bool isActive,
    /// Shift assigned to the user; null until an admin sets it.
    String? assignedShift,
    /// Job position / role title within the branch (e.g. "Cashier",
    /// "Supervisor"). Optional — null means unspecified. Drives shift-swap role
    /// compatibility when a branch enables `SwapPolicy.restrictToSamePosition`
    /// (an unset position stays compatible with everyone).
    String? position,
    // ─── Account provisioning (admin-created, no self-registration) ─────
    /// True until the user changes the admin-issued temporary password. While
    /// set, the router confines them to the Force Password Change screen.
    @Default(false) bool mustChangePassword,
    /// True once the user has filled their onboarding profile. While false, the
    /// router confines them to the Profile Completion screen. Defaults true so
    /// legacy / pre-migration documents are never trapped in onboarding.
    @Default(true) bool isProfileCompleted,
    /// True once the user has seen the one-time Welcome screen (shown to
    /// employees right after profile completion). Defaults true so every
    /// existing user is treated as already welcomed and is NEVER interrupted —
    /// only a genuinely new account is seeded `false` at profile completion, so
    /// the router shows Welcome exactly once. Non-employees never see it
    /// regardless of this flag (the gate is employee-scoped).
    @Default(true) bool hasCompletedOnboarding,
    /// HR employment label (`active` / `suspended` / `terminated`). A record
    /// field shown/edited in admin — it does NOT gate access (that's [isActive]).
    @Default('active') String employmentStatus,
    /// The admin uid that provisioned this account (audit). Null for accounts
    /// created out of band (e.g. the bootstrapped first admin).
    String? createdBy,
    // ─── Single active session ──────────────────────────────────
    /// The id of the ONE sign-in currently allowed to hold this account, minted
    /// per device at sign-in (`generateSessionId`) and claimed on the user
    /// document. A device stays signed in only while this matches the id in its
    /// own `SessionStore`; a newer sign-in elsewhere overwrites it and evicts
    /// every other device (see `AuthCubit`).
    ///
    /// **Null means "no claim on record"** — legacy documents, and any account
    /// that has not signed in since the feature shipped. Null is deliberately
    /// NOT an eviction: it is the back-compat state, so an app upgrade never
    /// signs the whole company out at once.
    String? activeSessionId,
    // NOTE (C2 fix, 2026-07-03): compensation (salaryAmount / salaryType /
    // paymentMethod / paymentNumber) is deliberately NOT on this entity — it
    // lives in the private subdocument `users/{uid}/private/compensation`
    // (see UserCompensation) and is loaded on demand, so the branch-readable
    // public user fetch can never carry salary data.
  }) = _UserEntity;

  /// Whether the user may enter the app. OpsHub is admin-provisioned: the only
  /// access gate is [isActive] — a deactivated account is blocked at login and
  /// signed out. (`employmentStatus` is an HR label, not a gate.)
  bool get hasAppAccess => isActive;
}
